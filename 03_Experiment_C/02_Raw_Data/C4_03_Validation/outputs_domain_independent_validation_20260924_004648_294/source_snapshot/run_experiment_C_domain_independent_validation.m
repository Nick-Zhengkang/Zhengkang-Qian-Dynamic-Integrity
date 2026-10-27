function outDir=run_experiment_C_domain_independent_validation( ...
    domainDiagnosticDir,alphaValues,resumeDir)
% Validate a frozen domain rule on new points that did not build the rule.
if nargin<2, alphaValues=[0.2 0.7 1.0]; end
if nargin<3, resumeDir=''; end
validateattributes(alphaValues,{'numeric'},{'vector','positive','finite','nonempty'});
alphaValues=reshape(alphaValues,1,[]);
assert(numel(unique(alphaValues))==numel(alphaValues));

here=fileparts(mfilename('fullpath'));
funcDir=fullfile(fileparts(here),'work','DynIn','DynIn_v1.1.0','functions');
modelDir=fullfile(here,'transfer_2d_model');
oldPath=path; guard=onCleanup(@()path(oldPath)); %#ok<NASGU>
restoredefaultpath; addpath(here,funcDir,modelDir,'-begin');
assert(strcmpi(which('simulation_DI'),fullfile(funcDir,'simulation_DI.m')));
assert(strcmpi(which('sistema'),fullfile(modelDir,'sistema.m')));
assert(isfile(fullfile(domainDiagnosticDir,'domain_protocol.mat')), ...
    'The supplied folder is not a completed domain-diagnostic output.');

design=struct('version','domain_independent_validation_v1', ...
    'sourceDomainDiagnosticDir',char(domainDiagnosticDir), ...
    'alphaValues',alphaValues,'angleCount',18, ...
    'angleOffset',0.381,'radialFactors',[0.12 0.32 0.52 0.72 0.92 1.12 1.32], ...
    'edgeSamplesPerSide',9,'edgeInsetFraction',0.025, ...
    'frozenCandidateProfile','energy_envelope', ...
    'comparisonProfile','original_domain', ...
    'usesAnalyticLIM',false,'freshCoordinates',true, ...
    'candidateRebuiltFromFreshPoints',false);

