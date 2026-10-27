% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Proposed-method implementation, comparison, or supporting model code.
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
function outDir=run_sampled_forward_comparison(o,resumeDirectory)
if nargin<1 || isempty(o), o=sampled_forward_options(); end
if nargin<2, resumeDirectory=""; end
[root,repo,original,cleanup]=sampled_forward_setup(); %#ok<ASGLU>
validate_options(o);
modelDir=fullfile(repo,'work','DynIn','DynIn_v1.1.0','VanDerPolDuffing_NLTVA');
dyninDir=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
[cases,~]=original.cases(modelDir);
% The historical comparison contained an unverified radius. Never score
% the coupled model against that value in this new experiment.
coupled=cases.model_id=="habib_vdp_tmd_4d";
cases.R_reference(coupled)=NaN;
cases.reference_kind(coupled)="no_independent_reference";
cases.reference_source(coupled)="Boundary validation required; no error score";
cases.reference_kind(cases.model_id=="separable_qc_bd_4d")="analytical_product_evaluated_numerically";
ids=string(o.benchmarks(:));
assert(~isempty(ids),'Select at least one benchmark.');
if isscalar(ids) && ids=="all", ids=cases.model_id; end
assert(all(ismember(ids,cases.model_id)) && numel(unique(ids))==numel(ids), ...
    'Unknown or repeated benchmark name. See test_sampled_forward_comparison.m.');
cases=cases(ismember(cases.model_id,ids),:);
o.benchmarks=reshape(cases.model_id,1,[]); o.seeds=reshape(o.seeds,1,[]);
signature=sampled_forward_io('signature',root,repo);
if strlength(string(resumeDirectory))==0
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    outDir=fullfile(root,['outputs_sampled_forward_' char(o.mode) '_' stamp]);
    mkdir(outDir); mkdir(fullfile(outDir,'runs')); mkdir(fullfile(outDir,'dynin_models'));
    schedule=make_schedule(cases,o);
    definition=struct('options',o,'signature',signature,'schedule',schedule, ...
        'matlab_version',version,'created',char(datetime('now')));
    sampled_forward_io('save',fullfile(outDir,'study_definition.mat'),definition);
    sampled_forward_io('snapshot',signature,repo,outDir);
else
    [ok,info]=fileattrib(char(resumeDirectory));
    assert(ok && info.directory,'Resume directory was not found.'); outDir=info.Name;
    saved=load(fullfile(outDir,'study_definition.mat'));
    assert(isequaln(saved.options,o),'Resume options differ from the saved study.');
    assert(isequal(saved.signature,signature),'Source files changed. Start a new study to avoid mixing implementations.');
    schedule=saved.schedule;
end
sampled_forward_io('table',cases,fullfile(outDir,'benchmark_references.csv'));
sampled_forward_io('table',schedule,fullfile(outDir,'randomized_execution_schedule.csv'));
configs=original.configurations(cases,fullfile(outDir,'dynin_models'),modelDir);
manifest=cell(0,1);
for j=1:height(cases)
    caseRow=table2struct(cases(j,:)); id=char(caseRow.model_id); d=configs.(id);
    if o.mode=="smoke", d.tfinal=2; d.numberOfSteps=3; d.numGen=2; end
    d=sampled_forward_config(d,o);
    configs.(id)=d;
    [p,c,s]=sampled_forward_model(caseRow,d,o);
    % Full settings are saved separately from the timed algorithms.
    settings=struct('dynin',d,'proposedClassifier',c,'proposedSearch',s,'problem',p);
    sampled_forward_io('save',fullfile(outDir,[id '_settings.mat']),settings);
    for method=["dynin_original_ga","proposed_sampled_forward"]
        r=struct('model_id',string(id),'method',method,'dimension',caseRow.dimension, ...
            'target',string(mat2str(p.target,12)),'weight',string(mat2str(p.weight,12)), ...
            'domain',string(mat2str([p.lower p.upper],12)), ...
            'discr',c.discr,'target_cells',c.targetCells,'tfinal',c.tfinal,'Ts',c.Ts, ...
            'RelTol',c.RelTol,'AbsTol',c.AbsTol,'rep_fix_point',c.repFixPoint, ...
            'rep_periodic',c.repPeriodic,'retry_unresolved',c.retryUnresolved, ...
            'energy_preclassification',false,'trajectory_candidate_reuse',false, ...
            'grid_label_reuse',true,'conflict_detection',false, ...
            'grid_label_priority',"target before non-target", ...
            'type_x0',NaN,'outer_budget',NaN,'query_budget',NaN,'direction_budget',NaN, ...
            'search_radius_cap',NaN,'wall_guard_s',NaN, ...
            'target_definition',"original DynIn grid target-cell construction", ...
            'backward_integration',false,'classifier',"native sampled grid rules", ...
            'automatic',1,'check_min_periodic',0,'min_periodic_radius',.005, ...
            'integrator',"single ode45 with sampled callback", ...
            'MaxStep',.1*d.Ts,'refinement_factor',d.refinementFactor, ...
            'base_discr',d.baseDiscr,'base_requested_k',d.baseRequestedK, ...
            'base_effective_k',d.baseEffectiveK, ...
            'physical_cell_width',string(mat2str(p.cellWidth,14)), ...
            'nominal_target_width',string(mat2str(2*p.targetHalfWidth,14)));
        if method=="dynin_original_ga"
            r.discr=d.discr; r.target_cells=d.targetCells; r.tfinal=d.tfinal;
            r.Ts=d.Ts; r.RelTol=d.RelTol; r.AbsTol=d.AbsTol;
            r.rep_fix_point=d.repFixPoint; r.rep_periodic=d.repPeriodic;
            r.retry_unresolved=false; r.trajectory_candidate_reuse=true;
            r.integrator="native segmented ode45";
            r.type_x0=1; r.outer_budget=d.numberOfSteps;
            r.search_radius_cap=min([p.sqrtWeight.*(p.target-p.lower),p.sqrtWeight.*(p.upper-p.target)]);
            r.target_definition="original DynIn grid target-cell construction";
        else
            r.trajectory_candidate_reuse=false;
            if caseRow.dimension==2
                r.query_budget=s.queryBudget; r.direction_budget=s.maxDirections;
                r.search_radius_cap=s.maxRadius; r.wall_guard_s=s.maxSeconds;
            else
                r.query_budget=c.queryBudget; r.direction_budget=c.maxDirections;
                r.search_radius_cap=c.maxRadius; r.wall_guard_s=c.maxWallSeconds;
            end
        end
        manifest{end+1,1}=r; %#ok<AGROW>
    end
