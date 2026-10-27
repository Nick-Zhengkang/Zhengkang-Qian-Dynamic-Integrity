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
function outDir=run_experiment_C_controlled_GA(domainDiagnosticDir, ...
    independentValidationDir,mode,alphaValues,numberOfSteps,resumeDir)
% Paired full DynIn-GA test: original domain vs frozen energy envelope.
% The original compute_LIM_FP implementation is called without modification.
if nargin<3 || isempty(mode), mode='confirm'; end
if nargin<4 || isempty(alphaValues), alphaValues=[0.2 0.7 1.0]; end
if nargin<5 || isempty(numberOfSteps), numberOfSteps=100; end
if nargin<6, resumeDir=''; end
mode=validatestring(char(mode),{'smoke','develop','confirm'});
validateattributes(alphaValues,{'numeric'},{'vector','positive','finite','nonempty'});
validateattributes(numberOfSteps,{'numeric'},{'scalar','integer','positive','finite'});
alphaValues=reshape(alphaValues,1,[]);
assert(numel(unique(alphaValues))==numel(alphaValues),'Duplicate alpha values.');

here=fileparts(mfilename('fullpath'));
funcDir=fullfile(fileparts(here),'work','DynIn','DynIn_v1.1.0','functions');
modelDir=fullfile(here,'transfer_2d_model');
assert(isfile(fullfile(funcDir,'compute_LIM_FP.m')),'Original DynIn functions not found.');
assert(isfile(fullfile(modelDir,'sistema.m')),'Bistable Duffing model file not found.');
assert(isfile(fullfile(domainDiagnosticDir,'domain_protocol.mat')), ...
    'domainDiagnosticDir is not a domain-diagnostic output.');
assert(isfile(fullfile(independentValidationDir,'independent_domain_decisions.csv')), ...
    'independentValidationDir is not a completed independent validation.');

seeds=select_seeds(mode);
ga=struct('type_x0',1,'divR',40,'num_gen',5,'num_crossover',9, ...
    'selected_opt',3,'newcomers',8,'num_almost_clones',2, ...
    'bis_iter_max',5,'automatic',1,'number_of_steps',numberOfSteps);
thresholds=[0.01 0.02 0.05];
protocol=struct('version','controlled_GA_domain_v1', ...
    'model','bistable_duffing','mode',mode,'alphaValues',alphaValues, ...
    'seeds',seeds,'ga',ga,'thresholds',thresholds, ...
    'domainDiagnosticDir',char(domainDiagnosticDir), ...
    'independentValidationDir',char(independentValidationDir), ...
    'profiles',{{'original_domain','energy_envelope'}}, ...
    'pairedRandomSeeds',true,'randomizedExecutionOrder',true, ...
    'searchRadiusCoupledToDomainByOriginalCode',true, ...
    'analyticReferenceUsedOnlyForFinalScoring',true);

