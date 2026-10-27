function outDir=run_experiment_C_rule_followup(stage,model,alpha,cfg,sourceDir,resumeDir)
% Isolate integration time, compare adjustment order, then test search budget.
% Original GA/classifier code is called unchanged. References only score runs.
if nargin<5, sourceDir=''; end
if nargin<6, resumeDir=''; end
stage=validatestring(char(stage),{'time_order','budget','transfer'});
model=validatestring(char(model),{'quadratic_cubic','bistable_duffing'});
validateattributes(alpha,{'numeric'},{'scalar','finite','positive'});
validateattributes(cfg.seeds,{'numeric'},{'vector','integer','positive'});
assert(numel(unique(cfg.seeds))==numel(cfg.seeds),'Seeds must be unique.');
if strcmp(model,'quadratic_cubic'), assert(alpha<1,'QC reference requires alpha<1.'); end
if strcmp(stage,'transfer')
    assert(strcmp(model,'bistable_duffing'),'Transfer stage is the prespecified Duffing test.');
end
if strcmp(cfg.mode,'confirm')
    assert(numel(cfg.seeds)>=30 && isempty(intersect(cfg.seeds,1:10)), ...
        'Use at least 30 fresh confirmation seeds, not development seeds 1:10.');
end
cfg.budgets=100;
if strcmp(stage,'budget'), cfg.budgets=[100 200]; end
if strcmp(cfg.mode,'smoke')
    cfg.budgets=5;
    if strcmp(stage,'budget'), cfg.budgets=[5 10]; end
end
here=fileparts(mfilename('fullpath'));
funcDir=fullfile(fileparts(here),'work','DynIn','DynIn_v1.1.0','functions');
modelDir=fullfile(here,'transfer_2d_model');
assert(isfile(fullfile(funcDir,'compute_LIM_FP.m')),'Original DynIn functions not found.');
oldPath=path; oldRng=rng;
pathGuard=onCleanup(@()path(oldPath));
rngGuard=onCleanup(@()rng(oldRng));
restoredefaultpath;
addpath(here,'-begin'); addpath(funcDir,'-begin'); addpath(modelDir,'-begin');
assert(strcmpi(which('compute_LIM_FP'),fullfile(funcDir,'compute_LIM_FP.m')));
assert(strcmpi(which('sistema'),fullfile(modelDir,'sistema.m')));

% Check the source before creating a budget output, so invalid sources fail early.
frozen=[];
if strcmp(stage,'budget')
    assert(~isempty(sourceDir),'Set sourceDir to the completed time_order/transfer output.');
    frozen=load_frozen(sourceDir,model,alpha,cfg,here,funcDir,modelDir);
else
    assert(isempty(sourceDir),'sourceDir is used only by the budget stage.');
