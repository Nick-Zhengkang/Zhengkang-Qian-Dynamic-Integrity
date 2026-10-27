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
function outDir=run_experiment_C_2d_hypotheses(model,alpha,cfg,resumeDir)
% Calibrate explicit transfer rules; audit independently; then score GA LIM.
if nargin<4, resumeDir=''; end
model=validatestring(char(model), ...
    {'quadratic_cubic','bistable_duffing','cosine_quadratic_drag'});
validateattributes(alpha,{'numeric'},{'scalar','positive','finite'});
validateattributes(cfg.seeds,{'numeric'},{'vector','integer','positive'});
validateattributes(cfg.budgets,{'numeric'},{'vector','integer','positive'});
assert(numel(unique(cfg.seeds))==numel(cfg.seeds),'Seeds must be unique.');
assert(numel(unique(cfg.budgets))==numel(cfg.budgets),'Budgets must be unique.');
if strcmp(model,'quadratic_cubic')
    assert(alpha<1,'The inherited analytical reference currently requires alpha<1.');
end
if strcmp(cfg.mode,'confirm')
    assert(numel(cfg.seeds)>=30 && isempty(intersect(cfg.seeds,1:10)), ...
        'Confirmation requires at least 30 seeds outside development seeds 1:10.');
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
if isempty(resumeDir)
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    outDir=fullfile(here,['outputs_rule_hypotheses_' model '_' stamp]);
    mkdir(outDir);
else
    outDir=char(resumeDir); assert(isfolder(outDir),'Resume folder does not exist.');
end
configFile=fullfile(outDir,'run_configuration.mat');
names={'run_experiment_C_2d_hypotheses.m','experiment_C_rule_defaults.m', ...
    'experiment_C_rule_physics.m','experiment_C_rule_diagnostics.m', ...
    'experiment_C_rule_decision.m','estimate_dynin_parameters_from_physics.m', ...
    'experiment_C_2d_reference.m'};
sourcePaths=cellfun(@(n)fullfile(here,n),names,'UniformOutput',false);
sourcePaths=[sourcePaths,{fullfile(funcDir,'compute_LIM_FP.m'), ...
    fullfile(funcDir,'simulation_DI.m'),fullfile(modelDir,'sistema.m')}];
snapshot=fullfile(outDir,'source_snapshot');
if isfile(configFile)
    old=load(configFile);
    assert(strcmp(old.model,model) && old.alpha==alpha && isequaln(old.cfg,cfg), ...
        'Resume model, alpha, mode or rule constants differ.');
    for i=1:numel(sourcePaths)
        [~,stem,ext]=fileparts(sourcePaths{i});
        archived=fullfile(snapshot,[stem ext]);
        assert(isfile(archived) && strcmp(fileread(sourcePaths{i}),fileread(archived)), ...
            'Source changed since checkpoint; start a new output directory.');
    end
else
    save(configFile,'model','alpha','cfg');
    mkdir(snapshot);
    for i=1:numel(sourcePaths), copyfile(sourcePaths{i},snapshot); end
    copyfile(fullfile(here,'test_experiment_C_2d_hypotheses.m'),snapshot);
end
[initial,f]=experiment_C_rule_physics('initial',model,alpha,cfg);
save(fullfile(outDir,'physical_features.mat'),'initial','f');
feature=struct2table(f);
writetable(feature,fullfile(outDir,'physical_features.csv'));
recipes=recipe_table();
writetable(recipes,fullfile(outDir,'candidate_rules.csv'));
fprintf('\nExperiment C: transferable-rule hypotheses / %s alpha=%.4g / %s\n', ...
    model,alpha,cfg.mode);
fprintf('7 rules; %d seeds; %d budget(s); %d GA runs.\nOutput: %s\n', ...
    numel(cfg.seeds),numel(cfg.budgets),7*numel(cfg.seeds)*numel(cfg.budgets),outDir);
fprintf('Step 1/4: build calibration labels from energy trapping and forward dynamics.\n');
D=experiment_C_rule_diagnostics('dataset','calibration',f,cfg,outDir);

