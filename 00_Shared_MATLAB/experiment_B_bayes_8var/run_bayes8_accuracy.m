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
function outDir=run_bayes8_accuracy(o,resumeDir)
% Genda quadratic-damping Duffing, two accuracy-only BO runs, no warm start.
if nargin<1 || isempty(o), o=bayes8_options('pilot'); end
if nargin<2, resumeDir=''; end
validate_options(o);
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
shared=fullfile(repo,'experiment_A_bayesian_optimization');
adapter=fullfile(repo,'experiment_A_top6_exhaustive');
support=fullfile(repo,'experiment_B_accuracy_first_bayes');
batchSupport=fullfile(repo,'experiment_B_surrogate_accuracy');
native=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
model=fullfile(root,'model_genda_duffing');
referenceFunctions=fullfile(repo,'four_model_five_method_suite','functions');
oldPath=path; oldFolder=pwd; oldRng=rng;
cleanup=onCleanup(@() restore_session(oldPath,oldFolder,oldRng));
if ~isempty(resumeDir)
    [ok,info]=fileattrib(resumeDir); assert(ok && info.directory,'Resume directory not found.');
    resumeDir=info.Name;
end
cd(root); addpath(shared);
bayes_A_initialize_path(root,adapter,native,model);
addpath(support,'-begin'); addpath(batchSupport,'-begin');
addpath(referenceFunctions,'-begin');
accuracy_first_activate(root,shared,adapter,native,model);
assert(strcmpi(which('limbench.reference'),fullfile(referenceFunctions,'+limbench','reference.m')), ...
    'Wrong analytical-reference implementation on the MATLAB path.');
assert(exist('bayesopt','file')==2 && license('test','Statistics_Toolbox'), ...
    'Statistics and Machine Learning Toolbox is required.');