end
if isempty(resumeDir)
    outDir=fullfile(here,['outputs_followup_' stage '_' model '_' ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
else
    outDir=char(resumeDir);
    assert(isfolder(outDir),'Resume folder does not exist.');
end
snapshot=fullfile(outDir,'source_snapshot');
paths=source_paths(here,funcDir,modelDir);
configFile=fullfile(outDir,'run_configuration.mat');
if isfile(configFile)
    old=load(configFile);
    assert(strcmp(old.stage,stage) && strcmp(old.model,model) && old.alpha==alpha && ...
        isequaln(old.cfg,cfg) && strcmp(old.sourceDir,sourceDir), ...
        'Resume settings differ; restore them or start a new output.');
    verify_sources(paths,snapshot);
else
    save(configFile,'stage','model','alpha','cfg','sourceDir');
    mkdir(snapshot);
    for i=1:numel(paths), copyfile(paths{i},snapshot); end
    copyfile(fullfile(here,'test_experiment_C_rule_followup.m'),snapshot);
end
fprintf('\nExperiment C follow-up: %s / %s / alpha=%.4g / %s\n',stage,model,alpha,cfg.mode);
fprintf('Output directory:\n%s\n',outDir);
fprintf('Original type_x0=1. Diagnostic unknowns remain separate from non-target labels.\n');
if strcmp(stage,'budget')
    P=frozen.P; audit=frozen.audit; f=frozen.f;
    % No retuning: repeat only GA searches at the two trajectory budgets.
    save(fullfile(outDir,'frozen_selection_used.mat'),'frozen');
    cost=frozen.cost;
    cost.reused_from_source=true;
else
    [initial,f]=experiment_C_rule_physics('initial',model,alpha,cfg);
    save(fullfile(outDir,'physical_features.mat'),'initial','f');
    writetable(struct2table(f),fullfile(outDir,'physical_features.csv'));
    starts=experiment_C_followup_plan('profiles',initial,f,cfg);
    writetable(struct2table(starts),fullfile(outDir,'prespecified_starting_profiles.csv'));
    fprintf('Step 1/4: shared calibration probes (no analytical LIM).\n');
    D=experiment_C_rule_diagnostics('dataset','calibration',f,cfg,outDir);
    fprintf('Step 2/4: fixed-grid time controls and two adjustment orders.\n');
    selected=cell(numel(starts),1); logs=cell(0,1);
    for i=1:numel(starts)
        fprintf('[profile %d/%d] %s\n',i,numel(starts),starts(i).rule_id);
        [selected{i},trace]=tune_profile(starts(i),D,f,cfg,outDir);
        logs=[logs;trace]; %#ok<AGROW>
        atomic_csv(struct2table(vertcat(selected{1:i})),fullfile(outDir,'selected_parameters.csv'));
        atomic_csv(struct2table(vertcat(logs{:})),fullfile(outDir,'adjustment_log.csv'));
    end
    P=struct2table(vertcat(selected{:}));
    L=struct2table(vertcat(logs{:}));
    fprintf('Step 3/4: independent holdout directions; no further adjustment.\n');
    H=experiment_C_rule_diagnostics('dataset','holdout',f,cfg,outDir);
    audits=cell(height(P),1);
    for i=1:height(P)
        [a,~,~]=experiment_C_rule_diagnostics('classify',H,'holdout',table2struct(P(i,:)),f,cfg,outDir);
        a.rule_id=P.rule_id(i); audits{i}=a;
        atomic_csv(struct2table(vertcat(audits{1:i})),fullfile(outDir,'holdout_by_profile.csv'));
    end
    audit=struct2table(vertcat(audits{:}));
    [~,uniqueKeys]=unique(L.cache_key,'stable');
    [~,uniqueHoldoutKeys]=unique(audit.cache_key,'stable');
    cost=struct('calibration_oracle_s',sum(D.truth_wall_s), ...
        'holdout_oracle_s',sum(H.truth_wall_s), ...
        'unique_calibration_classifier_s',sum(L.classifier_wall_s(uniqueKeys)), ...
        'unique_holdout_classifier_s',sum(audit.classifier_wall_s(uniqueHoldoutKeys)), ...
        'reused_from_source',false);
    % The eligible profile is prespecified, never chosen using Rref or GA outcomes.
    keep=P.rule_id=="time_first";
    frozen=struct('P',P(keep,:),'audit',audit(audit.rule_id=="time_first",:), ...
        'f',f,'cfg',cfg,'model',model,'alpha',alpha,'cost',cost,'eligible',false);
    frozen.eligible=experiment_C_followup_plan('eligible',table2struct(frozen.P), ...
        table2struct(frozen.audit));
    frozen.created_before_reference=true;
    atomic_mat(fullfile(outDir,'frozen_time_first.mat'),'frozen',frozen);
    if ~frozen.eligible
        warning('DynInFollowup:NotFrozen', ...
            'time_first did not pass all checks. Budget stage is blocked; inspect diagnostics.');
    end
end
writetable(P,fullfile(outDir,'selected_parameters.csv'));
writetable(audit,fullfile(outDir,'holdout_by_profile.csv'));
writetable(struct2table(cost),fullfile(outDir,'diagnostic_setup_cost.csv'));

fprintf('Step 4/4: score original GA searches, with randomized configuration order.\n');
timer=tic;
[Rref,residual]=experiment_C_2d_reference(model,alpha);
reference=table(string(model),alpha,Rref,residual,toc(timer), ...
    'VariableNames',{'model','alpha','reference_LIM','reference_residual','reference_wall_s'});
writetable(reference,fullfile(outDir,'reference_audit.csv'));
schedule=experiment_C_followup_plan('schedule',P,cfg,model,alpha);
atomic_csv(schedule,fullfile(outDir,'randomized_schedule.csv'));
fprintf('%d profiles x %d budgets x %d seeds = %d GA runs.\n', ...
    height(P),numel(cfg.budgets),numel(cfg.seeds),height(schedule));
folder=fullfile(outDir,'run_checkpoints');
if ~isfolder(folder), mkdir(folder); end
raw=table(); rawFile=fullfile(outDir,'raw_data_all_runs.csv');
% Rebuild from per-run checkpoints, so interruption between MAT/CSV is safe.
for i=1:height(schedule)
    s=table2struct(schedule(i,:));
    p=table2struct(P(P.rule_id==s.rule_id,:));
    checkpoint=fullfile(folder,char(s.run_key+".mat"));
    if isfile(checkpoint)
        saved=load(checkpoint,'result'); row=saved.result.row;
        fprintf('[run %d/%d] RESUME saved %s\n',i,height(schedule),s.run_key);
    else
        fprintf('[run %d/%d] START %s, Ntraj=%d, seed=%d\n', ...
            i,height(schedule),s.rule_id,s.number_of_steps,s.seed);
        rng(s.algorithm_seed,'twister');
        [row,history]=run_ga(p,s,f,cfg);
        row.reference_LIM=Rref;
        row.relative_error=abs(row.R_hat-Rref)/Rref;
        row.signed_error=(row.R_hat-Rref)/Rref;
        result=struct('row',row,'history',history);
        atomic_mat(checkpoint,'result',result);
        if cfg.writeTrajectoryHistory && ~isempty(history)
            atomic_csv(history,fullfile(folder,char(s.run_key+"_history.csv")));
        end
        fprintf('[run %d/%d] DONE R=%.7g, error=%.3g%%, wall=%.2fs, %s\n', ...
            i,height(schedule),row.R_hat,100*row.relative_error,row.wall_s,row.status);
    end
    if isempty(raw), raw=struct2table(row); else, raw=[raw;struct2table(row)]; end %#ok<AGROW>
    atomic_csv(raw,rawFile);
end
S=summarize(raw,P,audit,cfg);
atomic_csv(S,fullfile(outDir,'summary_by_profile_and_budget.csv'));
C=paired_contrasts(raw,stage,cfg);
atomic_csv(C,fullfile(outDir,'paired_contrasts_by_seed.csv'));
atomic_csv(contrast_summary(C),fullfile(outDir,'paired_contrast_summary.csv'));
fprintf('\nFinished.\nRaw: %s\nSummary: %s\n',rawFile, ...
    fullfile(outDir,'summary_by_profile_and_budget.csv'));
end

function [p,trace]=tune_profile(p,D,f,cfg,outDir)
[S,Q,key]=experiment_C_rule_diagnostics('classify',D,'calibration',p,f,cfg,outDir);
trace={log_row(p,0,"initial",S,key,"initial_diagnosis",false,NaN,NaN)};
blocks=strings(0,1);
if p.rule_id=="grid_first", blocks=["grid" "time" "sampling"]; end
if p.rule_id=="time_first", blocks=["time" "grid" "sampling"]; end
verified=false; nAdopted=0;
for pass=1:cfg.maxCombinedPasses
    if isempty(blocks), break; end
    stableAll=true;
    for block=blocks
        stable=false;
        for attempt=1:cfg.maxRefinements
            [q,allowed]=refine(p,block,f,cfg);
            fprintf('  [%s pass %d] %s: N=%d k=%d T=%.5g Ts=%.5g\n', ...
                p.rule_id,pass,block,q.discr,q.k,q.tfinal,q.Ts);
            if ~allowed
                trace{end+1,1}=log_row(p,pass,block,S,key, ...
                    "resource_or_geometry_limit",false,NaN,NaN); %#ok<AGROW>
                break
            end
            [B,QB,newKey]=experiment_C_rule_diagnostics('classify',D,'calibration',q,f,cfg,outDir);
            [action,stable,change,pathChange]=experiment_C_rule_decision(S,B,Q,QB,cfg,block);
            trace{end+1,1}=log_row(q,pass,block,B,newKey,action,stable,change,pathChange); %#ok<AGROW>
            fprintf('    %s; false-safe=%d, false-unsafe=%d, unresolved=%d\n', ...
                action,B.n_false_safe,B.n_false_unsafe,B.n_unresolved);
            if action=="adopt_and_recheck"
                p=q; S=B; Q=QB; key=newKey; nAdopted=nAdopted+1;
                % Earlier stability checks no longer validate the new settings.
                stableAll=false;
            else
                break
            end
        end
        stableAll=stableAll && stable;
    end
    verified=stableAll;
    if verified, break; end
end
T=struct2table(vertcat(trace{:}));
[~,idx]=unique(T.cache_key,'stable');
p.calibration_pass=S.diagnostic_pass;
p.verification_pass=verified;
p.n_adopted_changes=nAdopted;
p.calibration_classifier_s=sum(T.classifier_wall_s(idx));
p.calibration_false_safe=S.false_safe_rate;
p.calibration_false_unsafe=S.false_unsafe_rate;
p.calibration_unresolved=S.unresolved_rate;
p.n_classifier_configurations=numel(idx);
end

function [q,ok]=refine(p,block,f,cfg)
q=p; ok=true;
switch char(block)
    case 'grid'
        [q,ok]=experiment_C_rule_physics('regrid',p,2*p.discr,f,cfg);
    case 'time'
        q.tfinal=2*p.tfinal; ok=q.tfinal<=cfg.maximumTime;
    case 'sampling'
        q.Ts=p.Ts/2; ok=q.Ts>=cfg.minimumTs;
end
end

function r=log_row(p,pass,block,S,key,action,verified,change,pathChange)
r=struct('rule_id',p.rule_id,'pass',pass,'block',block,'discr',p.discr, ...
    'k',p.k,'tfinal',p.tfinal,'Ts',p.Ts,'target_energy_fraction',p.target_energy_fraction, ...
    'target_half_x',p.target_half_x,'target_half_v',p.target_half_v, ...
    'cache_key',key,'action',action,'verified',verified, ...
    'label_change_rate',change,'path_distance_change',pathChange, ...
    'n_false_safe',S.n_false_safe,'n_false_unsafe',S.n_false_unsafe, ...
    'n_unresolved',S.n_unresolved,'n_exceptions',S.n_exceptions, ...
    'n_domain_exit_false_unsafe',S.n_domain_exit_false_unsafe, ...
    'n_new_attractor_false_unsafe',S.n_new_attractor_false_unsafe, ...
    'diagnostic_pass',S.diagnostic_pass,'classifier_wall_s',S.classifier_wall_s);
end

function [row,history]=run_ga(p,s,f,cfg)
row=s; row.discr=p.discr; row.k=p.k; row.tfinal=p.tfinal; row.Ts=p.Ts;
row.rep_periodic=p.rep_periodic;
row.R_hat=NaN; row.wall_s=NaN; row.cpu_s=NaN;
row.timing_review_flag=false; row.started_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
row.finished_at=""; row.trajectory_evaluations=NaN;
row.horizon_exhausted_proxy=NaN; row.tail_relative_change=NaN;
row.prefix_budget=min(cfg.budgets); row.R_at_prefix_budget=NaN;
row.status="failed"; row.error_message=""; history=table();
row.estimated_allocation_GB=96*round(p.tfinal/p.Ts*s.number_of_steps/4)/1e9;
if row.estimated_allocation_GB>cfg.maximumEstimatedAllocationGB
    row.status="allocation_limit";
    row.error_message="Estimated original DynIn allocation exceeds experiment limit.";
    return
end
values={p.tfinal,p.Ts,f.weight,1,cfg.relTol,cfg.absTol, ...
    s.number_of_steps,p.k,1001,0,0,f.domain,p.discr,1, ...
    1,2,cfg.repFixPoint,p.rep_periodic,0.005,0,0,10000,40,5,9,3,8,2,5};
assert(numel(values)==29);
timer=tic; cpu0=cputime;
try
    [R,out]=compute_LIM_FP(f.target,struct('model',f.model,'alpha',f.alpha),values{:});
    row.wall_s=toc(timer); row.cpu_s=cputime-cpu0; row.R_hat=R;
    row.R_at_prefix_budget=out.R(row.prefix_budget+1);
    row.trajectory_evaluations=nnz(out.time_steps_sim>0);
    row.horizon_exhausted_proxy=nnz(out.time_steps_sim>=floor(p.tfinal/p.Ts));
    start=max(1,floor(0.8*s.number_of_steps)+1);
    row.tail_relative_change=abs(out.R(start)-R)/max(abs(R),eps);
    if isfinite(R), row.status="ok"; else, row.status="nonfinite"; end
    n=numel(out.time_steps_sim);
    history=table((1:n)',out.R(2:n+1),out.tipo(:),out.time_steps_sim(:), ...
        out.time_sim(:),out.time_x0(:), ...
        'VariableNames',{'iteration','R_hat','tipo_after_automatic_handling', ...
        'output_samples','integration_wall_s','GA_selection_wall_s'});
catch ME
    row.wall_s=toc(timer); row.cpu_s=cputime-cpu0;
    row.error_message=string(getReport(ME,'basic','hyperlinks','off'));
end
row.finished_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
% Review flag only: no samples are automatically discarded from time summaries.
row.timing_review_flag=row.wall_s>30 && row.wall_s>5*max(row.cpu_s,1);
end

function S=summarize(raw,P,audit,cfg)
rows=cell(0,1);
for i=1:height(P)
    for budget=cfg.budgets
        g=raw(raw.rule_id==P.rule_id(i) & raw.number_of_steps==budget,:);
        a=audit(audit.rule_id==P.rule_id(i),:);
        r=table2struct(P(i,:)); r.number_of_steps=budget; r.n_runs=height(g);
        r.n_completed=nnz(g.status=="ok");
        r.median_relative_error=median(g.relative_error,'omitnan');
        vals=sort(g.relative_error(isfinite(g.relative_error)));
        r.p95_relative_error=NaN;
        if ~isempty(vals), r.p95_relative_error=vals(ceil(.95*numel(vals))); end
        r.within_1pct_rate=mean(g.status=="ok" & g.relative_error<=cfg.targetRelativeError);
        r.overestimate_gt1pct_rate=mean(g.signed_error>cfg.targetRelativeError);
        r.median_wall_s=median(g.wall_s,'omitnan');
        r.median_cpu_s=median(g.cpu_s,'omitnan');
        r.n_timing_review_flags=nnz(g.timing_review_flag);
        r.median_tail_change=median(g.tail_relative_change,'omitnan');
        r.total_horizon_exhausted_proxy=sum(g.horizon_exhausted_proxy,'omitnan');
        r.holdout_false_safe=a.false_safe_rate;
        r.holdout_false_unsafe=a.false_unsafe_rate;
        r.holdout_unresolved=a.unresolved_rate;
        r.holdout_truth_unresolved=a.truth_unresolved_rate;
        r.holdout_pass=a.diagnostic_pass;
        r.meets_screening_criteria=r.calibration_pass && r.holdout_pass && ...
            r.n_completed==r.n_runs && r.total_horizon_exhausted_proxy==0 && ...
            r.within_1pct_rate>=cfg.requiredLIMSuccessRate;
        r.is_smoke=strcmp(cfg.mode,'smoke');
        if r.is_smoke, r.meets_screening_criteria=false; end
        rows{end+1,1}=r; %#ok<AGROW>
    end
end
S=struct2table(vertcat(rows{:}));
end

function C=paired_contrasts(raw,stage,cfg)
if strcmp(stage,'budget')
    ids={"time_first","time_first"};
    budgets=[max(cfg.budgets),min(cfg.budgets)];
else
    ids={"double_period","period_only";"decay_estimate","period_only"; ...
        "time_first","grid_first";"time_first","decay_estimate"};
    budgets=repmat(cfg.budgets(1),size(ids,1),2);
end
rows=cell(0,1);
for i=1:size(ids,1)
    for seed=reshape(cfg.seeds,1,[])
        a=raw(raw.rule_id==ids{i,1} & raw.number_of_steps==budgets(i,1) & raw.seed==seed,:);
        b=raw(raw.rule_id==ids{i,2} & raw.number_of_steps==budgets(i,2) & raw.seed==seed,:);
        assert(height(a)==1 && height(b)==1 && a.algorithm_seed==b.algorithm_seed);
        rows{end+1,1}=struct('candidate',string(ids{i,1}),'comparator',string(ids{i,2}), ...
            'candidate_budget',budgets(i,1),'comparator_budget',budgets(i,2),'seed',seed, ...
            'both_completed',a.status=="ok" && b.status=="ok", ...
            'delta_relative_error',a.relative_error-b.relative_error, ...
            'delta_R',a.R_hat-b.R_hat,'wall_ratio',a.wall_s/b.wall_s, ...
            'cpu_ratio',a.cpu_s/b.cpu_s, ...
            'prefix_R_difference',a.R_at_prefix_budget-b.R_at_prefix_budget, ...
            'timing_review_flag',a.timing_review_flag || b.timing_review_flag); %#ok<AGROW>
    end
end
C=struct2table(vertcat(rows{:}));
end

function S=contrast_summary(C)
keys=unique(C(:,{'candidate','comparator','candidate_budget','comparator_budget'}),'rows','stable');
rows=cell(height(keys),1);
for i=1:height(keys)
    k=keys(i,:);
    g=C(C.candidate==k.candidate & C.comparator==k.comparator & ...
        C.candidate_budget==k.candidate_budget & C.comparator_budget==k.comparator_budget,:);
    r=table2struct(k); r.n_pairs=height(g); r.n_complete_pairs=nnz(g.both_completed);
    r.n_pairs_requiring_timing_review=nnz(g.timing_review_flag);
    valid=g(g.both_completed,:);
    r.median_paired_error_change=median(valid.delta_relative_error,'omitnan');
    r.n_lower_error=nnz(valid.delta_relative_error<0);
    r.n_higher_error=nnz(valid.delta_relative_error>0);
    r.n_equal_error=nnz(valid.delta_relative_error==0);
    r.median_paired_wall_ratio=median(valid.wall_ratio,'omitnan');
    r.median_paired_cpu_ratio=median(valid.cpu_ratio,'omitnan');
    r.max_absolute_prefix_R_difference=max(abs(valid.prefix_R_difference),[],'omitnan');
    if isempty(r.max_absolute_prefix_R_difference), r.max_absolute_prefix_R_difference=NaN; end
    rows{i}=r;
end
S=struct2table(vertcat(rows{:}));
end

function frozen=load_frozen(folder,model,alpha,cfg,here,funcDir,modelDir)
file=fullfile(folder,'frozen_time_first.mat');
assert(isfile(file),'Source has no frozen_time_first.mat. Run time_order or transfer first.');
data=load(file,'frozen'); frozen=data.frozen;
assert(frozen.eligible && frozen.created_before_reference, ...
    'Source time_first profile failed classification/stability checks. Do not freeze it.');
assert(strcmp(frozen.model,model) && frozen.alpha==alpha,'Source model/alpha mismatch.');
assert(isequaln(experiment_C_followup_plan('constants',cfg), ...
    experiment_C_followup_plan('constants',frozen.cfg)), ...
    'Rule constants or diagnostic settings differ from the source.');
assert(strcmp(cfg.mode,'smoke')==strcmp(frozen.cfg.mode,'smoke'), ...
    'A smoke-test profile cannot be used as an experimental frozen configuration.');
verify_sources(source_paths(here,funcDir,modelDir),fullfile(folder,'source_snapshot'));
end

function paths=source_paths(here,funcDir,modelDir)
names={'run_experiment_C_rule_followup.m','experiment_C_followup_plan.m', ...
    'experiment_C_rule_defaults.m','experiment_C_rule_physics.m', ...
    'experiment_C_rule_diagnostics.m','experiment_C_rule_decision.m', ...
    'estimate_dynin_parameters_from_physics.m','experiment_C_2d_reference.m'};
paths=cellfun(@(n)fullfile(here,n),names,'UniformOutput',false);
files=dir(fullfile(funcDir,'*.m'));
paths=[paths, arrayfun(@(d)fullfile(d.folder,d.name),files,'UniformOutput',false)', ...
    {fullfile(modelDir,'sistema.m')}];
% Names must be unique because the snapshot is a flat, readable directory.
[~,names,extensions]=cellfun(@fileparts,paths,'UniformOutput',false);
assert(numel(unique(strcat(names,extensions)))==numel(paths),'Duplicate snapshot file names.');
end

function verify_sources(paths,snapshot)
for i=1:numel(paths)
    [~,name,ext]=fileparts(paths{i}); archived=fullfile(snapshot,[name ext]);
    assert(isfile(archived) && strcmp(fileread(paths{i}),fileread(archived)), ...
        'Source changed: %s. Do not mix implementations in one experiment.',paths{i});
end
end

function atomic_csv(T,file)
[folder,name,ext]=fileparts(file);
tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end

function atomic_mat(file,name,value)
[folder,stem,ext]=fileparts(file);
tmp=fullfile(folder,[stem '_writing' ext]);
data=struct(); data.(name)=value;
save(tmp,'-struct','data'); movefile(tmp,file,'f');
end