caseMap=locate_frozen_cases(domainDiagnosticDir,alphaValues);
validate_independent_decisions(independentValidationDir,alphaValues);
if isempty(resumeDir)
    outDir=fullfile(here,['outputs_controlled_GA_domain_' ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
else
    outDir=char(resumeDir);
    assert(isfile(fullfile(outDir,'controlled_GA_protocol.mat')), ...
        'resumeDir is not a controlled-GA output root.');
end

oldPath=path; oldRng=rng;
pathGuard=onCleanup(@()path(oldPath)); %#ok<NASGU>
rngGuard=onCleanup(@()rng(oldRng)); %#ok<NASGU>
restoredefaultpath; addpath(here,funcDir,modelDir,'-begin');
assert(strcmpi(which('compute_LIM_FP'),fullfile(funcDir,'compute_LIM_FP.m')));
assert(strcmpi(which('sistema'),fullfile(modelDir,'sistema.m')));

snapshotDir=fullfile(outDir,'source_snapshot');
inputDir=fullfile(outDir,'frozen_input_snapshot');
sourceFiles=source_files(here,funcDir,modelDir);
protocolFile=fullfile(outDir,'controlled_GA_protocol.mat');
if isfile(protocolFile)
    old=load(protocolFile,'protocol');
    assert(isequaln(old.protocol,protocol), ...
        'Resume settings changed. Restore the original settings or start a new output.');
    verify_source_snapshot(sourceFiles,snapshotDir);
    assert(isfolder(inputDir),'Frozen input snapshot is missing.');
else
    save(protocolFile,'protocol');
    snapshot_sources(sourceFiles,snapshotDir);
    snapshot_inputs(caseMap,independentValidationDir,inputDir);
end

schedule=build_schedule(alphaValues,seeds,ga.number_of_steps);
atomic_csv(schedule,fullfile(outDir,'randomized_schedule.csv'));
settings=load_frozen_settings(inputDir,alphaValues);
write_setting_audit(settings,ga,outDir);

fprintf('\nControlled DynIn GA domain test\n');
fprintf('Model: bistable Duffing; type_x0=1; original DynIn unchanged.\n');
fprintf('%d alpha x 2 domains x %d paired seeds = %d full GA runs.\n', ...
    numel(alphaValues),numel(seeds),height(schedule));
fprintf('Trajectory budget: %d per run. Primary threshold: 2%%; report 1%% and 5%%.\n', ...
    ga.number_of_steps);
fprintf(['Important: in original DynIn, the initial search radius equals the distance ' ...
    'to the nearest domain face. This coupled quantity is recorded, not overridden.\n']);
fprintf('Output directory:\n%s\n',outDir);

reference=make_reference_table(alphaValues);
atomic_csv(reference,fullfile(outDir,'reference_audit.csv'));
checkpointDir=fullfile(outDir,'run_checkpoints');
if ~isfolder(checkpointDir), mkdir(checkpointDir); end
raw=table();
for i=1:height(schedule)
    s=table2struct(schedule(i,:));
    setting=select_setting(settings,s.alpha,s.profile);
    checkpoint=fullfile(checkpointDir,char(s.run_key+'.mat'));
    if isfile(checkpoint)
        saved=load(checkpoint,'result'); result=saved.result;
        row=result.row;
        fprintf('[run %d/%d] RESUME %s\n',i,height(schedule),s.run_key);
    else
        fprintf('[run %d/%d] START alpha=%.3g, domain=%s, seed=%d, N=%d\n', ...
            i,height(schedule),s.alpha,s.profile,s.seed,s.number_of_steps);
        rng(s.algorithm_seed,'twister');
        ref=reference.reference_LIM(abs(reference.alpha-s.alpha)<1e-12);
        [row,history]=execute_run(s,setting,ga,ref);
        result=struct('row',row,'history',history);
        atomic_mat(checkpoint,'result',result);
        if ~isempty(history)
            atomic_csv(history,fullfile(checkpointDir,char(s.run_key+'_history.csv')));
        end
        fprintf('[run %d/%d] DONE R=%.7g, rel.err=%.3g%%, wall=%.2fs, exits=%g, %s\n', ...
            i,height(schedule),row.R_hat,100*row.relative_error,row.wall_s, ...
            row.n_domain_exit_iterations,row.status);
    end
    if isempty(raw), raw=struct2table(row); else, raw=[raw;struct2table(row)]; end %#ok<AGROW>
    atomic_csv(raw,fullfile(outDir,'raw_data_all_runs.csv'));
end

summary=summarize_profiles(raw,thresholds);
overall=summarize_overall(raw,thresholds);
paired=build_paired_contrasts(raw);
pairedSummary=summarize_paired(paired);
atomic_csv(summary,fullfile(outDir,'summary_by_alpha_and_domain.csv'));
atomic_csv(overall,fullfile(outDir,'summary_overall_by_domain.csv'));
atomic_csv(paired,fullfile(outDir,'paired_contrasts_by_seed.csv'));
atomic_csv(pairedSummary,fullfile(outDir,'paired_contrast_summary.csv'));

fprintf('\nControlled GA test finished.\n');
fprintf('Raw: %s\n',fullfile(outDir,'raw_data_all_runs.csv'));
fprintf('Summary: %s\n',fullfile(outDir,'summary_by_alpha_and_domain.csv'));
fprintf('Paired contrasts: %s\n',fullfile(outDir,'paired_contrasts_by_seed.csv'));
end

function seeds=select_seeds(mode)
switch mode
    case 'smoke', seeds=1;
    case 'develop', seeds=1:10;
    case 'confirm', seeds=61:90;
end
end

function caseMap=locate_frozen_cases(root,alphaValues)
folders=dir(fullfile(root,'case_*'));
rows=cell(0,1);
for i=1:numel(folders)
    if ~folders(i).isdir, continue; end
    folder=fullfile(folders(i).folder,folders(i).name);
    file=fullfile(folder,'energy_envelope','domain_settings.mat');
    original=fullfile(folder,'original_domain','domain_settings.mat');
    if ~(isfile(file) && isfile(original)), continue; end
    E=load(file,'geo','status'); O=load(original,'geo','status');
    assert(string(E.status)=="evaluated" && string(O.status)=="evaluated");
    assert(abs(E.geo.alpha-O.geo.alpha)<1e-12);
    rows{end+1,1}=struct('alpha',E.geo.alpha,'case_directory',string(folder)); %#ok<AGROW>
end
assert(~isempty(rows),'No frozen domain cases found.');
caseMap=struct2table(vertcat(rows{:}));
for a=alphaValues
    assert(nnz(abs(caseMap.alpha-a)<1e-12)==1, ...
        'Frozen domain source does not uniquely contain alpha=%g.',a);
end
end

function validate_independent_decisions(root,alphaValues)
T=readtable(fullfile(root,'independent_domain_decisions.csv'),'TextType','string');
required={'alpha','ready_for_controlled_GA_test','fresh_coordinate_set', ...
    'frozen_without_fresh_labels'};
assert(all(ismember(required,T.Properties.VariableNames)), ...
    'Independent decision table has an unexpected schema.');
for a=alphaValues
    q=T(abs(T.alpha-a)<1e-12,:);
    assert(height(q)==1 && logical(q.ready_for_controlled_GA_test) && ...
        logical(q.fresh_coordinate_set) && logical(q.frozen_without_fresh_labels), ...
        'alpha=%g did not pass the independent prerequisite.',a);
end
end

function snapshot_inputs(caseMap,validationDir,destination)
mkdir(destination);
copyfile(fullfile(validationDir,'independent_domain_decisions.csv'), ...
    fullfile(destination,'independent_domain_decisions.csv'));
copyfile(fullfile(validationDir,'independent_validation_protocol.mat'), ...
    fullfile(destination,'independent_validation_protocol.mat'));
for i=1:height(caseMap)
    tag=alpha_tag(caseMap.alpha(i));
    folder=fullfile(destination,char(tag)); mkdir(folder);
    src=char(caseMap.case_directory(i));
    copyfile(fullfile(src,'original_domain','domain_settings.mat'), ...
        fullfile(folder,'original_domain_settings.mat'));
    copyfile(fullfile(src,'energy_envelope','domain_settings.mat'), ...
        fullfile(folder,'energy_envelope_settings.mat'));
    copyfile(fullfile(src,'input_snapshot','run_configuration.mat'), ...
        fullfile(folder,'run_configuration.mat'));
end
end

function settings=load_frozen_settings(inputDir,alphaValues)
rows=cell(0,1);
for a=alphaValues
    folder=fullfile(inputDir,char(alpha_tag(a)));
    C=load(fullfile(folder,'run_configuration.mat'),'cfg'); cfg=C.cfg;
    for profile=["original_domain","energy_envelope"]
        S=load(fullfile(folder,char(profile+'_settings.mat')),'g','p','geo','status');
        assert(string(S.status)=="evaluated" && abs(S.geo.alpha-a)<1e-12);
        assert(S.g.model=="bistable_duffing" && isequal(S.g.target,[-1 0]));
        row=struct('alpha',a,'profile',profile,'g',S.g,'p',S.p,'geo',S.geo,'cfg',cfg);
        rows{end+1,1}=row; %#ok<AGROW>
    end
end
settings=vertcat(rows{:});
end

function s=select_setting(settings,alpha,profile)
ix=arrayfun(@(q)abs(q.alpha-alpha)<1e-12 && q.profile==profile,settings);
assert(nnz(ix)==1,'Frozen setting not uniquely identified.'); s=settings(ix);
end

function write_setting_audit(settings,ga,outDir)
rows=cell(numel(settings),1);
for i=1:numel(settings)
    s=settings(i); g=s.g; p=s.p;
    r0=initial_radius(g.target,g.domain,g.weight);
    h=(g.domain(3:4)-g.domain(1:2))/p.discr;
    rows{i}=struct('alpha',s.alpha,'profile',s.profile, ...
        'xmin',g.domain(1),'vmin',g.domain(2),'xmax',g.domain(3),'vmax',g.domain(4), ...
        'discr',p.discr,'hx',h(1),'hv',h(2),'target_cells',p.k, ...
        'tfinal',p.tfinal,'Ts',p.Ts,'rep_periodic',p.rep_periodic, ...
        'initial_search_radius',r0,'number_of_steps',ga.number_of_steps, ...
        'type_x0',ga.type_x0,'divR',ga.divR,'num_gen',ga.num_gen, ...
        'num_crossover',ga.num_crossover,'selected_opt',ga.selected_opt, ...
        'newcomers',ga.newcomers,'num_almost_clones',ga.num_almost_clones); %#ok<AGROW>
end
T=struct2table(vertcat(rows{:}));
atomic_csv(T,fullfile(outDir,'frozen_settings_audit.csv'));
end

function schedule=build_schedule(alphaValues,seeds,numberOfSteps)
rows=cell(0,1);
for a=alphaValues
    for seed=seeds
        algorithmSeed=24680+round(a*1000)*100000+seed;
        for profile=["original_domain","energy_envelope"]
            key=alpha_tag(a)+'_'+profile+sprintf('_seed%03d',seed);
            rows{end+1,1}=struct('alpha',a,'profile',profile,'seed',seed, ...
                'algorithm_seed',algorithmSeed,'number_of_steps',numberOfSteps, ...
                'pair_key',alpha_tag(a)+sprintf('_seed%03d',seed),'run_key',key); %#ok<AGROW>
        end
    end
end
schedule=struct2table(vertcat(rows{:}));
state=rng; guard=onCleanup(@()rng(state)); %#ok<NASGU>
rng(9242026,'twister'); schedule=schedule(randperm(height(schedule)),:);
schedule.execution_order=(1:height(schedule))';
end

function reference=make_reference_table(alphaValues)
rows=cell(numel(alphaValues),1);
for i=1:numel(alphaValues)
    timer=tic;
    [R,residual]=experiment_C_2d_reference('bistable_duffing',alphaValues(i));
    rows{i}=struct('alpha',alphaValues(i),'reference_LIM',R, ...
        'reference_residual',residual,'reference_wall_s',toc(timer));
end
reference=struct2table(vertcat(rows{:}));
end

function [row,history]=execute_run(s,setting,ga,Rref)
g=setting.g; p=setting.p; cfg=setting.cfg;
row=s;
row.discr=p.discr; row.target_cells=p.k; row.tfinal=p.tfinal; row.Ts=p.Ts;
row.rep_periodic=p.rep_periodic; row.xmin=g.domain(1); row.vmin=g.domain(2);
row.xmax=g.domain(3); row.vmax=g.domain(4);
step=(g.domain(3:4)-g.domain(1:2))/p.discr;
row.hx=step(1); row.hv=step(2);
row.initial_search_radius=initial_radius(g.target,g.domain,g.weight);
row.search_radius_is_domain_derived=true;
row.reference_LIM=Rref; row.R_hat=NaN; row.relative_error=NaN; row.signed_error=NaN;
row.within_1pct=false; row.within_2pct=false; row.within_5pct=false;
row.wall_s=NaN; row.cpu_s=NaN; row.trajectory_evaluations=NaN;
row.n_target_iterations=NaN; row.n_other_known_iterations=NaN;
row.n_domain_exit_iterations=NaN; row.n_new_attractor_iterations=NaN;
row.n_unresolved_iterations=NaN; row.n_stored_domain_exit_points=NaN;
row.horizon_exhausted_proxy=NaN; row.tail_relative_change=NaN;
row.first_x0_x=NaN; row.first_x0_v=NaN; row.first_x0_radius=NaN;
row.first_x0_energy=NaN; row.max_initial_condition_energy=NaN;
row.timing_review_flag=false; row.status="failed"; row.error_message="";
row.started_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
row.finished_at=""; history=table();
row.estimated_allocation_GB=96*round(p.tfinal/p.Ts*s.number_of_steps/4)/1e9;
maxGB=cfg.maximumEstimatedAllocationGB;
if row.estimated_allocation_GB>maxGB
    row.status="allocation_limit";
    row.error_message="Estimated original DynIn allocation exceeds the frozen limit.";
    row.finished_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
    return
end
values={p.tfinal,p.Ts,g.weight,ga.type_x0,cfg.relTol,cfg.absTol, ...
    s.number_of_steps,p.k,1001,0,0,g.domain,p.discr,ga.automatic, ...
    1,2,cfg.repFixPoint,p.rep_periodic,0.005,0,0,10000,ga.divR,ga.num_gen, ...
    ga.num_crossover,ga.selected_opt,ga.newcomers,ga.num_almost_clones,ga.bis_iter_max};
assert(numel(values)==29);
timer=tic; cpu0=cputime;
try
    [R,out,outH]=compute_LIM_FP(g.target,struct('model',g.model,'alpha',g.alpha),values{:});
    row.wall_s=toc(timer); row.cpu_s=cputime-cpu0; row.R_hat=R;
    row.relative_error=abs(R-Rref)/Rref; row.signed_error=(R-Rref)/Rref;
    row.within_1pct=isfinite(R) && row.relative_error<=0.01;
    row.within_2pct=isfinite(R) && row.relative_error<=0.02;
    row.within_5pct=isfinite(R) && row.relative_error<=0.05;
    row.trajectory_evaluations=nnz(out.time_steps_sim>0);
    row.n_target_iterations=nnz(out.tipo==1);
    row.n_other_known_iterations=nnz(out.tipo==2);
    row.n_domain_exit_iterations=nnz(out.tipo==3);
    row.n_new_attractor_iterations=nnz(out.tipo==4);
    row.n_unresolved_iterations=nnz(out.tipo==0);
    row.n_stored_domain_exit_points=nnz(any(outH.vdout~=0,2));
    row.horizon_exhausted_proxy=nnz(out.time_steps_sim>=floor(p.tfinal/p.Ts));
    start=max(1,floor(0.8*s.number_of_steps)+1);
    row.tail_relative_change=abs(out.R(start)-R)/max(abs(R),eps);
    row.first_x0_x=out.x0(1,1); row.first_x0_v=out.x0(1,2);
    row.first_x0_radius=weighted_radius(out.x0(1,:),g.target,g.weight);
    energies=0.5*out.x0(:,2).^2-0.5*out.x0(:,1).^2+0.25*out.x0(:,1).^4;
    row.first_x0_energy=energies(1); row.max_initial_condition_energy=max(energies,[],'omitnan');
    if isfinite(R), row.status="ok"; else, row.status="nonfinite"; end
    n=numel(out.time_steps_sim);
    history=table((1:n)',out.R(2:n+1),out.tipo(:),out.time_steps_sim(:), ...
        out.time_sim(:),out.time_x0(:),out.x0(:,1),out.x0(:,2), ...
        'VariableNames',{'iteration','R_hat','tipo','output_samples', ...
        'integration_wall_s','GA_selection_wall_s','x0','v0'});
catch ME
    row.wall_s=toc(timer); row.cpu_s=cputime-cpu0;
    row.error_message=string(getReport(ME,'basic','hyperlinks','off'));
end
row.finished_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
row.timing_review_flag=row.wall_s>30 && row.wall_s>5*max(row.cpu_s,1);
end

function r=initial_radius(target,domain,weight)
d=[abs(target-domain(1:2)),abs(domain(3:4)-target)];
w=[sqrt(weight),sqrt(weight)]; r=min(w.*d);
end

function r=weighted_radius(z,target,weight)
r=sqrt(sum((z-target).^2.*weight));
end

function S=summarize_profiles(raw,thresholds)
alphas=unique(raw.alpha,'stable'); rows=cell(0,1);
for a=reshape(alphas,1,[])
    for profile=["original_domain","energy_envelope"]
        g=raw(abs(raw.alpha-a)<1e-12 & raw.profile==profile,:);
        rows{end+1,1}=summary_row(g,a,profile,thresholds); %#ok<AGROW>
    end
end
S=struct2table(vertcat(rows{:}));
end

function S=summarize_overall(raw,thresholds)
rows=cell(2,1); profiles=["original_domain","energy_envelope"];
for i=1:2
    g=raw(raw.profile==profiles(i),:);
    rows{i}=summary_row(g,NaN,profiles(i),thresholds);
end
S=struct2table(vertcat(rows{:}));
end

function r=summary_row(g,alpha,profile,thresholds)
ok=g.status=="ok" & isfinite(g.relative_error);
e=g.relative_error(ok); wall=g.wall_s(ok); cpu=g.cpu_s(ok);
r=struct('alpha',alpha,'profile',profile,'n_runs',height(g),'n_completed',nnz(ok), ...
    'median_relative_error',median(e,'omitnan'), ...
    'p95_relative_error',empirical_percentile(e,0.95), ...
    'median_signed_error',median(g.signed_error(ok),'omitnan'), ...
    'positive_signed_error_rate',mean(g.signed_error(ok)>0), ...
    'unsafe_overestimate_gt2pct_rate',mean(g.signed_error(ok)>0.02), ...
    'within_1pct_rate',mean(ok & g.relative_error<=thresholds(1)), ...
    'within_2pct_rate',mean(ok & g.relative_error<=thresholds(2)), ...
    'within_5pct_rate',mean(ok & g.relative_error<=thresholds(3)), ...
    'median_wall_s',median(wall,'omitnan'),'median_cpu_s',median(cpu,'omitnan'), ...
    'median_trajectory_evaluations',median(g.trajectory_evaluations(ok),'omitnan'), ...
    'median_domain_exit_iterations',median(g.n_domain_exit_iterations(ok),'omitnan'), ...
    'runs_with_any_domain_exit',nnz(ok & g.n_domain_exit_iterations>0), ...
    'median_tail_relative_change',median(g.tail_relative_change(ok),'omitnan'), ...
    'initial_search_radius',median(g.initial_search_radius,'omitnan'), ...
    'n_timing_review_flags',nnz(g.timing_review_flag),'n_failed',nnz(~ok));
end

function C=build_paired_contrasts(raw)
rows=cell(0,1); alphas=unique(raw.alpha,'stable');
for a=reshape(alphas,1,[])
    seeds=unique(raw.seed(abs(raw.alpha-a)<1e-12),'stable');
    for seed=reshape(seeds,1,[])
        O=raw(abs(raw.alpha-a)<1e-12 & raw.seed==seed & raw.profile=="original_domain",:);
        E=raw(abs(raw.alpha-a)<1e-12 & raw.seed==seed & raw.profile=="energy_envelope",:);
        assert(height(O)==1 && height(E)==1,'Pair is incomplete or duplicated.');
        complete=O.status=="ok" && E.status=="ok";
        rows{end+1,1}=struct('alpha',a,'seed',seed,'pair_complete',complete, ...
            'original_R_hat',O.R_hat,'energy_R_hat',E.R_hat, ...
            'original_relative_error',O.relative_error, ...
            'energy_relative_error',E.relative_error, ...
            'relative_error_change_energy_minus_original',E.relative_error-O.relative_error, ...
            'absolute_error_improved',E.relative_error<O.relative_error, ...
            'original_within_2pct',O.within_2pct,'energy_within_2pct',E.within_2pct, ...
            'two_pct_success_change',double(E.within_2pct)-double(O.within_2pct), ...
            'original_wall_s',O.wall_s,'energy_wall_s',E.wall_s, ...
            'wall_ratio_energy_over_original',E.wall_s/O.wall_s, ...
            'original_domain_exits',O.n_domain_exit_iterations, ...
            'energy_domain_exits',E.n_domain_exit_iterations, ...
            'domain_exit_change',E.n_domain_exit_iterations-O.n_domain_exit_iterations, ...
            'original_initial_search_radius',O.initial_search_radius, ...
            'energy_initial_search_radius',E.initial_search_radius, ...
            'initial_search_radius_ratio',E.initial_search_radius/O.initial_search_radius, ...
            'same_algorithm_seed',O.algorithm_seed==E.algorithm_seed); %#ok<AGROW>
    end
end
C=struct2table(vertcat(rows{:}));
end

function S=summarize_paired(C)
alphas=[unique(C.alpha,'stable');NaN]; rows=cell(numel(alphas),1);
for i=1:numel(alphas)
    if isnan(alphas(i)), g=C; label="all";
    else, g=C(abs(C.alpha-alphas(i))<1e-12,:); label=string(alphas(i)); end
    g=g(logical(g.pair_complete),:);
    rows{i}=struct('alpha_group',label,'n_complete_pairs',height(g), ...
        'median_error_change_energy_minus_original', ...
        median(g.relative_error_change_energy_minus_original,'omitnan'), ...
        'fraction_error_improved',mean(g.absolute_error_improved), ...
        'mean_two_pct_success_change',mean(g.two_pct_success_change), ...
        'median_wall_ratio_energy_over_original', ...
        median(g.wall_ratio_energy_over_original,'omitnan'), ...
        'median_domain_exit_change',median(g.domain_exit_change,'omitnan'), ...
        'median_initial_search_radius_ratio',median(g.initial_search_radius_ratio,'omitnan'));
end
S=struct2table(vertcat(rows{:}));
end

function q=empirical_percentile(x,p)
x=sort(x(isfinite(x)));
if isempty(x), q=NaN; else, q=x(max(1,ceil(p*numel(x)))); end
end

function tag=alpha_tag(a)
tag="alpha_"+replace(sprintf('%.6g',a),'.','p');
end

function files=source_files(here,funcDir,modelDir)
names={'run_experiment_C_controlled_GA.m','test_experiment_C_controlled_GA.m', ...
    'experiment_C_2d_reference.m'};
files=cellfun(@(n)fullfile(here,n),names,'UniformOutput',false);
original=dir(fullfile(funcDir,'*.m'));
files=[files,arrayfun(@(d)fullfile(d.folder,d.name),original,'UniformOutput',false)', ...
    {fullfile(modelDir,'sistema.m')}];
end

function snapshot_sources(files,destination)
mkdir(destination); mkdir(fullfile(destination,'experiment'));
mkdir(fullfile(destination,'dynin')); mkdir(fullfile(destination,'model'));
for i=1:numel(files)
    file=files{i};
    if contains(file,[filesep 'functions' filesep])
        folder=fullfile(destination,'dynin');
    elseif contains(file,[filesep 'transfer_2d_model' filesep])
        folder=fullfile(destination,'model');
    else
        folder=fullfile(destination,'experiment');
    end
    copyfile(file,fullfile(folder,get_name(file)));
end
end

function verify_source_snapshot(files,destination)
for i=1:numel(files)
    file=files{i};
    if contains(file,[filesep 'functions' filesep])
        folder=fullfile(destination,'dynin');
    elseif contains(file,[filesep 'transfer_2d_model' filesep])
        folder=fullfile(destination,'model');
    else
        folder=fullfile(destination,'experiment');
    end
    saved=fullfile(folder,get_name(file));
    assert(isfile(saved) && strcmp(fileread(file),fileread(saved)), ...
        'Source changed since this experiment started: %s',file);
end
end

function name=get_name(file)
[~,stem,ext]=fileparts(file); name=[stem ext];
end

function atomic_csv(T,file)
[folder,stem,ext]=fileparts(file); tmp=fullfile(folder,[stem '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end

function atomic_mat(file,name,value)
[folder,stem,ext]=fileparts(file); tmp=fullfile(folder,[stem '_writing' ext]);
S=struct(); S.(name)=value; save(tmp,'-struct','S'); movefile(tmp,file,'f');
end
