% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
function outDir = run_experiment_C_highdim_vdp_tmd(seedList,runMode,resumeDir)
%RUN_EXPERIMENT_C_HIGHDIM_VDP_TMD High-dimensional DynIn GA transfer test.
%
% The original four-dimensional Duffing-Van der Pol + NLTVA model and the
% original DynIn GA branch (type_x0 = 1) are called unchanged.  Parameter
% rules use only the target Jacobian, a local Lyapunov contraction test,
% the published metric and the computational domain.  No reference LIM is
% available or used for tuning this benchmark.

    if nargin < 1 || isempty(seedList), seedList = 1:10; end
    if nargin < 2 || isempty(runMode), runMode = 'screening'; end
    if nargin < 3, resumeDir = ''; end

    runMode = validatestring(char(runMode), ...
        {'screening','confirmation','smoke','design'});
    seedList = unique(seedList(:).','stable');
    validateattributes(seedList,{'numeric'}, ...
        {'integer','positive','finite','nonempty'});
    if strcmp(runMode,'smoke'), seedList = seedList(1); end

    scriptRoot = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(scriptRoot);
    dyninRoot = fullfile(repoRoot,'work','DynIn','DynIn_v1.1.0');
    originalFunctionsDir = fullfile(dyninRoot,'functions');
    modelDir = fullfile(dyninRoot,'VanDerPolDuffing_NLTVA');
    assert(isfile(fullfile(originalFunctionsDir,'compute_LIM_FP.m')), ...
        'Original compute_LIM_FP.m was not found at %s.',originalFunctionsDir);
    assert(isfile(fullfile(modelDir,'sistema.m')) && ...
        isfile(fullfile(modelDir,'coefficients_VDPD_NLTVA.m')), ...
        'The original four-dimensional Habib model was not found at %s.',modelDir);

    if isempty(resumeDir)
        stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
        outDir = fullfile(scriptRoot, ...
            ['outputs_refined_C_habib_vdp_tmd_' stamp]);
        mkdir(outDir);
    else
        outDir = char(resumeDir);
        assert(isfolder(outDir),'Resume directory does not exist: %s',outDir);
    end

    previousPath = path;
    pathCleanup = onCleanup(@() path(previousPath));
    restoredefaultpath;
    rehash toolboxcache;
    addpath(scriptRoot,'-begin');
    addpath(modelDir,'-begin');
    addpath(originalFunctionsDir,'-begin');
    assert_same_file(which('compute_LIM_FP'), ...
        fullfile(originalFunctionsDir,'compute_LIM_FP.m'),'compute_LIM_FP');
    assert_same_file(which('sistema'),fullfile(modelDir,'sistema.m'),'sistema');
    assert_same_file(which('coefficients_VDPD_NLTVA'), ...
        fullfile(modelDir,'coefficients_VDPD_NLTVA.m'), ...
        'coefficients_VDPD_NLTVA');

    cases = build_cases();
    if strcmp(runMode,'smoke'), cases = cases(2,:); end
    [design,audit,pilotAudit] = build_design(cases,runMode);
    schedule = build_schedule(design,seedList,20260920);

    designPath = fullfile(outDir,'experiment_C_highdim_design.csv');
    auditPath = fullfile(outDir,'jacobian_parameter_audit.csv');
    pilotAuditPath = fullfile(outDir,'pilot_horizon_audit.csv');
    sourceAuditPath = fullfile(outDir,'paper_baseline_parameter_sources.csv');
    schedulePath = fullfile(outDir,'randomized_execution_schedule.csv');
    rawPath = fullfile(outDir,'raw_data_all_runs.csv');
    checkpointPath = fullfile(outDir,'checkpoint.mat');
    writetable(design,designPath);
    writetable(audit,auditPath);
    writetable(pilotAudit,pilotAuditPath);
    write_paper_baseline_source_audit(sourceAuditPath);
    if isfile(schedulePath)
        stored = readtable(schedulePath,'TextType','string');
        assert(isequal(string(stored.run_key),string(schedule.run_key)), ...
            'Resume schedule differs from the stored schedule.');
    else
        writetable(schedule,schedulePath);
    end
    write_manifest(fullfile(outDir,'run_manifest.txt'),runMode,seedList, ...
        originalFunctionsDir,modelDir,cases,design);

    if strcmp(runMode,'design')
        fprintf('High-dimensional Experiment C design written:\n%s\n%s\n%s\n', ...
            designPath,auditPath,pilotAuditPath);
        return
    end

    if isfile(rawPath)
        raw = readtable(rawPath,'TextType','string');
    else
        raw = table();
    end
    completed = completed_keys(raw);
    totalRuns = height(schedule);
    runCounter = numel(completed);

    fprintf('DynIn Experiment C: Habib 4-D Duffing-VdP + NLTVA / %s mode\n', ...
        upper(runMode));
    fprintf('Original model and DynIn GA branch retained: type_x0 = 1\n');
    fprintf('Cases: %d; profiles: %d; paired seeds: %d; runs: %d\n', ...
        height(cases),numel(unique(design.profile_id)), ...
        numel(seedList),totalRuns);
    fprintf('No analytical LIM is used; evidence comes from seed and budget stability.\n');
    fprintf('Output directory:\n%s\n\n',outDir);

    for iRun = 1:height(schedule)
        key = string(schedule.run_key(iRun));
        if any(completed == key), continue; end
        cfgRow = design(design.design_id == schedule.design_id(iRun),:);
        assert(height(cfgRow)==1,'Unknown design row: %s',key);
        cfg = table_row_to_struct(cfgRow);
        seed = schedule.seed(iRun);
        runCounter = runCounter+1;
        fprintf('[run %d/%d] START case=%s, seed=%d, profile=%s\n', ...
            runCounter,totalRuns,cfg.case_id,seed,cfg.profile_id);
        rng(schedule.algorithm_rng_seed(iRun),'twister');
        result = execute_one_run(cfg);
        if result.success
            fprintf('[run %d/%d] DONE  R=%.6g, tail.change=%.3g, wall=%.2fs\n', ...
                runCounter,totalRuns,result.R_hat, ...
                result.tail_relative_change,result.wall_runtime_s);
        else
            fprintf('[run %d/%d] FAILED %s\n', ...
                runCounter,totalRuns,result.error_message);
        end
        row = cfg;
        row.run_key = key;
        row.seed = seed;
        row.execution_order = schedule.execution_order(iRun);
        row.algorithm_rng_seed = schedule.algorithm_rng_seed(iRun);
        names = fieldnames(result);
        for i = 1:numel(names), row.(names{i}) = result.(names{i}); end
        if isempty(raw)
            raw = struct2table(row,'AsArray',true);
        else
            raw = [raw; struct2table(row,'AsArray',true)]; %#ok<AGROW>
        end
        atomic_write_table(raw,rawPath);
        save(checkpointPath,'raw','design','audit','pilotAudit','schedule','cases', ...
            'seedList','runMode','-v7.3');
        completed(end+1,1) = key; %#ok<AGROW>
    end

    summary = summarize_results(raw);
    contrasts = summarize_contrasts(raw,design);
    convergence = build_budget_stability(summary);
    writetable(summary,fullfile(outDir,'summary_by_case_and_profile.csv'));
    writetable(contrasts,fullfile(outDir,'paired_contrasts_parameter_blocks.csv'));
    writetable(convergence,fullfile(outDir,'budget_stability_matrix.csv'));
    fprintf('\nHigh-dimensional Experiment C finished.\n');
    fprintf('Raw runs: %s\n',rawPath);
    fprintf('Summary:  %s\n',fullfile(outDir,'summary_by_case_and_profile.csv'));
    fprintf('Contrasts: %s\n', ...
        fullfile(outDir,'paired_contrasts_parameter_blocks.csv'));
end

function cases = build_cases()
    mu1Values = [0.065 0.075 0.095];
    labels = ["near_fold","paper_default","near_hopf"];
    rows = cell(numel(mu1Values),1);
    for i = 1:numel(mu1Values)
        row = struct();
        row.case_id = "mu1_"+replace(sprintf('%.3f',mu1Values(i)),'.','p');
        row.parameter_label = labels(i);
        row.gamma = 0.97;
        row.mu2 = 0.12;
        row.r = 0.05;
        row.alpha3 = 0.30;
        row.beta3 = 0;
        row.mu1 = mu1Values(i);
        rows{i} = row;
    end
    cases = struct2table(vertcat(rows{:}));
    cases.case_order = (1:height(cases)).';
    cases = movevars(cases,'case_order','Before',1);
end

function [design,auditTable,pilotAudit] = build_design(cases,runMode)
    rows = cell(0,1);
    auditRows = cell(height(cases),1);
    pilotBlocks = cell(height(cases),1);
    target = zeros(1,4);
    domain = [-3 -3 -3 -3 3 3 3 3];
    for iCase = 1:height(cases)
        c = table_row_to_struct(cases(iCase,:));
        [par,weight] = coefficients_VDPD_NLTVA( ...
            c.gamma,c.mu2,c.r,c.alpha3,c.beta3,c.mu1);
        rhs = @(z) sistema(0,z,par);
        A = numerical_jacobian(rhs,target(:));
        [estimated,audit] = estimate_dynin_parameters_from_jacobian( ...
            A,rhs,target,weight,domain);
        fprintf('[pilot %d/%d] case=%s: calibrating integration horizon ...\n', ...
            iCase,height(cases),c.case_id);
        [pilotTfinal,pilotRows] = calibrate_tfinal_with_pilots( ...
            rhs,target,weight,domain,estimated,c.case_id,c.parameter_label);
        pilotBlocks{iCase} = pilotRows;
        audit.case_id = c.case_id;
        audit.parameter_label = c.parameter_label;
        audit.mu1 = c.mu1;
        auditRows{iCase} = audit;

        published = habib_paper_profile(weight,domain,estimated);
        published.profile_id = "habib_paper_GA_N40";
        published.profile_label = "Habib paper-reported GA configuration; N=40";
        published.profile_order = 1;
        published.physics_rule_complete = false;

        spatial = published;
        spatial.profile_id = "jacobian_spatial_N40";
        spatial.profile_label = "Add Jacobian-Lyapunov grid and target belt";
        spatial.profile_order = 2;
        spatial.discr = estimated.discr;
        spatial.num_of_cell_around_equilibrium = ...
            estimated.num_of_cell_around_equilibrium;

        sampled = spatial;
        sampled.profile_id = "jacobian_Ts_N40";
        sampled.profile_label = "Add Jacobian sampling interval only; N=40";
        sampled.profile_order = 3;
        sampled.Ts = estimated.Ts;

        periodic = sampled;
        periodic.profile_id = "jacobian_rep_periodic_N40";
        periodic.profile_label = "Add decay-aware periodic threshold; N=40";
        periodic.profile_order = 4;
        periodic.rep_periodic = estimated.rep_periodic;

        frozen40 = periodic;
        frozen40.profile_id = "frozen_classifier_N40";
        frozen40.profile_label = "Add pilot-validated horizon; N=40";
        frozen40.profile_order = 5;
        frozen40.physics_rule_complete = true;
        frozen40.tfinal = pilotTfinal;

        full100 = frozen40;
        full100.profile_id = "frozen_classifier_N100";
        full100.profile_label = "Frozen classifier; N=100";
        full100.profile_order = 6;
        full100.number_of_steps = 100;

        full200 = frozen40;
        full200.profile_id = "frozen_classifier_N200";
        full200.profile_label = "Frozen classifier; N=200";
        full200.profile_order = 7;
        full200.number_of_steps = 200;

        if strcmp(runMode,'confirmation')
            profiles = {published,frozen40,full100,full200};
        elseif strcmp(runMode,'smoke')
            profiles = {published,spatial,sampled,periodic,frozen40};
        else
            profiles = {published,spatial,sampled,periodic, ...
                frozen40,full100,full200};
        end
        for iProfile = 1:numel(profiles)
            rows{end+1,1} = design_row(c,profiles{iProfile}); %#ok<AGROW>
        end
    end
    design = struct2table(vertcat(rows{:}));
    design.design_id = (1:height(design)).';
    design = movevars(design,'design_id','Before',1);
    auditTable = struct2table(vertcat(auditRows{:}));
    pilotAudit = vertcat(pilotBlocks{:});
end

function [selectedTfinal,auditTable] = calibrate_tfinal_with_pilots( ...
        rhs,target,weight,domain,estimated,caseId,parameterLabel)
% Increase the horizon until no additional pilot trajectory reaches the
% target belt between T and 2T for two consecutive rounds.
    d = numel(target);
    lower = domain(1:d);
    upper = domain(d+1:end);
    cellWidth = (upper-lower)/estimated.discr;
    targetHalfWidth = 0.5*estimated.num_of_cell_around_equilibrium*cellWidth;
    pilotPoints = build_pilot_points(target,weight,lower,upper);
    currentT = max(50,estimated.tfinal);
    maximumT = 8000;
    requiredStableRounds = 2;
    stableRounds = 0;
    roundNumber = 0;
    rows = cell(0,1);

    while true
        roundNumber = roundNumber+1;
        doubledT = min(2*currentT,maximumT);
        hitTimes = inf(size(pilotPoints,1),1);
        failed = false(size(pilotPoints,1),1);
        timer = tic;
        for iPoint = 1:size(pilotPoints,1)
            options = odeset('RelTol',1e-8,'AbsTol',1e-9, ...
                'Events',@(t,x) target_belt_event( ...
                    t,x,target(:),targetHalfWidth(:)));
            try
                [~,~,eventTime] = ode45(@(~,x) rhs(x), ...
                    [0 doubledT],pilotPoints(iPoint,:).',options);
                if ~isempty(eventTime), hitTimes(iPoint)=eventTime(1); end
            catch
                failed(iPoint)=true;
            end
        end
        hitByT = hitTimes<=currentT;
        hitBy2T = hitTimes<=doubledT;
        lateHits = nnz(hitBy2T & ~hitByT);
        if lateHits==0 && ~any(failed)
            stableRounds=stableRounds+1;
        else
            stableRounds=0;
        end
        row = struct();
        row.case_id = string(caseId);
        row.parameter_label = string(parameterLabel);
        row.pilot_round = roundNumber;
        row.T = currentT;
        row.two_T = doubledT;
        row.n_pilot_points = size(pilotPoints,1);
        row.n_target_by_T = nnz(hitByT);
        row.n_target_by_2T = nnz(hitBy2T);
        row.n_late_target_captures = lateHits;
        row.n_not_target_by_2T = nnz(~hitBy2T & ~failed);
        row.n_failed_integrations = nnz(failed);
        row.consecutive_stable_rounds = stableRounds;
        row.pilot_runtime_s = toc(timer);
        row.selected_round = false;
        rows{end+1,1}=row; %#ok<AGROW>
        fprintf('  round %d: T=%g, 2T=%g, target=%d/%d, late=%d, failed=%d\n', ...
            roundNumber,currentT,doubledT,nnz(hitBy2T),size(pilotPoints,1), ...
            lateHits,nnz(failed));
        if stableRounds>=requiredStableRounds || doubledT>=maximumT
            selectedTfinal=doubledT;
            rows{end}.selected_round=true;
            break
        end
        currentT=doubledT;
    end
    auditTable=struct2table(vertcat(rows{:}));
end

function points = build_pilot_points(target,weight,lower,upper)
    d=numel(target);
    targetColumn=target(:);
    lowerColumn=lower(:);
    upperColumn=upper(:);
    directions=[eye(d),-eye(d)];
    stream=RandStream('mt19937ar','Seed',20260921+d);
    extra=randn(stream,d,4);
    directions=[directions,extra];
    for i=1:size(directions,2)
        directions(:,i)=directions(:,i)/ ...
            sqrt(sum(weight(:).*directions(:,i).^2));
    end
    fractions=[0.30 0.60 0.90];
    points=zeros(size(directions,2)*numel(fractions),d);
    k=0;
    for i=1:size(directions,2)
        u=directions(:,i);
        limits=inf(d,1);
        positive=u>1e-12;
        negative=u<-1e-12;
        limits(positive)=(upperColumn(positive)-targetColumn(positive))./u(positive);
        limits(negative)=(lowerColumn(negative)-targetColumn(negative))./u(negative);
        radialLimit=min(limits);
        for fraction=fractions
            k=k+1;
            points(k,:)=(targetColumn+fraction*radialLimit*u).';
        end
    end
end

function [value,isterminal,direction] = target_belt_event( ...
        ~,state,target,targetHalfWidth)
    value=max(abs(state-target)./targetHalfWidth)-1;
    isterminal=1;
    direction=-1;
end

function cfg = habib_paper_profile(weight,domain,estimated)
% Parameters explicitly reported by Habib are copied from Table 1, the
% classification text, and Fig. 7. Parameters absent from the article are
% kept as separately disclosed implementation controls; they are never
% labelled as paper-reported values.
    cfg = struct();
    cfg.profile_id = "";
    cfg.profile_label = "";
    cfg.profile_order = NaN;
    cfg.physics_rule_complete = false;
    cfg.weight = weight;
    cfg.domain = domain;
    cfg.discr = 701;
    cfg.num_of_cell_around_equilibrium = 1;
    cfg.tfinal = max(50,estimated.tfinal);
    cfg.Ts = 0.05;
    cfg.reltol = 1e-8;
    cfg.abstol = 1e-8;
    cfg.number_of_steps = 40;
    cfg.rep_fix_point = 40;
    cfg.rep_periodic = 5;
    cfg.divR = 40;
    cfg.num_gen = 5;
    cfg.num_crossover = 9;
    cfg.selected_opt = 3;
    cfg.newcomers = 8;
    cfg.num_almost_clones = 2;
end

function row = design_row(c,cfg)
    row = c;
    row.profile_id = cfg.profile_id;
    row.profile_label = cfg.profile_label;
    row.profile_order = cfg.profile_order;
    row.physics_rule_complete = cfg.physics_rule_complete;
    for i = 1:4
        row.(sprintf('weight_%d',i)) = cfg.weight(i);
        row.(sprintf('domain_min_%d',i)) = cfg.domain(i);
        row.(sprintf('domain_max_%d',i)) = cfg.domain(4+i);
    end
    row.discr = cfg.discr;
    row.num_of_cell_around_equilibrium = ...
        cfg.num_of_cell_around_equilibrium;
    row.tfinal = cfg.tfinal;
    row.Ts = cfg.Ts;
    row.reltol = cfg.reltol;
    row.abstol = cfg.abstol;
    row.number_of_steps = cfg.number_of_steps;
    row.rep_fix_point = cfg.rep_fix_point;
    row.rep_periodic = cfg.rep_periodic;
    row.divR = cfg.divR;
    row.num_gen = cfg.num_gen;
    row.num_crossover = cfg.num_crossover;
    row.selected_opt = cfg.selected_opt;
    row.newcomers = cfg.newcomers;
    row.num_almost_clones = cfg.num_almost_clones;
    row.population_size = 1+cfg.num_crossover+cfg.newcomers+ ...
        cfg.num_almost_clones;
end

function A = numerical_jacobian(rhs,target)
    d = numel(target);
    A = zeros(d);
    for i = 1:d
        step = sqrt(eps)*(1+abs(target(i)));
        delta = zeros(d,1);
        delta(i) = step;
        A(:,i) = (rhs(target+delta)-rhs(target-delta))/(2*step);
    end
end

function schedule = build_schedule(design,seedList,scheduleSeed)
    n = height(design)*numel(seedList);
    designId = zeros(n,1); seed = zeros(n,1); algorithmSeed = zeros(n,1);
    runKey = strings(n,1); k = 0;
    for iSeed = 1:numel(seedList)
        for iDesign = 1:height(design)
            k = k+1;
            designId(k) = design.design_id(iDesign);
            seed(k) = seedList(iSeed);
            algorithmSeed(k) = 100000+seedList(iSeed);
            runKey(k) = make_key(design.case_id(iDesign), ...
                design.profile_id(iDesign),seedList(iSeed));
        end
    end
    stream = RandStream('mt19937ar','Seed',scheduleSeed);
    order = randperm(stream,n).';
    schedule = table(designId(order),seed(order),algorithmSeed(order), ...
        runKey(order),'VariableNames', ...
        {'design_id','seed','algorithm_rng_seed','run_key'});
    schedule.execution_order = (1:n).';
    schedule = movevars(schedule,'execution_order','Before',1);
end

function result = execute_one_run(cfg)
    result = struct('success',false,'R_hat',NaN, ...
        'wall_runtime_s',NaN,'algorithm_runtime_s',NaN, ...
        'trajectory_evaluations',NaN,'processed_time_samples',NaN, ...
        'completed_iterations',NaN,'tail_relative_change',NaN, ...
        'tail_relative_range',NaN,'error_message',"");
    [par,~] = coefficients_VDPD_NLTVA( ...
        cfg.gamma,cfg.mu2,cfg.r,cfg.alpha3,cfg.beta3,cfg.mu1);
    target = zeros(1,4);
    weight = [cfg.weight_1 cfg.weight_2 cfg.weight_3 cfg.weight_4];
    lower = [cfg.domain_min_1 cfg.domain_min_2 ...
             cfg.domain_min_3 cfg.domain_min_4];
    upper = [cfg.domain_max_1 cfg.domain_max_2 ...
             cfg.domain_max_3 cfg.domain_max_4];
    args = struct('tfinal',cfg.tfinal,'Ts',cfg.Ts,'weight',weight, ...
        'type_x0',1,'reltol',cfg.reltol,'abstol',cfg.abstol, ...
        'number_of_steps',cfg.number_of_steps, ...
        'num_of_cell_around_equilibrium',cfg.num_of_cell_around_equilibrium, ...
        'num_fig',1001,'plot_results',0,'plot_results_final',0, ...
        'spaceboundary',[lower upper],'discr',cfg.discr,'automatic',1, ...
        'var1',1,'var2',2,'rep_fix_point',cfg.rep_fix_point, ...
        'rep_periodic',cfg.rep_periodic,'min_periodic_radius',0.005, ...
        'check_min_periodic',1,'check_equilibrium',0, ...
        'max_check_step',10000,'divR',cfg.divR,'num_gen',cfg.num_gen, ...
        'num_crossover',cfg.num_crossover,'selected_opt',cfg.selected_opt, ...
        'newcomers',cfg.newcomers, ...
        'num_almost_clones',cfg.num_almost_clones,'bis_iter_max',5);
    timer = tic;
    try
        vals = optional_values(args,target);
        [Rhat,OutL] = compute_LIM_FP(target,par,vals{:});
        result.wall_runtime_s = toc(timer);
        result.R_hat = Rhat;
        result.algorithm_runtime_s = safe_scalar(OutL,'total_time');
        result.trajectory_evaluations = count_evaluations(OutL);
        result.processed_time_samples = sum_finite(OutL,'time_steps_sim');
        if isfield(OutL,'R')
            trace = OutL.R(:);
            trace = trace(isfinite(trace));
            result.completed_iterations = numel(trace);
            if numel(trace)>=2
                tail = trace(max(1,end-min(9,numel(trace)-1)):end);
                scale = max(abs(trace(end)),eps);
                result.tail_relative_change = abs(trace(end)-tail(1))/scale;
                result.tail_relative_range = (max(tail)-min(tail))/scale;
            end
        end
        result.success = isfinite(Rhat);
        if ~result.success
            result.error_message = "compute_LIM_FP returned a non-finite LIM";
        end
    catch ME
        result.wall_runtime_s = toc(timer);
        result.error_message = string(getReport(ME,'basic','hyperlinks','off'));
    end
end

function summary = summarize_results(raw)
    caseIds = unique(raw.case_id,'stable');
    profileIds = unique(raw.profile_id,'stable');
    rows = cell(0,1);
    for iCase = 1:numel(caseIds)
        for iProfile = 1:numel(profileIds)
            g = raw(raw.case_id==caseIds(iCase) & ...
                raw.profile_id==profileIds(iProfile),:);
            if isempty(g), continue; end
            row = struct();
            row.case_id = caseIds(iCase);
            row.parameter_label = g.parameter_label(1);
            row.mu1 = g.mu1(1);
            row.profile_id = profileIds(iProfile);
            row.profile_label = g.profile_label(1);
            row.profile_order = g.profile_order(1);
            row.n_runs = height(g);
            row.n_success = nnz(g.success);
            row.median_R_hat = median_finite(g.R_hat);
            row.p05_R_hat = percentile_finite(g.R_hat,5);
            row.p95_R_hat = percentile_finite(g.R_hat,95);
            row.relative_seed_spread = ...
                (row.p95_R_hat-row.p05_R_hat)/max(abs(row.median_R_hat),eps);
            row.median_tail_relative_change = ...
                median_finite(g.tail_relative_change);
            row.median_tail_relative_range = ...
                median_finite(g.tail_relative_range);
            row.median_wall_runtime_s = median_finite(g.wall_runtime_s);
            row.median_trajectory_evaluations = ...
                median_finite(g.trajectory_evaluations);
            rows{end+1,1} = row; %#ok<AGROW>
        end
    end
    summary = struct2table(vertcat(rows{:}));
    summary = sortrows(summary,{'case_id','profile_order'});
end

function contrasts = summarize_contrasts(raw,design)
    available = unique(string(design.profile_id),'stable');
    pairFrom = ["habib_paper_GA_N40","jacobian_spatial_N40", ...
        "jacobian_Ts_N40","jacobian_rep_periodic_N40", ...
        "frozen_classifier_N40","frozen_classifier_N100"];
    pairTo = ["jacobian_spatial_N40","jacobian_Ts_N40", ...
        "jacobian_rep_periodic_N40","frozen_classifier_N40", ...
        "frozen_classifier_N100","frozen_classifier_N200"];
    caseIds = unique(raw.case_id,'stable');
    rows = cell(0,1);
    for iCase = 1:numel(caseIds)
        g = raw(raw.case_id==caseIds(iCase),:);
        for iPair = 1:numel(pairFrom)
            if ~any(available==pairFrom(iPair)) || ...
                    ~any(available==pairTo(iPair)), continue; end
            from = g(g.profile_id==pairFrom(iPair),:);
            to = g(g.profile_id==pairTo(iPair),:);
            [shared,ia,ib] = intersect(from.seed,to.seed,'stable');
            if isempty(shared), continue; end
            row = struct();
            row.case_id = caseIds(iCase);
            row.from_profile = pairFrom(iPair);
            row.to_profile = pairTo(iPair);
            row.n_paired = numel(shared);
            row.median_delta_R_hat = median_finite(to.R_hat(ib)-from.R_hat(ia));
            row.median_relative_delta_R = median_finite( ...
                abs(to.R_hat(ib)-from.R_hat(ia))./max(abs(from.R_hat(ia)),eps));
            row.median_runtime_ratio = median_finite( ...
                to.wall_runtime_s(ib)./from.wall_runtime_s(ia));
            row.median_delta_tail_change = median_finite( ...
                to.tail_relative_change(ib)-from.tail_relative_change(ia));
            rows{end+1,1} = row; %#ok<AGROW>
        end
    end
    if isempty(rows), contrasts=table();
    else, contrasts=struct2table(vertcat(rows{:})); end
end

function matrix = build_budget_stability(summary)
    keep = startsWith(string(summary.profile_id),'frozen_classifier_N');
    matrix = summary(keep,{'case_id','parameter_label','mu1','profile_id', ...
        'n_runs','n_success','median_R_hat','relative_seed_spread', ...
        'median_tail_relative_change','median_tail_relative_range', ...
        'median_wall_runtime_s','median_trajectory_evaluations'});
    matrix.seed_stability_pass = matrix.relative_seed_spread<=0.05;
    matrix.tail_stability_pass = matrix.median_tail_relative_change<=0.01;
    matrix.complete_run_pass = matrix.n_success==matrix.n_runs;
end

function write_paper_baseline_source_audit(pathName)
% Keep the publication evidence separate from executable controls that the
% paper does not numerically specify.
    parameter = ["model parameters r, gamma, mu2, alpha, mu1"; ...
        "initial-condition selector"; "cells per direction"; ...
        "phase-space boundaries"; "sampling interval Ts"; ...
        "RelTol and AbsTol"; "GA generations"; ...
        "individuals per generation"; "outer iterations"; ...
        "modal distance weights"; "fixed-point repeats"; ...
        "periodic-cell repeats"; "target-neighbourhood cells"; ...
        "maximum integration horizon tfinal"; ...
        "GA population composition"; "near-point merge divisor divR"];
    value = ["0.05, 0.97, 0.12, 0.3, case-specific mu1"; ...
        "GA (type_x0=1 in software)"; "701"; "[-3,3]^4"; "0.05"; ...
        "1e-8 / 1e-8"; "5"; "20"; "40"; ...
        "[omega1^2, omega2^2, 1, 1]"; "40"; "5"; ...
        "1 (only the equilibrium cell)"; ...
        "Jacobian lower bound, then tested by pilot profile"; ...
        "1 elite + 9 crossover + 8 newcomers + 2 near-clones"; "40"];
    evidence = ["Section 4.2"; "Section 3.3.3"; "Table 1"; ...
        "Table 1"; "Table 1"; "Table 1"; "Table 1"; "Table 1"; ...
        "Figure 7"; "Equations (3)-(4), Section 4.2"; ...
        "Section 3.3.1 default"; "Section 3.3.1 default"; ...
        "Section 3.3.1 states the equilibrium cell; no numeric belt reported"; ...
        "Not numerically reported"; "Not numerically reported"; ...
        "Not numerically reported"];
    status = [repmat("paper_reported",12,1); ...
        "paper_literal_minimum"; repmat("implementation_control",3,1)];
    note = strings(size(parameter));
    note(13) = "No surrounding cells are pre-labelled in the paper baseline.";
    note(14) = "Not imported from Starter; kept separate from the paper baseline claim.";
    note(15) = "Sums to the reported population size 20; split is a software control.";
    note(16) = "Software control used only to merge nearby tracked points.";
    T = table(parameter,value,evidence,status,note);
    writetable(T,pathName);
end

function vals = optional_values(args,target)
    defaults = struct('tfinal',1000,'Ts',0.05,'weight',ones(1,numel(target)), ...
        'type_x0',1,'reltol',1e-6,'abstol',1e-6,'number_of_steps',50, ...
        'num_of_cell_around_equilibrium',3,'num_fig',1001, ...
        'plot_results',0,'plot_results_final',0, ...
        'spaceboundary',[target-10 target+10],'discr',1001,'automatic',0, ...
        'var1',1,'var2',2,'rep_fix_point',40,'rep_periodic',10, ...
        'min_periodic_radius',0.005,'check_min_periodic',0, ...
        'check_equilibrium',1,'max_check_step',10000,'divR',40, ...
        'num_gen',5,'num_crossover',9,'selected_opt',3,'newcomers',8, ...
        'num_almost_clones',2,'bis_iter_max',5);
    names = fieldnames(args);
    for i = 1:numel(names), defaults.(names{i})=args.(names{i}); end
    order = {'tfinal','Ts','weight','type_x0','reltol','abstol', ...
        'number_of_steps','num_of_cell_around_equilibrium','num_fig', ...
        'plot_results','plot_results_final','spaceboundary','discr', ...
        'automatic','var1','var2','rep_fix_point','rep_periodic', ...
        'min_periodic_radius','check_min_periodic','check_equilibrium', ...
        'max_check_step','divR','num_gen','num_crossover','selected_opt', ...
        'newcomers','num_almost_clones','bis_iter_max'};
    vals = cell(size(order));
    for i = 1:numel(order), vals{i}=defaults.(order{i}); end
end

function keys = completed_keys(raw)
    if isempty(raw) || ~ismember('run_key',raw.Properties.VariableNames)
        keys = strings(0,1);
    else
        keys = string(raw.run_key);
    end
end

function key = make_key(caseId,profileId,seed)
    key = string(caseId)+"__"+string(profileId)+"__seed_"+string(seed);
end

function s = table_row_to_struct(row)
    s = table2struct(row);
end

function value = safe_scalar(s,name)
    value = NaN;
    if isstruct(s) && isfield(s,name)
        x=s.(name); x=x(isfinite(x));
        if ~isempty(x), value=x(end); end
    end
end

function value = count_evaluations(OutL)
    if isstruct(OutL) && isfield(OutL,'time_steps_sim')
        value = nnz(isfinite(OutL.time_steps_sim));
    else
        value = NaN;
    end
end

function value = sum_finite(s,name)
    value=NaN;
    if isstruct(s) && isfield(s,name)
        x=s.(name); x=x(isfinite(x));
        if ~isempty(x), value=sum(x); end
    end
end

function value = median_finite(x)
    x=x(isfinite(x));
    if isempty(x), value=NaN; else, value=median(x); end
end

function value = percentile_finite(x,p)
    x=sort(x(isfinite(x)));
    if isempty(x), value=NaN; return; end
    if isscalar(x), value=x; return; end
    q=1+(numel(x)-1)*p/100; lo=floor(q); hi=ceil(q);
    value=x(lo)+(q-lo)*(x(hi)-x(lo));
end

function atomic_write_table(T,pathName)
    [folder,name,extension]=fileparts(pathName);
    tempName=fullfile(folder,[name '.tmp' extension]);
    writetable(T,tempName,'FileType','text');
    movefile(tempName,pathName,'f');
end

function assert_same_file(actual,expected,label)
    normalize=@(p) lower(strrep(char(p),'/','\'));
    assert(strcmp(normalize(actual),normalize(expected)), ...
        'Wrong %s resolved. Expected %s, got %s.',label,expected,actual);
end

function write_manifest(pathName,runMode,seedList,functionDir,modelDir,cases,design)
    fid=fopen(pathName,'w');
    assert(fid>=0,'Could not write manifest.');
    cleaner=onCleanup(@() fclose(fid));
    fprintf(fid,'Experiment C: high-dimensional physics-guided DynIn GA tuning\n');
    fprintf(fid,'Created: %s\n',char(datetime('now')));
    fprintf(fid,'Model: Habib Duffing-Van der Pol + NLTVA (4 states)\n');
    fprintf(fid,'Mode: %s\nSeeds: %s\n',runMode,mat2str(seedList));
    fprintf(fid,'Original functions: %s\nOriginal model: %s\n',functionDir,modelDir);
    fprintf(fid,'Cases: %d; design rows: %d\n',height(cases),height(design));
    fprintf(fid,'Original sistema.m, coefficient function and compute_LIM_FP.m are unchanged.\n');
    fprintf(fid,'The GA branch type_x0=1 is used in every profile.\n');
    fprintf(fid,'Baseline: Habib paper-reported GA configuration, 40 iterations.\n');
    fprintf(fid,'Paper values: discr=701, domain=[-3,3]^4, Ts=0.05, tolerances=1e-8, generations=5, population=20.\n');
    fprintf(fid,'Paper-text defaults: rep_fix_point=40 and rep_periodic=5.\n');
    fprintf(fid,'No Starter numerical setting is used as the baseline.\n');
    fprintf(fid,'Unreported executable controls are disclosed in paper_baseline_parameter_sources.csv.\n');
    fprintf(fid,'No analytical or empirical reference LIM is used for tuning or scoring.\n');
    fprintf(fid,'Parameter rules use the target Jacobian and a Lyapunov contraction ellipsoid.\n');
    fprintf(fid,'Target-cell width has an algorithmic floor of 3.\n');
    fprintf(fid,'The final horizon is frozen after two stable T-versus-2T pilot rounds.\n');
end
