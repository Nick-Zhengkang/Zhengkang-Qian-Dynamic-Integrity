function outputDirectory = run_habib_4d_candidate_validation( ...
        sixModelOutputDirectory,seedList)
%RUN_HABIB_4D_CANDIDATE_VALIDATION Validate the reported 4D boundary.
%
% The saved best ray from each adaptive-angle run is tested without using
% the search classifier. Validation uses ode113, tighter tolerances, an
% expanded escape domain, and checkpoints at t=2000, 4000, and 8000.
% Points immediately inside and outside the reported boundary are included
% so the test checks a safe/non-target bracket rather than only one point.

    if nargin<1 || strlength(string(sixModelOutputDirectory))==0
        error('Provide the completed six-model output directory.');
    end
    if nargin<2, seedList=[]; end
    sixModelOutputDirectory=char(sixModelOutputDirectory);
    assert(isfolder(sixModelOutputDirectory), ...
        'Six-model output directory does not exist: %s', ...
        sixModelOutputDirectory);

    manifestPath=fullfile(sixModelOutputDirectory, ...
        'child_output_manifest.csv');
    rawPath=fullfile(sixModelOutputDirectory,'raw_data_all_runs.csv');
    assert(isfile(manifestPath) && isfile(rawPath), ...
        'The selected directory is not a complete six-model output.');

    manifest=readtable(manifestPath,'Delimiter',',', ...
        'ReadVariableNames',true,'TextType','string');
    manifestModel=string(table_column(manifest,'model_id'));
    manifestDirectory=string(table_column( ...
        manifest,'child_output_directory'));
    hit=manifestModel=="habib_vdp_tmd_4d";
    assert(nnz(hit)==1,'Habib 4D child output was not found in the manifest.');
    childDirectory=char(manifestDirectory(hit));
    detailDirectory=fullfile(childDirectory,'run_details');
    assert(isfolder(detailDirectory), ...
        'Saved run details were not found: %s',detailDirectory);

    raw=readtable(rawPath,'Delimiter',',', ...
        'ReadVariableNames',true,'TextType','string');
    rawModel=string(table_column(raw,'model_id'));
    rawMethod=string(table_column(raw,'method'));
    rawSuccess=numeric_column(raw,'success');
    selected=raw(rawModel=="habib_vdp_tmd_4d" & ...
        rawMethod=="proposed_adaptive_angle" & rawSuccess==1,:);
    assert(~isempty(selected),'No successful Habib 4D proposed runs exist.');
    if isempty(seedList)
        seedList=sort(unique(numeric_column(selected,'seed'))).';
    else
        seedList=double(seedList(:).');
    end

    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    outputDirectory=fullfile(fileparts(mfilename('fullpath')), ...
        ['outputs_habib_4d_candidate_validation_' stamp]);
    mkdir(outputDirectory);

    validation=validation_configuration();
    candidateRows=table();
    pointRows=table();
    fprintf('Habib 4D independent candidate validation\n');
    fprintf('Seeds: %d; solver: ode113; maximum horizon: %.0f\n', ...
        numel(seedList),validation.horizons(end));
    fprintf('Output directory:\n%s\n\n',outputDirectory);

    for iSeed=1:numel(seedList)
        seed=seedList(iSeed);
        sourceSeeds=numeric_column(selected,'seed');
        sourceRow=selected(sourceSeeds==seed,:);
        assert(height(sourceRow)==1, ...
            'Expected one proposed result for seed %d.',seed);
        sourceRHat=numeric_column(sourceRow,'R_hat');
        detailPath=find_detail_file(detailDirectory,seed);
        loaded=load(detailPath,'details','problem','cfg');
        details=loaded.details;
        problem=loaded.problem;

        rays=details.rays;
        radii=[rays.boundary_radius].';
        finiteRay=find(isfinite(radii));
        assert(~isempty(finiteRay), ...
            'Seed %d has no finite boundary ray.',seed);
        [bestRadius,localIndex]=min(radii(finiteRay));
        bestRay=rays(finiteRay(localIndex));
        assert(abs(bestRadius-sourceRHat) <= ...
            max(1e-10,2*loaded.cfg.radialTolerance), ...
            'Saved best ray does not match R_hat for seed %d.',seed);

        direction=bestRay.direction(:).'/norm(bestRay.direction);
        probes=build_probes(bestRay,bestRadius,validation.paperReference);
        candidateState=state_on_ray(problem,bestRadius,direction);
        candidateRow=struct();
        candidateRow.seed=seed;
        candidateRow.source_R_hat=sourceRHat;
        candidateRow.best_ray_radius=bestRadius;
        candidateRow.bracket_lower=bestRay.bracket_lower;
        candidateRow.bracket_upper=bestRay.bracket_upper;
        candidateRow.bracket_width=bestRay.bracket_width;
        candidateRow.paper_reference=validation.paperReference;
        candidateRow.signed_difference_from_paper= ...
            bestRadius-validation.paperReference;
        for j=1:4
            candidateRow.(sprintf('direction_u%d',j))=direction(j);
            candidateRow.(sprintf('candidate_z%d',j))=candidateState(j);
        end

        seedPoints=table();
        fprintf('[seed %d/%d] R_hat=%.9f; validating %d probes\n', ...
            iSeed,numel(seedList),bestRadius,height(probes));
        for iProbe=1:height(probes)
            radius=probes.radius(iProbe);
            z0=state_on_ray(problem,radius,direction);
            trajectory=integrate_independently(z0,problem,validation);
            for iHorizon=1:numel(validation.horizons)
                horizon=validation.horizons(iHorizon);
                assessment=assess_at_horizon(trajectory,problem, ...
                    validation,horizon);
                row=struct();
                row.seed=seed;
                row.probe=probes.probe(iProbe);
                row.expected_side=probes.expected_side(iProbe);
                row.radius=radius;
                row.relative_to_R_hat=radius/bestRadius-1;
                row.horizon=horizon;
                row.label=assessment.label;
                row.classification_reason=assessment.reason;
                row.event_time=assessment.event_time;
                row.minimum_weighted_radius=assessment.minimum_radius;
                row.final_weighted_radius=assessment.final_radius;
                row.tail_median_radius=assessment.tail_median_radius;
                row.tail_radius_ratio=assessment.tail_radius_ratio;
                row.asymptotic_hint=assessment.asymptotic_hint;
                row.periodic_detected=assessment.periodic_detected;
                row.estimated_period=assessment.estimated_period;
                row.period_coefficient_of_variation=assessment.period_cv;
                row.poincare_recurrence_error= ...
                    assessment.recurrence_error;
                row.periodic_cycles=assessment.periodic_cycles;
                row.periodic_observable=assessment.periodic_observable;
                row.solver_success=trajectory.success;
                row.solver_message=trajectory.message;
                for j=1:4
                    row.(sprintf('initial_z%d',j))=z0(j);
                end
                seedPoints=append_struct_row(seedPoints,row);
            end
            finalRows=seedPoints(seedPoints.probe==probes.probe(iProbe) & ...
                seedPoints.horizon==validation.horizons(end),:);
            fprintf('  %-31s r=%.9f -> %s (%s)\n', ...
                char(probes.probe(iProbe)),radius, ...
                char(finalRows.label),char(finalRows.classification_reason));
        end

        finalSeed=seedPoints(seedPoints.horizon==validation.horizons(end),:);
        candidateRow.bracket_inner_label=label_for( ...
            finalSeed,"bracket_inner");
        candidateRow.bracket_outer_label=label_for( ...
            finalSeed,"bracket_outer");
        candidateRow.inward_0p2pct_label=label_for( ...
            finalSeed,"inward_0p2pct");
        candidateRow.outward_0p2pct_label=label_for( ...
            finalSeed,"outward_0p2pct");
        candidateRow.paper_radius_label=label_for( ...
            finalSeed,"paper_radius_same_direction");
        candidateRow.verdict=boundary_verdict(candidateRow);
        candidateRows=append_struct_row(candidateRows,candidateRow);
        pointRows=[pointRows;seedPoints]; %#ok<AGROW>
    end

    candidatePath=fullfile(outputDirectory, ...
        'candidate_coordinates_and_verdicts.csv');
    pointPath=fullfile(outputDirectory,'independent_probe_results.csv');
    protocolPath=fullfile(outputDirectory,'validation_protocol.mat');
    writetable(candidateRows,candidatePath);
    writetable(pointRows,pointPath);
    sourceSixModelOutput=sixModelOutputDirectory; %#ok<NASGU>
    sourceChildOutput=childDirectory; %#ok<NASGU>
    save(protocolPath,'validation','sourceSixModelOutput', ...
        'sourceChildOutput','seedList');

    fprintf('\nIndependent validation finished.\n');
    fprintf('Candidates: %s\n',candidatePath);
    fprintf('Pointwise results: %s\n',pointPath);
    fprintf('Verdicts:\n');
    disp(candidateRows(:,{'seed','source_R_hat','bracket_lower', ...
        'bracket_upper','bracket_inner_label','bracket_outer_label', ...
        'paper_radius_label','verdict'}));
end

function validation=validation_configuration()
    validation=struct();
    validation.horizons=[2000 4000 8000];
    validation.RelTol=1e-10;
    validation.AbsTol=1e-12;
    validation.MaxStep=0.10;
    validation.outputStep=0.50;
    validation.domainExpansionFactor=2;
    validation.targetRadiusFactor=0.5;
    validation.tailWindow=500;
    validation.periodicWindow=1000;
    validation.minPeriodicCrossings=20;
    validation.maxPeriodCoefficientOfVariation=0.02;
    validation.maxPoincareRecurrenceError=0.05;
    validation.periodicRadiusRatioRange=[0.95 1.05];
    validation.minPeriodicAmplitude=0.05;
    validation.paperReference=0.5737;
end

function probes=build_probes(ray,bestRadius,paperReference)
    names=["inward_1pct";"inward_0p2pct";"bracket_inner"; ...
        "reported_midpoint";"bracket_outer";"outward_0p2pct"; ...
        "outward_1pct";"paper_radius_same_direction"];
    radius=[0.99*bestRadius;0.998*bestRadius;ray.bracket_lower; ...
        bestRadius;ray.bracket_upper;1.002*bestRadius; ...
        1.01*bestRadius;paperReference];
    expected=["target";"target";"target";"boundary"; ...
        "non_target";"non_target";"non_target";"non_target"];
    probes=table(names,radius,expected,'VariableNames', ...
        {'probe','radius','expected_side'});
end

function path=find_detail_file(detailDirectory,seed)
    pattern=sprintf('*seed_%03d*adaptive_s3_radial.mat',seed);
    files=dir(fullfile(detailDirectory,pattern));
    assert(numel(files)==1, ...
        'Expected one detail file for seed %d, found %d.',seed,numel(files));
    path=fullfile(files(1).folder,files(1).name);
end

function z0=state_on_ray(problem,radius,direction)
    z0=problem.target+radius*direction./problem.sqrtWeight;
end

function trajectory=integrate_independently(z0,problem,validation)
    horizon=validation.horizons(end);
    outputTimes=0:validation.outputStep:horizon;
    expandedLower=validation.domainExpansionFactor*problem.lower;
    expandedUpper=validation.domainExpansionFactor*problem.upper;
    targetRadius=validation.targetRadiusFactor*problem.targetMetricRadius;
    options=odeset('RelTol',validation.RelTol, ...
        'AbsTol',validation.AbsTol,'MaxStep',validation.MaxStep, ...
        'Events',@(t,z) validation_events(t,z,problem, ...
        expandedLower,expandedUpper,targetRadius));
    trajectory=struct('success',false,'message',"",'time',[], ...
        'states',[],'event_time',[],'event_index',[]);
    try
        [time,states,eventTime,~,eventIndex]=ode113( ...
            @(t,z) habib_rhs(z,problem.par),outputTimes,z0(:),options);
        trajectory.success=true;
        trajectory.time=time;
        trajectory.states=states;
        trajectory.event_time=eventTime;
        trajectory.event_index=eventIndex;
    catch ME
        trajectory.message=string(getReport(ME,'basic','hyperlinks','off'));
    end
end

function [value,isterminal,direction]=validation_events( ...
        ~,z,problem,lower,upper,targetRadius)
    z=z(:).';
    radius=sqrt(sum((z-problem.target).^2.*problem.weight));
    targetMargin=radius-targetRadius;
    domainMargin=min([z-lower,upper-z]);
    value=[targetMargin;domainMargin];
    isterminal=[1;1];
    direction=[-1;-1];
end

function assessment=assess_at_horizon( ...
        trajectory,problem,validation,horizon)
    assessment=struct('label',"solver_failure", ...
        'reason',"solver_failure",'event_time',NaN, ...
        'minimum_radius',NaN,'final_radius',NaN, ...
        'tail_median_radius',NaN,'tail_radius_ratio',NaN, ...
        'asymptotic_hint',"unavailable",'periodic_detected',false, ...
        'estimated_period',NaN,'period_cv',NaN, ...
        'recurrence_error',NaN,'periodic_cycles',0, ...
        'periodic_observable',NaN);
    if ~trajectory.success, return; end

    targetEvent=trajectory.event_time(trajectory.event_index==1 & ...
        trajectory.event_time<=horizon);
    escapeEvent=trajectory.event_time(trajectory.event_index==2 & ...
        trajectory.event_time<=horizon);
    if ~isempty(targetEvent)
        assessment.label="target";
        assessment.reason="entered_strict_target_ball";
        assessment.event_time=targetEvent(1);
    elseif ~isempty(escapeEvent)
        assessment.label="non_target";
        assessment.reason="left_expanded_domain";
        assessment.event_time=escapeEvent(1);
    else
        assessment.label="unresolved";
        assessment.reason="checkpoint_reached_without_event";
    end

    use=trajectory.time<=horizon;
    time=trajectory.time(use);
    states=trajectory.states(use,:);
    if isempty(time), return; end
    radii=sqrt(sum((states-problem.target).^2.*problem.weight,2));
    assessment.minimum_radius=min(radii);
    assessment.final_radius=radii(end);
    tailStart=max(0,horizon-validation.tailWindow);
    tail=radii(time>=tailStart);
    if isempty(tail), tail=radii; end
    assessment.tail_median_radius=median(tail);
    split=max(1,floor(numel(tail)/2));
    firstMedian=median(tail(1:split));
    secondMedian=median(tail(split:end));
    assessment.tail_radius_ratio=secondMedian/max(firstMedian,eps);
    if assessment.label=="unresolved"
        periodic=detect_periodic_attractor(time,states,problem, ...
            validation,horizon,assessment.tail_radius_ratio);
        assessment.periodic_detected=periodic.detected;
        assessment.estimated_period=periodic.period;
        assessment.period_cv=periodic.period_cv;
        assessment.recurrence_error=periodic.recurrence_error;
        assessment.periodic_cycles=periodic.cycles;
        assessment.periodic_observable=periodic.observable;
        if periodic.detected
            assessment.label="non_target_periodic";
            assessment.reason="persistent_periodic_attractor";
            assessment.asymptotic_hint="non_target_periodic";
            return
        end
    end
    if assessment.label~="unresolved"
        assessment.asymptotic_hint=assessment.label;
    elseif assessment.tail_radius_ratio<0.9
        assessment.asymptotic_hint="approaching_target";
    elseif assessment.tail_radius_ratio>1.1
        assessment.asymptotic_hint="moving_away";
    else
        assessment.asymptotic_hint="persistent_away_or_slow";
    end
end

function result=detect_periodic_attractor( ...
        time,states,problem,validation,horizon,tailRadiusRatio)
    result=struct('detected',false,'period',NaN,'period_cv',NaN, ...
        'recurrence_error',NaN,'cycles',0,'observable',NaN);
    windowStart=max(0,horizon-validation.periodicWindow);
    use=time>=windowStart & time<=horizon;
    tailTime=time(use);
    tailStates=states(use,:);
    if numel(tailTime)<2*validation.minPeriodicCrossings
        return
    end

    weighted=(tailStates-problem.target).*problem.sqrtWeight;
    amplitudes=max(weighted,[],1)-min(weighted,[],1);
    [amplitude,observable]=max(amplitudes);
    result.observable=observable;
    if amplitude<validation.minPeriodicAmplitude
        return
    end

    signal=weighted(:,observable);
    sectionLevel=median(signal);
    crossingIndex=find(signal(1:end-1)<=sectionLevel & ...
        signal(2:end)>sectionLevel);
    if numel(crossingIndex)<validation.minPeriodicCrossings+1
        return
    end

    crossingTime=zeros(numel(crossingIndex),1);
    crossingState=zeros(numel(crossingIndex),size(weighted,2));
    for i=1:numel(crossingIndex)
        k=crossingIndex(i);
        denominator=signal(k+1)-signal(k);
        if abs(denominator)<=eps
            fraction=0;
        else
            fraction=(sectionLevel-signal(k))/denominator;
        end
        fraction=max(0,min(1,fraction));
        crossingTime(i)=tailTime(k)+ ...
            fraction*(tailTime(k+1)-tailTime(k));
        crossingState(i,:)=weighted(k,:)+ ...
            fraction*(weighted(k+1,:)-weighted(k,:));
    end

    periods=diff(crossingTime);
    keep=max(1,numel(periods)-49):numel(periods);
    periods=periods(keep);
    crossingState=crossingState([keep,keep(end)+1],:);
    result.cycles=numel(periods);
    result.period=median(periods);
    result.period_cv=std(periods)/max(mean(periods),eps);
    recurrenceSteps=vecnorm(diff(crossingState,1,1),2,2);
    orbitScale=median(vecnorm(weighted,2,2));
    result.recurrence_error=median(recurrenceSteps)/max(orbitScale,eps);
    stationary=tailRadiusRatio>=validation.periodicRadiusRatioRange(1) && ...
        tailRadiusRatio<=validation.periodicRadiusRatioRange(2);
    result.detected=result.cycles>=validation.minPeriodicCrossings && ...
        result.period_cv<=validation.maxPeriodCoefficientOfVariation && ...
        result.recurrence_error<=validation.maxPoincareRecurrenceError && ...
        stationary;
end

function dz=habib_rhs(z,par)
    z=z(:);
    dz=zeros(4,1);
    dz(1)=z(2);
    dz(2)=par(1)*z(1)+par(2)*z(2)+par(3)*z(4)+ ...
        par(4)*z(1)*z(2)*z(3)+par(5)*z(1)*z(3)*z(4)+ ...
        par(6)*z(1)*z(3)^2+par(7)*z(1)^2*z(2)+ ...
        par(8)*z(2)*z(3)^2+par(9)*z(1)^2*z(3)+ ...
        par(10)*z(1)^2*z(4)+par(11)*z(3)^2*z(4)+ ...
        par(23)*z(1)^3+par(24)*z(3)^3;
    dz(3)=z(4);
    dz(4)=par(12)*z(2)+par(13)*z(3)+par(14)*z(4)+ ...
        par(15)*z(1)*z(2)*z(3)+par(16)*z(1)*z(3)*z(4)+ ...
        par(17)*z(1)*z(3)^2+par(18)*z(1)^2*z(2)+ ...
        par(19)*z(2)*z(3)^2+par(20)*z(1)^2*z(3)+ ...
        par(21)*z(1)^2*z(4)+par(22)*z(3)^2*z(4)+ ...
        par(25)*z(1)^3+par(26)*z(3)^3;
end

function label=label_for(rows,probe)
    hit=rows.probe==probe;
    assert(nnz(hit)==1,'Missing final result for probe %s.',probe);
    label=string(rows.label(hit));
end

function verdict=boundary_verdict(row)
    bracketValid=row.bracket_inner_label=="target" && ...
        is_non_target(row.bracket_outer_label);
    robustValid=row.inward_0p2pct_label=="target" && ...
        is_non_target(row.outward_0p2pct_label);
    if bracketValid && robustValid
        verdict="validated_sharp_boundary";
    elseif bracketValid
        verdict="validated_original_bracket_only";
    else
        verdict="not_validated";
    end
end

function result=is_non_target(label)
    result=startsWith(string(label),"non_target");
end

function T=append_struct_row(T,row)
    newRow=struct2table(row,'AsArray',true);
    if isempty(T), T=newRow; else, T=[T;newRow]; end %#ok<AGROW>
end

function values=table_column(T,requestedName)
    names=string(T.Properties.VariableNames);
    normalized=regexprep(lower(names),'[^a-z0-9]','');
    requested=regexprep(lower(string(requestedName)),'[^a-z0-9]','');
    index=find(normalized==requested,1);
    assert(~isempty(index), ...
        'CSV column "%s" was not found. Available columns: %s', ...
        requestedName,strjoin(names,', '));
    values=T{:,index};
end

function values=numeric_column(T,requestedName)
    values=table_column(T,requestedName);
    if isnumeric(values) || islogical(values)
        values=double(values);
    else
        values=str2double(string(values));
    end
end