end
manifest=struct2table(vertcat(manifest{:}));
sampled_forward_audit(manifest);
sampled_forward_io('table',manifest,fullfile(outDir,'configuration_manifest.csv'));
if o.runSelfTests
    testResult=sampled_forward_selftest(configs,cases,o);
    sampled_forward_io('table',testResult,fullfile(outDir,'classifier_implementation_checks.csv'));
end
fprintf('\nSampled single-ODE comparison: %s, %d models, %d paired seeds, %d runs.\n%s\n', ...
    o.mode,height(cases),numel(o.seeds),height(schedule),outDir);
for k=1:height(schedule)
    task=table2struct(schedule(k,:)); file=fullfile(outDir,'runs',char(task.run_key+".mat"));
    if isfile(file)
        saved=load(file,'row');
        if saved.row.execution_ok
            fprintf('[%d/%d] SKIP %s\n',k,height(schedule),task.run_key); continue
        end
    end
    caseRow=table2struct(cases(cases.model_id==task.model_id,:));
    d=configs.(char(task.model_id)); row=empty_row(task,caseRow,o);
    [p,c,s,api]=sampled_forward_model(caseRow,d,o);
    details=struct(); fprintf('[%d/%d] START %s\n',k,height(schedule),task.run_key);
    wall=tic;
    try
        % Both methods must resolve the same physical model and solver.
        modelGuard=sampled_forward_activate(d,repo); %#ok<NASGU>
        if task.method=="dynin_original_ga"
            % Avoid current-folder sistema.m shadowing the intended model.
            [r,details]=original.dynin(d,dyninDir,task.algorithm_seed,k);
            row.R_hat=r.R_hat; row.algorithm_runtime_s=r.algorithm_runtime_s;
            row.query_count=r.query_count; row.trajectory_count=r.query_count;
            row.execution_ok=r.success; row.estimate_available=isfinite(r.R_hat);
            row.valid_estimate=row.execution_ok && row.estimate_available;
            row.stop_status=r.stop_status; row.error_message=r.error_message;
            if isfield(details,'time_steps_sim')
                row.ode_solver_calls=sum(max(0,details.time_steps_sim-1));
                row.sample_check_count=row.ode_solver_calls;
            end
            % Original automatic=1 loses the pre-convention unknown count.
            row.unresolved_count=NaN; row.converged=false;
        else
            [r,details]=sampled_forward_proposed(p,c,s,api,task.algorithm_seed);
            names=fieldnames(r);
            for f=1:numel(names), row.(names{f})=r.(names{f}); end
            row.execution_ok=true;
        end
    catch ME
        row.execution_ok=false; row.stop_status="execution_error";
        row.error_message=string(getReport(ME,'extended','hyperlinks','off'));
    end
    clear modelGuard
    row.wall_runtime_s=toc(wall); row.finished=string(datetime('now'));
    if row.estimate_available && isfinite(row.R_reference)
        row.absolute_error=abs(row.R_hat-row.R_reference);
        row.relative_error=row.absolute_error/row.R_reference;
        row.signed_relative_error=(row.R_hat-row.R_reference)/row.R_reference;
    end
    if task.method=="proposed_sampled_forward"
        row.review_required=~row.valid_estimate || ~row.converged || row.domain_exit_count>0 || row.recurrence_count>0 || row.grid_cache_hit_count>0 || row.forced_non_target_count>0;
    else
        row.review_required=~row.execution_ok;
    end
    sampled_forward_io('save',file,struct('row',row,'details',details));
    sampled_forward_io('export',outDir,schedule);
    fprintf('[%d/%d] SAVED R=%.8g, queries=%g, ODE calls=%g, core=%.2fs, %s\n', ...
        k,height(schedule),row.R_hat,row.query_count,row.ode_solver_calls, ...
        row.algorithm_runtime_s,row.stop_status);