if isempty(resumeDir)
    outDir=fullfile(here,['outputs_domain_independent_validation_' ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
else
    outDir=char(resumeDir);
    assert(isfile(fullfile(outDir,'independent_validation_protocol.mat')), ...
        'Resume folder is not an independent domain-validation output.');
end

snapshot=fullfile(outDir,'source_snapshot');
sourceFiles={fullfile(here,'run_experiment_C_domain_independent_validation.m'), ...
    fullfile(here,'test_experiment_C_domain_independent_validation.m'), ...
    fullfile(here,'experiment_C_rule_diagnostics.m'), ...
    fullfile(here,'experiment_C_domain_read_table.m'), ...
    fullfile(here,'experiment_C_rule_physics.m'), ...
    fullfile(modelDir,'sistema.m')};
originalFiles=dir(fullfile(funcDir,'*.m'));
sourceFiles=[sourceFiles,arrayfun(@(d)fullfile(d.folder,d.name), ...
    originalFiles,'UniformOutput',false)'];
if isfile(fullfile(outDir,'independent_validation_protocol.mat'))
    old=load(fullfile(outDir,'independent_validation_protocol.mat'),'design');
    assert(isequaln(old.design,design),'Resume settings changed.');
    verify_files(sourceFiles,snapshot);
else
    mkdir(snapshot);
    for j=1:numel(sourceFiles), copyfile(sourceFiles{j},snapshot); end
    save(fullfile(outDir,'independent_validation_protocol.mat'),'design');
end

caseMap=locate_cases(domainDiagnosticDir);
fprintf('\nIndependent domain validation: %d damping cases. No GA and no LIM reference.\n', ...
    numel(alphaValues));
fprintf('Frozen candidate: energy_envelope from %s\nOutput: %s\n', ...
    domainDiagnosticDir,outDir);

allTruth=table(); allPoints=table(); allSummary=table(); allDecisions=table();
for c=1:numel(alphaValues)
    alpha=alphaValues(c);
    ix=find(abs(caseMap.alpha-alpha)<1e-12);
    assert(isscalar(ix),'Frozen diagnostic does not uniquely identify alpha=%g.',alpha);
    srcCase=char(caseMap.case_directory(ix));
    caseDir=fullfile(outDir,sprintf('case_%02d',c));
    if ~isfolder(caseDir), mkdir(caseDir); end

    frozenEnergy=load(fullfile(srcCase,'energy_envelope','domain_settings.mat'), ...
        'g','p','geo','status');
    frozenOriginal=load(fullfile(srcCase,'original_domain','domain_settings.mat'), ...
        'g','p','geo','status');
    assert(string(frozenEnergy.status)=="evaluated" && ...
        string(frozenOriginal.status)=="evaluated",'Frozen profile was not evaluated.');
    assert(abs(frozenEnergy.geo.alpha-alpha)<1e-12 && ...
        abs(frozenOriginal.geo.alpha-alpha)<1e-12);
    f=frozenOriginal.g;
    pOriginal=frozenOriginal.p;
    gEnergy=frozenEnergy.g;
    pEnergy=frozenEnergy.p;
    assert(f.model=="bistable_duffing" && isequal(f.target,[-1 0]));

    inputDir=fullfile(srcCase,'input_snapshot');
    saved=load(fullfile(inputDir,'run_configuration.mat'),'cfg'); cfg=saved.cfg;
    required=["point_id","x0","v0"];
    numeric=required;
    oldCal=experiment_C_domain_read_table( ...
        fullfile(inputDir,'calibration_truth.csv'),required,numeric);
    oldHold=experiment_C_domain_read_table( ...
        fullfile(inputDir,'holdout_truth.csv'),required,numeric);
    oldZ=[oldCal.x0 oldCal.v0;oldHold.x0 oldHold.v0];

    fprintf('\n[case %d/%d] alpha=%g, generating fresh points\n', ...
        c,numel(alphaValues),alpha);
    truthFile=fullfile(caseDir,'fresh_validation_truth.csv');
    D=fresh_dataset(f,oldZ,cfg,design,truthFile);
    assert(all(logical(D.inside_domain)),'Fresh initial points must lie in the original domain.');
    assert(all(D.minimum_normalized_distance_to_old>1e-8), ...
        'Fresh validation accidentally reused an old diagnostic coordinate.');
    D.alpha=repmat(alpha,height(D),1);

    profiles=["original_domain","energy_envelope"];
    settings={f,pOriginal;gEnergy,pEnergy};
    profileQueries=struct(); summaries=cell(0,1); points=cell(0,1);
    for j=1:numel(profiles)
        id=profiles(j); g=settings{j,1}; p=settings{j,2};
        profileDir=fullfile(caseDir,char(id));
        if ~isfolder(profileDir), mkdir(profileDir); end
        [S,Q,~]=experiment_C_rule_diagnostics( ...
            'classify',D,'fresh_independent',p,g,cfg,profileDir);
        Q.alpha=repmat(alpha,height(Q),1);
        Q.profile=repmat(id,height(Q),1);
        Q.frozen_energy_ceiling=repmat(frozenEnergy.geo.energy_ceiling_calibration,height(Q),1);
        Q.above_frozen_energy_ceiling=Q.initial_energy> ...
            frozenEnergy.geo.energy_ceiling_calibration+1e-10;
        profileQueries.(char(id))=Q;
        points{end+1,1}=Q; %#ok<AGROW>

        known=ismember(Q.truth_label,[1 2]);
        high=known & Q.above_frozen_energy_ceiling;
        highTarget=high & Q.truth_label==1;
        coveragePass=S.n_true_target>=cfg.minClassCount && ...
            S.n_true_non_target>=cfg.minClassCount;
        ratePass=S.n_exceptions==0 && ...
            S.false_safe_rate<=cfg.maxFalseSafe && ...
            S.false_unsafe_rate<=cfg.maxFalseUnsafe && ...
            S.unresolved_rate<=cfg.maxUnresolved && ...
            S.truth_unresolved_rate<=cfg.maxTruthUnresolved;
        independentPass=coveragePass && ratePass && ...
            S.n_domain_exit_false_unsafe==0;
        summaries{end+1,1}=struct('alpha',alpha,'profile',id, ...
            'n_points',height(Q),'n_true_target',S.n_true_target, ...
            'n_true_non_target',S.n_true_non_target, ...
            'n_false_safe',S.n_false_safe,'n_false_unsafe',S.n_false_unsafe, ...
            'n_unresolved',S.n_unresolved, ...
            'false_safe_rate',S.false_safe_rate, ...
            'false_unsafe_rate',S.false_unsafe_rate, ...
            'unresolved_rate',S.unresolved_rate, ...
            'domain_exit_false_unsafe',S.n_domain_exit_false_unsafe, ...
            'n_above_frozen_energy_ceiling',nnz(high), ...
            'n_target_above_frozen_energy_ceiling',nnz(highTarget), ...
            'n_high_energy_false_unsafe',nnz(highTarget & Q.predicted_label==2), ...
            'n_high_energy_unresolved',nnz(highTarget & Q.predicted_label==0), ...
            'classifier_wall_s',S.classifier_wall_s, ...
            'independent_validation_pass',independentPass); %#ok<AGROW>
        fprintf('[fresh %d/2] %s: target=%d, non-target=%d, FSR=%.3g, FUR=%.3g, exits=%d\n', ...
            j,id,S.n_true_target,S.n_true_non_target,S.false_safe_rate, ...
            S.false_unsafe_rate,S.n_domain_exit_false_unsafe);
    end

    Q0=profileQueries.original_domain;
    QE=profileQueries.energy_envelope;
    assert(isequal(Q0.point_id,QE.point_id) && max(abs(Q0.x0-QE.x0))<1e-12 && ...
        max(abs(Q0.v0-QE.v0))<1e-12,'Profiles did not classify identical points.');
    target=Q0.truth_label==1;
    oldExit=target & Q0.raw_tipo==3;
    corrected=nnz(oldExit & QE.predicted_label==1);
    remaining=nnz(oldExit & QE.predicted_label==2);
    newlyWrong=nnz(target & Q0.predicted_label==1 & QE.predicted_label~=1);
    energySummary=summaries{2};
    decision=struct('alpha',alpha,'fresh_coordinate_set',true, ...
        'frozen_without_fresh_labels',true, ...
        'n_original_domain_exit_false_unsafe',nnz(oldExit), ...
        'n_original_exit_errors_corrected',corrected, ...
        'n_original_exit_errors_remaining',remaining, ...
        'n_new_target_errors_after_expansion',newlyWrong, ...
        'independent_energy_domain_pass',energySummary.independent_validation_pass, ...
        'ready_for_controlled_GA_test',energySummary.independent_validation_pass);

    caseTruth=D;
    casePoints=vertcat(points{:});
    caseSummary=struct2table(vertcat(summaries{:}));
    caseDecision=struct2table(decision);
    atomic_csv(caseTruth,fullfile(caseDir,'fresh_validation_truth.csv'));
    atomic_csv(casePoints,fullfile(caseDir,'fresh_pointwise_comparison.csv'));
    atomic_csv(caseSummary,fullfile(caseDir,'summary_independent_domain_validation.csv'));
    atomic_csv(caseDecision,fullfile(caseDir,'independent_domain_decision.csv'));

    allTruth=append_table(allTruth,caseTruth);
    allPoints=append_table(allPoints,casePoints);
    allSummary=append_table(allSummary,caseSummary);
    allDecisions=append_table(allDecisions,caseDecision);
    atomic_csv(allTruth,fullfile(outDir,'fresh_validation_truth.csv'));
    atomic_csv(allPoints,fullfile(outDir,'fresh_pointwise_comparison.csv'));
    atomic_csv(allSummary,fullfile(outDir,'summary_independent_domain_validation.csv'));
    atomic_csv(allDecisions,fullfile(outDir,'independent_domain_decisions.csv'));
end

fprintf('\nIndependent domain validation finished.\nSummary: %s\nPoints: %s\n', ...
    fullfile(outDir,'summary_independent_domain_validation.csv'), ...
    fullfile(outDir,'fresh_pointwise_comparison.csv'));
end

function map=locate_cases(root)
folders=dir(fullfile(root,'case_*'));
rows=cell(0,1);
for i=1:numel(folders)
    file=fullfile(folders(i).folder,folders(i).name, ...
        'energy_envelope','domain_settings.mat');
    if ~isfile(file), continue; end
    x=load(file,'geo');
    rows{end+1,1}=struct('alpha',x.geo.alpha, ...
        'case_directory',string(fullfile(folders(i).folder,folders(i).name))); %#ok<AGROW>
end
assert(~isempty(rows),'No frozen energy-envelope cases were found.');
map=struct2table(vertcat(rows{:}));
end

function D=fresh_dataset(f,oldZ,cfg,design,file)
rows=cell(0,1);
if isfile(file)
    old=readtable(file,'TextType','string','VariableNamingRule','preserve');
    rows=num2cell(table2struct(old));
end

candidateRows=cell(0,1);
angles=((0:design.angleCount-1)+design.angleOffset)*2*pi/design.angleCount;
for theta=angles
    for radius=design.radialFactors
        z=f.target+radius*[f.Lx*cos(theta),f.Lv*sin(theta)];
        candidateRows{end+1,1}=candidate(z,"fresh_radial",radius,theta); %#ok<AGROW>
    end
end

d=f.domain; span=d(3:4)-d(1:2); inset=design.edgeInsetFraction*span;
fractions=(1:design.edgeSamplesPerSide)/(design.edgeSamplesPerSide+1);
for q=fractions
    candidateRows{end+1,1}=candidate( ...
        [d(1)+inset(1),d(2)+q*span(2)],"fresh_edge",NaN,NaN); %#ok<AGROW>
    candidateRows{end+1,1}=candidate( ...
        [d(3)-inset(1),d(2)+q*span(2)],"fresh_edge",NaN,NaN); %#ok<AGROW>
    candidateRows{end+1,1}=candidate( ...
        [d(1)+q*span(1),d(2)+inset(2)],"fresh_edge",NaN,NaN); %#ok<AGROW>
    candidateRows{end+1,1}=candidate( ...
        [d(1)+q*span(1),d(4)-inset(2)],"fresh_edge",NaN,NaN); %#ok<AGROW>
end

Z=zeros(0,2); candidates=cell(0,1);
scale=max(span,eps);
for i=1:numel(candidateRows)
    r=candidateRows{i}; z=[r.x0 r.v0];
    if ~all(z>d(1:2)+1e-12 & z<d(3:4)-1e-12), continue; end
    if ~isempty(Z) && min(sqrt(sum(((Z-z)./scale).^2,2)))<1e-10, continue; end
    oldDistance=min(sqrt(sum(((oldZ-z)./scale).^2,2)));
    if oldDistance<=1e-8, continue; end
    r.minimum_normalized_distance_to_old=oldDistance;
    candidates{end+1,1}=r; %#ok<AGROW>
    Z(end+1,:)=z; %#ok<AGROW>
end

assert(numel(candidates)>=100,'Too few fresh points survived domain and overlap checks.');
for n=numel(rows)+1:numel(candidates)
    r=candidates{n}; z=[r.x0 r.v0];
    timer=tic;
    [label,reason,simTime,errorText]=experiment_C_rule_diagnostics('oracle',z,f,cfg);
    r.point_id=n;
    r.inside_domain=true;
    r.truth_label=label;
    r.truth_reason=reason;
    r.truth_sim_time=simTime;
    r.truth_wall_s=toc(timer);
    r.truth_error=errorText;
    r.initial_energy=0.5*z(2)^2+ ...
        experiment_C_rule_physics('potential',f.model,z(1));
    rows{n,1}=r;
    atomic_csv(struct2table(vertcat(rows{:})),file);
    fprintf('[fresh oracle %d/%d] label=%d, %s, E0=%.4g, %.2fs\n', ...
        n,numel(candidates),label,char(reason),r.initial_energy,r.truth_wall_s);
end
assert(numel(rows)==numel(candidates),'Fresh truth checkpoint has extra points.');
D=struct2table(vertcat(rows{:}));
expected=vertcat(candidates{:});
assert(max(abs(D.x0-[expected.x0]'))<1e-12 && ...
    max(abs(D.v0-[expected.v0]'))<1e-12, ...
    'Fresh truth checkpoint coordinates differ from the fixed design.');
end

function r=candidate(z,kind,radius,theta)
r=struct('point_id',NaN,'kind',kind,'radius_factor',radius, ...
    'angle_rad',theta,'x0',z(1),'v0',z(2), ...
    'minimum_normalized_distance_to_old',NaN,'inside_domain',true, ...
    'truth_label',NaN,'truth_reason',"",'truth_sim_time',NaN, ...
    'truth_wall_s',NaN,'truth_error',"",'initial_energy',NaN);
end

function T=append_table(T,U)
if isempty(T), T=U; else, T=[T;U]; end
end

function verify_files(paths,snapshot)
for j=1:numel(paths)
    [~,stem,ext]=fileparts(paths{j}); other=fullfile(snapshot,[stem ext]);
    assert(isfile(other) && strcmp(fileread(paths{j}),fileread(other)), ...
        'Source differs from resume snapshot: %s',paths{j});
end
end

function atomic_csv(T,file)
[folder,name,ext]=fileparts(file);
tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end