fprintf('Step 2/4: select settings using calibration diagnostics only.\n');
selected=cell(height(recipes),1); logs=cell(0,1);
for i=1:height(recipes)
    fprintf('[rule %d/%d] %s\n',i,height(recipes),char(recipes.rule_id(i)));
    [p,info,trace]=tune(recipes(i,:),initial,D,f,cfg,outDir);
    selected{i}=join_structs(p,info);
    logs=[logs;trace]; %#ok<AGROW>
    atomic_csv(struct2table(vertcat(selected{1:i})),fullfile(outDir,'selected_parameters.csv'));
    atomic_csv(struct2table(vertcat(logs{:})),fullfile(outDir,'adjustment_log.csv'));
end
P=struct2table(vertcat(selected{:}));
save(fullfile(outDir,'selected_parameters.mat'),'P');

fprintf('Step 3/4: audit on different directions and radii; no retuning.\n');
H=experiment_C_rule_diagnostics('dataset','holdout',f,cfg,outDir);
audits=cell(height(P),1);
for i=1:height(P)
    p=table2struct(P(i,:));
    [a,~,~]=experiment_C_rule_diagnostics('classify',H,'holdout',p,f,cfg,outDir);
    a.rule_id=P.rule_id(i);
    audits{i}=a;
    atomic_csv(struct2table(vertcat(audits{1:i})),fullfile(outDir,'holdout_by_rule.csv'));
end
audit=struct2table(vertcat(audits{:}));
cost=table(sum(D.truth_wall_s),sum(H.truth_wall_s), ...
    'VariableNames',{'shared_calibration_oracle_s','independent_holdout_oracle_s'});
writetable(cost,fullfile(outDir,'diagnostic_setup_cost.csv'));

% Only now obtain the published LIM, after all settings have been selected.
timer=tic;
[Rref,residual]=experiment_C_2d_reference(model,alpha);
reference=table(string(model),alpha,Rref,residual,toc(timer), ...
    'VariableNames',{'model','alpha','reference_LIM','reference_residual','reference_wall_s'});
writetable(reference,fullfile(outDir,'reference_audit.csv'));
schedule=make_schedule(P,cfg,model,alpha);
writetable(schedule,fullfile(outDir,'randomized_schedule.csv'));
rawFile=fullfile(outDir,'raw_data_all_runs.csv');
raw=table();
if isfile(rawFile), raw=readtable(rawFile,'TextType','string'); end
runFolder=fullfile(outDir,'run_checkpoints');
if ~isfolder(runFolder), mkdir(runFolder); end
fprintf('Step 4/4: original DynIn GA; paired starting seeds; randomized run order.\n');
for i=1:height(schedule)
    s=table2struct(schedule(i,:));
    if ~isempty(raw) && any(string(raw.run_key)==s.run_key), continue; end
    p=table2struct(P(P.rule_id==s.rule_id,:));
    checkpoint=fullfile(runFolder,char(s.run_key+".mat"));
    fprintf('[run %d/%d] START %s, Ntraj=%d, seed=%d\n', ...
        i,height(schedule),char(s.rule_id),s.number_of_steps,s.seed);
    if isfile(checkpoint)
        saved=load(checkpoint,'row'); row=saved.row;
    else
        rng(s.algorithm_seed,'twister');
        [row,history]=run_ga(p,s,f,cfg);
        row.reference_LIM=Rref;
        row.relative_error=abs(row.R_hat-Rref)/Rref;
        row.signed_error=(row.R_hat-Rref)/Rref;
        save(checkpoint,'row','history');
        if cfg.writeTrajectoryHistory && ~isempty(history)
            writetable(history,fullfile(runFolder,char(s.run_key+"_history.csv")));
        end
    end
    if isempty(raw), raw=struct2table(row); else, raw=[raw;struct2table(row)]; end %#ok<AGROW>
    atomic_csv(raw,rawFile);
    fprintf('[run %d/%d] DONE R=%.7g, err=%.3g%%, wall=%.2fs, %s\n', ...
        i,height(schedule),row.R_hat,100*row.relative_error,row.wall_s,char(row.status));
end
summary=summarize(raw,P,audit,cost,cfg);
writetable(summary,fullfile(outDir,'summary_by_rule_and_budget.csv'));
writetable(contrasts(summary,cfg),fullfile(outDir,'hypothesis_comparisons.csv'));
writetable(paired_contrasts(raw,cfg),fullfile(outDir,'paired_contrasts_by_seed.csv'));
fprintf('\nFinished. Raw: %s\nSummary: %s\n',rawFile, ...
    fullfile(outDir,'summary_by_rule_and_budget.csv'));