[base,reference,referenceAudit]=bayes8_problem(o);
bx=bayes8_design('baseline',base);
assert(bayes8_design('feasible',bx,o),'Default configuration is outside the search bounds.');
signature=source_signature(root,shared,adapter,support,batchSupport,native,model,referenceFunctions);
definition=struct('options',o,'base',base,'signature',signature,'matlab_version',version);
if isempty(resumeDir)
    prefix=['outputs_bayes8_' o.mode '_'];
    if o.synthetic, prefix='outputs_SYNTHETIC_bayes8_'; end
    outDir=fullfile(root,[prefix char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
    for name={'records','observations','source_snapshot'}, mkdir(fullfile(outDir,name{1})); end
    for j=1:size(signature,1)
        [~,name,ext]=fileparts(signature(j,1));
        copyfile(signature(j,1),fullfile(outDir,'source_snapshot',sprintf('%03d_%s',j,name+ext)));
    end
    surrogate_accuracy_util('save',fullfile(outDir,'study_definition.mat'),definition);
    surrogate_accuracy_util('save',fullfile(outDir,'analytical_reference.mat'), ...
        struct('reference',reference,'audit',referenceAudit));
    surrogate_accuracy_util('table',referenceAudit,fullfile(outDir,'analytical_reference_audit.csv'));
    modelInfo=table(string(o.modelId),o.alpha,string(mat2str(base.xe)), ...
        string(mat2str(base.weight)),string(mat2str(base.spaceboundary)), ...
        base.reference_LIM,string(reference.kind),string(reference.published_source), ...
        'VariableNames',{'model_id','quadratic_damping_alpha','target','distance_weights', ...
        'fixed_domain','reference_LIM','reference_kind','reference_source'});
    surrogate_accuracy_util('table',modelInfo,fullfile(outDir,'model_definition.csv'));
    surrogate_accuracy_util('table',struct2table(bayes8_design('config',bx,base)), ...
        fullfile(outDir,'default_configuration.csv'));
else
    outDir=resumeDir; previous=load(fullfile(outDir,'study_definition.mat'));
    assert(isequaln(previous,definition), ...
        'Options, MATLAB version, or numerical sources changed. Start a new study.');
end
c=struct('root',root,'shared',shared,'adapter',adapter,'native',native, ...
    'model',model,'base',base,'bx',bx,'options',o,'outDir',outDir);
budget=2*o.evaluationsPerRestart*numel(o.screenSeeds)+numel(o.screenSeeds)+2*numel(o.confirmSeeds);
fprintf('\nEIGHT-VARIABLE ACCURACY-ONLY BAYESOPT: %s\n%s\n',o.mode,outDir);
fprintf('2 x %d evaluations (%d initialization + %d later evaluations per restart).\n', ...
    o.evaluationsPerRestart,o.initialPoints,o.evaluationsPerRestart-o.initialPoints);
fprintf('%d common search seeds; up to %d saved DynIn runs, excluding worker warm-up.\n', ...
    numel(o.screenSeeds),budget);
fprintf('Genda quadratic-damping Duffing, alpha=%.3f, Euclidean metric.\n',o.alpha);
fprintf('Minimize median abs(R_hat - %.12f). Analytical-equation reference; no time gate.\n',base.reference_LIM);
fprintf('New variables: number_of_steps integer [%g,%g]; Ts real [%g,%g].\n', ...
    o.lower(7),o.upper(7),o.lower(8),o.upper(8));
if isfile(fullfile(outDir,'study_finished.mat'))
    surrogate_accuracy_util('export',outDir); fprintf('Already complete. Nothing repeated.\n'); return
end
execution=bayes8_pool(o,c);
file=fullfile(outDir,'execution_settings.mat');
if isfile(file)
    previous=load(file,'execution');
    assert(isequaln(previous.execution,execution),'Execution settings changed; start a new study.');
else
    surrogate_accuracy_util('save',file,struct('execution',execution));
end
surrogate_accuracy_util('table',struct2table(execution),fullfile(outDir,'execution_settings.csv'));
try
    names=bayes8_design('names');
    vars=optimizableVariable(names{1},[o.lower(1) o.upper(1)],'Type','integer');
    for j=2:8
        kind='integer'; if j==8, kind='real'; end
        vars(j)=optimizableVariable(names{j},[o.lower(j) o.upper(j)],'Type',kind);
    end
    for restart=1:2
        finished=fullfile(outDir,sprintf('restart_%02d_complete.mat',restart));
        checkpoint=fullfile(outDir,sprintf('restart_%02d_checkpoint.mat',restart));
        if isfile(finished), continue; end
        if isfile(checkpoint)
            saved=load(checkpoint,'BayesoptResults','optimizerRng');
            results=saved.BayesoptResults;
            assert(~any(results.ErrorTrace==1),'Previous objective failed. Inspect the saved trace.');
            remaining=o.evaluationsPerRestart-results.NumObjectiveEvaluations;
            assert(remaining>=0,'Checkpoint exceeds the intended budget.');
            rng(saved.optimizerRng);
            if remaining>0
                % Native resume counts ADDITIONAL, not total, evaluations.
                results=resume(results,'MaxObjectiveEvaluations',remaining);
            end
        else
            rng(o.optimizerSeeds(restart),'twister');
            results=bayesopt(@(T) bayes8_objective( ...
                bayes8_design('matrix',T),c,restart),vars, ...
                'NumSeedPoints',o.initialPoints, ...
                'MaxObjectiveEvaluations',o.evaluationsPerRestart, ...
                'XConstraintFcn',@(T) bayes8_design('feasible',T,o), ...
                'IsObjectiveDeterministic',true, ...
                'AcquisitionFunctionName','expected-improvement-plus', ...
                'UseParallel',false,'PlotFcn',{},'Verbose',1, ...
                'OutputFcn',@(R,state) bayes8_checkpoint(R,state,c,restart));
        end
        assert(results.NumObjectiveEvaluations==o.evaluationsPerRestart && ...
            ~any(results.ErrorTrace==1) && all(isfinite(results.ObjectiveTrace)), ...
            'Incomplete search or invalid objective. Check records before resuming.');
        bayes8_checkpoint(results,'done',c,restart);
        surrogate_accuracy_util('save',finished,struct( ...
            'evaluations',results.NumObjectiveEvaluations,'best_error',min(results.ObjectiveTrace)));
    end
    [~,S]=surrogate_accuracy_util('export',outDir);
    frozenFile=fullfile(outDir,'frozen_candidate.mat');
    if isfile(frozenFile)
        saved=load(frozenFile); winner=saved.winner; winnerId=saved.winnerId;
    else
        winner=bayes8_design('matrix',S(1,:)); winnerId=S.config_id(1);
        surrogate_accuracy_util('save',frozenFile,struct('winner',winner,'winnerId',winnerId));
    end
    surrogate_accuracy_util('table',S(1,:),fullfile(outDir,'selected_candidate.csv'));
    fprintf('\nCandidate frozen: %s. Measuring baseline only after selection.\n',winnerId);
    B=bayes8_batch(c,bx,o.screenSeeds,'baseline','post_search');
    E0=surrogate_accuracy_util('score',B);
    comparison=table(E0,S.median_absolute_error(1),S.median_absolute_error(1)<E0, ...
        'VariableNames',{'baseline_median_absolute_error','best_search_median_absolute_error', ...
        'search_beats_baseline'});
    surrogate_accuracy_util('table',comparison,fullfile(outDir,'search_baseline_comparison.csv'));
    [Q,B]=bayes8_batch(c,winner,o.confirmSeeds,'confirmation','frozen');
    [C,P]=bayes8_confirmation(B,Q,o); C.config_id=winnerId;
    surrogate_accuracy_util('table',C,fullfile(outDir,'confirmation_summary.csv'));
    surrogate_accuracy_util('table',P,fullfile(outDir,'paired_confirmation.csv'));
    [R,S]=surrogate_accuracy_util('export',outDir);
    status="pilot_only";
    if strcmp(o.mode,'full'), status="completed_no_optimality_certificate"; end
    if o.synthetic, status="synthetic_pipeline_only"; end
    decision=table(status,height(R),height(S),numel(unique(S.config_id)), ...
        sum(~R.valid_for_score),C.observed_error_improvement,C.bootstrap_supports_error_improvement, ...
        'VariableNames',{'status','saved_runs','configuration_batches','unique_configurations', ...
        'invalid_runs','observed_confirmation_improvement','bootstrap_supports_improvement'});
    surrogate_accuracy_util('table',decision,fullfile(outDir,'study_decision.csv'));
    surrogate_accuracy_util('save',fullfile(outDir,'study_finished.mat'),struct('decision',decision));
    disp(C);
    fprintf('Saved %d runs. Read search_configurations.csv and confirmation_summary.csv.\n',height(R));
catch ME
    surrogate_accuracy_util('export',outDir);
    failure=struct('identifier',ME.identifier,'message',ME.message,'stack',ME.stack);
    surrogate_accuracy_util('save',fullfile(outDir,'last_failure.mat'),struct('failure',failure));
    rethrow(ME)
end
end

function validate_options(o)
assert(o.version==1 && any(strcmp(o.mode,{'pilot','full','selftest'})));
assert(o.synthetic==strcmp(o.mode,'selftest'));
assert(strcmp(o.modelId,'genda_bistable_duffing'));
validateattributes(o.alpha,{'numeric'},{'scalar','real','finite','>=',.1,'<=',1});
validateattributes(o.useParallel,{'logical'},{'scalar'});
if ~isempty(o.numWorkers)
    validateattributes(o.numWorkers,{'numeric'},{'scalar','integer','positive','finite'});
end
for field={'screenSeeds','confirmSeeds','optimizerSeeds'}
    v=o.(field{1}); validateattributes(v,{'numeric'},{'row','integer','positive','finite','nonempty'});
    assert(numel(unique(v))==numel(v),'Duplicate seed IDs.');
end
assert(numel(o.optimizerSeeds)==2 && isempty(intersect(o.screenSeeds,o.confirmSeeds)));
assert(numel(o.confirmSeeds)>=3);
assert(~strcmp(o.mode,'full') || numel(o.confirmSeeds)==100, ...
    'Full confirmation requires 100 new seeds.');
assert(o.synthetic || numel(o.screenSeeds)==10,'This experiment uses ten search seeds.');
for field={'initialPoints','evaluationsPerRestart','bootstrapSamples','scheduleSeed','bootstrapSeed'}
    validateattributes(o.(field{1}),{'numeric'},{'scalar','integer','positive','finite'});
end
assert(o.evaluationsPerRestart>o.initialPoints && o.bootstrapSamples>=100);
assert(isequal(o.newcomerRatioBounds,[.2 .6]));
assert(isequal(size(o.lower),[1 8]) && isequal(size(o.upper),[1 8]));
assert(all(isfinite([o.lower o.upper])));
assert(all(o.lower(1:7)==fix(o.lower(1:7))) && all(o.upper(1:7)==fix(o.upper(1:7))));
assert(o.lower(7)>=1 && o.lower(8)>0);
assert(isequal(o.lower(1:6),[0 351 2 10 2 2]) && isequal(o.upper(1:6),[5 1051 10 20 12 5]));
assert(all(o.lower<o.upper));
end

function restore_session(p,f,r)
cd(f); path(p); rng(r);
end

function signature=source_signature(root,shared,adapter,support,batchSupport,native,model,referenceFunctions)
files=[dir(fullfile(root,'*.m'));dir(fullfile(shared,'bayes_A_design.m')); ...
    dir(fullfile(shared,'bayes_A_initialize_path.m'));dir(fullfile(adapter,'original_A_adapter.m')); ...
    dir(fullfile(support,'accuracy_first_activate.m'));dir(fullfile(batchSupport,'surrogate_accuracy_util.m')); ...
    dir(fullfile(referenceFunctions,'+limbench','reference.m')); ...
    dir(fullfile(referenceFunctions,'+limbench','private','reference_bistable_duffing.m')); ...
    dir(fullfile(native,'*.m'));dir(fullfile(model,'*.m'))];
names=string({files.name}); files=files(~startsWith(names,'test_') & ~startsWith(names,'selftest_'));
signature=strings(numel(files),2);
for j=1:numel(files)
    file=fullfile(files(j).folder,files(j).name); fid=fopen(file,'rb'); assert(fid>=0);
    bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    md=java.security.MessageDigest.getInstance('SHA-256'); md.update(typecast(bytes,'int8'));
    digest=typecast(md.digest(),'uint8');
    signature(j,:)=[string(file),string(lower(reshape(dec2hex(digest,2).',1,[])))];
end
signature=sortrows(signature,1);
end