end
raw=sampled_forward_io('export',outDir,schedule);
fprintf('\nSaved %d/%d rows. Execution failures=%d; Proposed review flags=%d.\n', ...
    height(raw),height(schedule),sum(~raw.execution_ok), ...
    sum(raw.review_required & raw.method=="proposed_sampled_forward"));
fprintf('Raw: %s\nSummary: %s\n',fullfile(outDir,'raw_data_all_runs.csv'), ...
    fullfile(outDir,'summary_by_model_and_method.csv'));
if o.mode=="smoke", fprintf('SMOKE ONLY: do not use these shortened runs as scientific results.\n'); end
assert(height(raw)==height(schedule) && all(raw.execution_ok), ...
    'Some runs failed. Results are saved; inspect error_message in raw_data_all_runs.csv.');
end

function validate_options(o)
for f=[o.refinement2D,o.refinement4D]
    validateattributes(f,{'numeric'},{'scalar','integer','positive','finite'});
    assert(mod(f,2)==1,'Use an odd refinement factor to preserve odd native target-cell counts.');
end
assert(any(string(o.mode)==["smoke","pilot","full"]));
validateattributes(o.seeds,{'numeric'},{'vector','integer','positive','finite'});
assert(numel(unique(o.seeds))==numel(o.seeds));
validateattributes(o.scheduleSeed,{'numeric'},{'scalar','integer','nonnegative'});
validateattributes(o.proposedMaxSeconds,{'numeric'},{'scalar','positive','finite'});
validateattributes(o.proposed2DQueryBudget,{'numeric'},{'scalar','integer','positive'});
validateattributes(o.proposed4DQueryBudget,{'numeric'},{'scalar','integer','positive'});
end

function schedule=make_schedule(cases,o)
rows=cell(0,1);
for i=1:height(cases)
    for seed=o.seeds
        for method=["dynin_original_ga","proposed_sampled_forward"]
            key=cases.model_id(i)+"__"+method+"__seed_"+string(seed);
            rows{end+1,1}=struct('run_key',key,'model_id',cases.model_id(i), ...
                'method',method,'seed',seed,'algorithm_seed',800000+1000*cases.model_order(i)+seed); %#ok<AGROW>
        end
    end
end
schedule=struct2table(vertcat(rows{:}));
stream=RandStream('mt19937ar','Seed',o.scheduleSeed);
schedule=schedule(randperm(stream,height(schedule)),:);
schedule.execution_order=(1:height(schedule)).';
end

function row=empty_row(t,c,o)
row=struct('run_key',t.run_key,'model_id',t.model_id,'method',t.method, ...
    'seed',t.seed,'algorithm_seed',t.algorithm_seed,'execution_order',t.execution_order, ...
    'mode',o.mode,'dimension',c.dimension,'R_reference',c.R_reference, ...
    'reference_kind',c.reference_kind,'R_hat',NaN,'absolute_error',NaN, ...
    'relative_error',NaN,'signed_relative_error',NaN,'algorithm_runtime_s',NaN, ...
    'wall_runtime_s',NaN,'query_count',NaN,'trajectory_count',NaN, ...
    'ode_solver_calls',NaN,'rhs_count',NaN,'sample_check_count',NaN,'direction_count',NaN, ...
    'unresolved_count',NaN,'forced_non_target_count',NaN,'retry_count',NaN,'target_query_count',NaN, ...
    'non_target_query_count',NaN,'domain_exit_count',NaN,'recurrence_count',NaN, ...
    'initial_outside_count',NaN,'ode_failure_count',NaN, ...
    'grid_cache_hit_count',NaN,'grid_cache_target_hit_count',NaN, ...
    'grid_cache_non_target_hit_count',NaN,'cached_target_cells',NaN, ...
    'cached_non_target_cells',NaN,'cached_exit_cells',NaN, ...
    'execution_ok',false,'estimate_available',false,'valid_estimate',false, ...
    'converged',false,'review_required',true,'energy_preclassification',false, ...
    'backward_integration',false,'classifier',"native sampled grid rules", ...
    'integrator',"single ode45 with sampled callback", ...
    'stop_status',"not_run",'error_message',"",'finished',"");
if t.method=="dynin_original_ga", row.integrator="native segmented ode45"; end
end