end

function R=recipe_table()
rule_id=["physics_only";"grid_check";"time_check";"sampling_check"; ...
    "combined";"combined_fixed_k3";"combined_period_time"];
grid_guard=logical([0;1;0;0;1;1;1]);
time_guard=logical([0;0;1;0;1;1;1]);
sampling_guard=logical([0;0;0;1;1;1;1]);
belt_mode=["energy";"energy";"energy";"energy";"energy";"fixed3";"energy"];
initial_time=["decay";"decay";"decay";"decay";"decay";"decay";"periods"];
R=table(rule_id,grid_guard,time_guard,sampling_guard,belt_mode,initial_time);
end

function [p,info,trace]=tune(recipe,p,D,f,cfg,outDir)
p.belt_mode=recipe.belt_mode;
[p,ok]=experiment_C_rule_physics('regrid',p,p.discr,f,cfg);
assert(ok,'This rule cannot represent its initial target cells.');
if recipe.initial_time=="periods", p.tfinal=min(cfg.maximumTime,f.timeFromPeriod); end
[S,Q,key]=experiment_C_rule_diagnostics('classify',D,'calibration',p,f,cfg,outDir);
trace={log_row(recipe.rule_id,0,"initial",p,S,key,"initial_diagnosis",false,NaN,NaN)};
blocks=strings(0,1);
if recipe.grid_guard, blocks(end+1)="grid"; end
if recipe.time_guard, blocks(end+1)="time"; end
if recipe.sampling_guard, blocks(end+1)="sampling"; end
verification=false; adopted=0;
passes=1; if numel(blocks)>1, passes=cfg.maxCombinedPasses; end
for pass=1:passes
    allStable=~isempty(blocks); changedInPass=false;
    for b=1:numel(blocks)
        stable=false;
        for attempt=1:cfg.maxRefinements
            [candidate,allowed]=refine(p,blocks(b),f,cfg);
            if ~allowed
                trace{end+1,1}=log_row(recipe.rule_id,pass,blocks(b), ...
                    p,S,key,"resource_or_geometry_limit",false,NaN,NaN); %#ok<AGROW>
                break
            end
            [B,QB,newKey]=experiment_C_rule_diagnostics('classify', ...
                D,'calibration',candidate,f,cfg,outDir);
            [action,stable,change,pathChange]=experiment_C_rule_decision(S,B,Q,QB,cfg,blocks(b));
            trace{end+1,1}=log_row(recipe.rule_id,pass,blocks(b), ...
                candidate,B,newKey,action,stable,change,pathChange); %#ok<AGROW>
            if action=="adopt_and_recheck"
                p=candidate; S=B; Q=QB; key=newKey;
                adopted=adopted+1; changedInPass=true;
            else
                break
            end
        end
        allStable=allStable && stable;
    end
    verification=allStable;
    if numel(blocks)>1, verification=verification && ~changedInPass; end
    if verification || ~changedInPass, break; end
end
traceTable=struct2table(vertcat(trace{:}));
[~,uniqueCache]=unique(traceTable.cache_key,'stable');
info=struct('rule_id',recipe.rule_id,'initial_time_rule',recipe.initial_time, ...
    'calibration_pass',S.diagnostic_pass,'verification_pass',verification, ...
    'n_adopted_changes',adopted,'n_classifier_evaluations',numel(uniqueCache), ...
    'calibration_classifier_s',sum(traceTable.classifier_wall_s(uniqueCache)), ...
    'calibration_false_safe',S.false_safe_rate, ...
    'calibration_false_unsafe',S.false_unsafe_rate, ...
    'calibration_unresolved',S.unresolved_rate, ...
    'initial_time_capped',max(f.timeFromDecay*(recipe.initial_time=="decay"), ...
    f.timeFromPeriod*(recipe.initial_time=="periods"))>cfg.maximumTime, ...
    'initial_grid_capped',f.requestedGrid>cfg.maximumGrid);
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

function r=log_row(id,pass,block,p,S,key,action,verified,change,pathChange)
r=struct('rule_id',id,'pass',pass,'block',block,'discr',p.discr,'k',p.k, ...
    'tfinal',p.tfinal,'Ts',p.Ts,'cache_key',key,'action',action, ...
    'verified',verified,'label_change_rate',change,'path_distance_change',pathChange, ...
    'n_false_safe',S.n_false_safe,'n_false_unsafe',S.n_false_unsafe, ...
    'n_unresolved',S.n_unresolved,'n_domain_excluded',S.n_domain_excluded, ...
    'n_exceptions',S.n_exceptions, ...
    'n_domain_exit_false_unsafe',S.n_domain_exit_false_unsafe, ...
    'n_new_attractor_false_unsafe',S.n_new_attractor_false_unsafe, ...
    'diagnostic_pass',S.diagnostic_pass,'classifier_wall_s',S.classifier_wall_s);
end

function out=join_structs(a,b)
out=a; names=fieldnames(b);
for j=1:numel(names), out.(names{j})=b.(names{j}); end
end

function S=make_schedule(P,cfg,model,alpha)
rows=cell(height(P)*numel(cfg.seeds)*numel(cfg.budgets),1); n=0;
for i=1:height(P)
    for budget=cfg.budgets
        for seed=cfg.seeds
            n=n+1;
            % Identical starting RNG state across rules and budgets.
            actualSeed=mod(seed*1000003+round(alpha*10000)+sum(double(model))*37,2^32-1);
            rows{n}=struct('rule_id',P.rule_id(i),'number_of_steps',budget, ...
                'seed',seed,'algorithm_seed',actualSeed, ...
                'run_key',P.rule_id(i)+"_N"+string(budget)+"_seed_"+string(seed));
        end
    end
end
S=struct2table(vertcat(rows{:}));
stream=RandStream('mt19937ar','Seed',20260922+round(alpha*10000)+sum(double(model)));
S=S(randperm(stream,height(S)),:); S.execution_order=(1:height(S))';
end

function [row,history]=run_ga(p,s,f,cfg)
row=join_structs(p,s);
row.R_hat=NaN; row.wall_s=NaN; row.trajectory_evaluations=NaN;
row.horizon_exhausted_proxy=NaN; row.tail_relative_change=NaN;
row.status="failed"; row.error_message=""; history=table();
% Original preallocation: three 2-D point arrays, three cell arrays,
% and the 3-column GA archive. This is an estimate, not peak-memory logging.
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
par=struct('model',f.model,'alpha',f.alpha);
timer=tic;
try
    [R,out]=compute_LIM_FP(f.target,par,values{:});
    row.wall_s=toc(timer); row.R_hat=R;
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
    row.wall_s=toc(timer); row.error_message=string(getReport(ME,'basic','hyperlinks','off'));
end
end

function S=summarize(raw,P,audit,cost,cfg)
rows=cell(height(P)*numel(cfg.budgets),1); n=0;
for i=1:height(P)
    for budget=cfg.budgets
        n=n+1; id=P.rule_id(i);
        g=raw(string(raw.rule_id)==id & raw.number_of_steps==budget,:);
        d=audit(audit.rule_id==id,:);
        r=table2struct(P(i,:));
        r.number_of_steps=budget; r.n_runs=height(g);
        r.n_completed=nnz(string(g.status)=="ok");
        r.median_relative_error=median(g.relative_error,'omitnan');
        good=sort(g.relative_error(isfinite(g.relative_error)));
        r.p95_relative_error=NaN;
        if ~isempty(good), r.p95_relative_error=good(ceil(0.95*numel(good))); end
        r.within_1pct_rate=mean(g.relative_error<=cfg.targetRelativeError);
        r.overestimate_gt1pct_rate=mean(g.signed_error>cfg.targetRelativeError);
        r.median_wall_s=median(g.wall_s,'omitnan');
        r.median_tail_change=median(g.tail_relative_change,'omitnan');
        r.total_horizon_exhausted_proxy=sum(g.horizon_exhausted_proxy,'omitnan');
        r.holdout_false_safe=d.false_safe_rate;
        r.holdout_false_unsafe=d.false_unsafe_rate;
        r.holdout_unresolved=d.unresolved_rate;
        r.holdout_truth_unresolved=d.truth_unresolved_rate;
        r.holdout_domain_excluded=d.n_domain_excluded;
        r.holdout_pass=d.diagnostic_pass;
        r.tuning_cost_s=r.calibration_classifier_s+cost.shared_calibration_oracle_s;
        r.cost_for_one_application_s=r.tuning_cost_s+r.median_wall_s;
        r.meets_screening_criteria=r.calibration_pass && r.holdout_pass && ...
            r.n_completed==r.n_runs && r.total_horizon_exhausted_proxy==0 && ...
            r.within_1pct_rate>=cfg.requiredLIMSuccessRate && ...
            r.median_relative_error<=cfg.targetRelativeError;
        r.is_smoke=strcmp(cfg.mode,'smoke');
        if r.is_smoke, r.meets_screening_criteria=false; end
        r.ready_for_confirmation=r.meets_screening_criteria && r.verification_pass;
        rows{n}=r;
    end
end
S=struct2table(vertcat(rows{:}));
end

function C=contrasts(S,cfg)
pairs=hypothesis_pairs();
rows=cell(size(pairs,1)*numel(cfg.budgets),1); n=0;
for budget=cfg.budgets
    for i=1:size(pairs,1)
        a=S(S.rule_id==pairs{i,2} & S.number_of_steps==budget,:);
        b=S(S.rule_id==pairs{i,3} & S.number_of_steps==budget,:);
        n=n+1;
        r=struct('hypothesis',pairs{i,1},'candidate',pairs{i,2},'comparator',pairs{i,3}, ...
            'number_of_steps',budget, ...
            'delta_median_relative_error',a.median_relative_error-b.median_relative_error, ...
            'delta_success_rate',a.within_1pct_rate-b.within_1pct_rate, ...
            'delta_holdout_false_safe',a.holdout_false_safe-b.holdout_false_safe, ...
            'delta_holdout_false_unsafe',a.holdout_false_unsafe-b.holdout_false_unsafe, ...
            'delta_holdout_unresolved',a.holdout_unresolved-b.holdout_unresolved, ...
            'runtime_ratio',a.median_wall_s/b.median_wall_s, ...
            'tuning_cost_ratio',a.tuning_cost_s/b.tuning_cost_s, ...
            'candidate_meets_screening',a.meets_screening_criteria, ...
            'comparator_meets_screening',b.meets_screening_criteria, ...
            'interpretation',"case_level_evidence_not_cross_model_validation");
        rows{n}=r;
    end
end
C=struct2table(vertcat(rows{:}));
end

function C=paired_contrasts(raw,cfg)
pairs=hypothesis_pairs(); rows=cell(0,1);
for budget=cfg.budgets
    for i=1:size(pairs,1)
        for seed=cfg.seeds
            a=raw(string(raw.rule_id)==pairs{i,2} & raw.number_of_steps==budget & raw.seed==seed,:);
            b=raw(string(raw.rule_id)==pairs{i,3} & raw.number_of_steps==budget & raw.seed==seed,:);
            assert(height(a)==1 && height(b)==1 && a.algorithm_seed==b.algorithm_seed, ...
                'Paired run identifiers or initial RNG states differ.');
            r=struct('hypothesis',pairs{i,1},'seed',seed,'number_of_steps',budget, ...
                'candidate',pairs{i,2},'comparator',pairs{i,3}, ...
                'both_completed',string(a.status)=="ok" && string(b.status)=="ok", ...
                'delta_relative_error',a.relative_error-b.relative_error, ...
                'runtime_ratio',a.wall_s/b.wall_s);
            rows{end+1,1}=r; %#ok<AGROW>
        end
    end
end
C=struct2table(vertcat(rows{:}));
end

function pairs=hypothesis_pairs()
pairs={"H_grid_check","grid_check","physics_only"; ...
    "H_time_check","time_check","physics_only"; ...
    "H_sampling_check","sampling_check","physics_only"; ...
    "H_combined_check","combined","physics_only"; ...
    "H_energy_belt","combined","combined_fixed_k3"; ...
    "H_decay_initial_time","combined","combined_period_time"};
end

function atomic_csv(T,file)
[folder,name,ext]=fileparts(file);
tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end
