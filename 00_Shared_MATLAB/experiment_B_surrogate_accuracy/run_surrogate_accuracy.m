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
function outDir=run_surrogate_accuracy(o,resumeDir)
% Accuracy-only surrogateopt. Each restart has an empty InitialPoints option.
if nargin<1 || isempty(o), o=surrogate_accuracy_options('pilot'); end
if nargin<2, resumeDir=''; end
validate_options(o);
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
shared=fullfile(repo,'experiment_A_bayesian_optimization');
adapter=fullfile(repo,'experiment_A_top6_exhaustive');
support=fullfile(repo,'experiment_B_accuracy_first_bayes');
native=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
model=fullfile(repo,'work','DynIn','DynIn_v1.1.0','Unforced_Duffing_Oscillator');
oldPath=path; oldFolder=pwd; oldRng=rng;
cleanup=onCleanup(@() restore_session(oldPath,oldFolder,oldRng));
if ~isempty(resumeDir)
    [ok,info]=fileattrib(resumeDir);
    assert(ok && info.directory,'Resume folder not found.');
    resumeDir=info.Name;
end
cd(root); addpath(shared);
bayes_A_initialize_path(root,adapter,native,model);
addpath(support,'-begin');
accuracy_first_activate(root,shared,adapter,native,model);
assert(exist('surrogateopt','file')==2 && license('test','GADS_Toolbox'), ...
    'Global Optimization Toolbox is required.');
base=original_A_adapter('base'); bx=bayes_A_design('baseline',base);
signature=source_signature(root,shared,adapter,support,native,model);
definition=struct('options',o,'base',base,'signature',signature,'matlab_version',version);
if isempty(resumeDir)
    prefix=['outputs_surrogate_accuracy_' o.mode '_'];
    if o.synthetic, prefix='outputs_SYNTHETIC_surrogate_'; end
    outDir=fullfile(root,[prefix char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
    for name={'records','observations','trace','source_snapshot'}
        mkdir(fullfile(outDir,name{1}));
    end
    for j=1:size(signature,1)
        [~,name,ext]=fileparts(signature(j,1));
        copyfile(signature(j,1),fullfile(outDir,'source_snapshot',sprintf('%03d_%s',j,name+ext)));
    end
    surrogate_accuracy_util('save',fullfile(outDir,'study_definition.mat'),definition);
else
    outDir=resumeDir;
    old=load(fullfile(outDir,'study_definition.mat'));
    assert(isequaln(old,definition), ...
        'Options, MATLAB version, or source files changed. Start a new study.');
end
c=struct('root',root,'shared',shared,'adapter',adapter,'native',native, ...
    'model',model,'base',base,'bx',bx,'options',o,'outDir',outDir);
budget=numel(o.optimizerSeeds)*o.evaluationsPerRestart*numel(o.screenSeeds) ...
    +numel(o.screenSeeds)+2*numel(o.confirmSeeds);
fprintf('\nACCURACY-ONLY SURROGATEOPT: %s\n%s\n',o.mode,outDir);
fprintf('Empty InitialPoints; no time gate; no historical observations; no extra local search.\n');
fprintf('%d restarts x %d evaluations, %d common seeds, up to %d saved runs.\n', ...
    numel(o.optimizerSeeds),o.evaluationsPerRestart,numel(o.screenSeeds),budget);
fprintf('Objective: median abs(R_hat - %.4f), a published numerical reference.\n',base.reference_LIM);
if isfile(fullfile(outDir,'study_finished.mat'))
    surrogate_accuracy_util('export',outDir);
    fprintf('Already complete. No runs repeated.\n'); return
end
execution=accuracy_first_pool(o,c);
file=fullfile(outDir,'execution_settings.mat');
if isfile(file)
    a=load(file,'execution');
    assert(isequaln(a.execution,execution),'Execution environment changed; start a new study.');
else
    surrogate_accuracy_util('save',file,struct('execution',execution));
end
surrogate_accuracy_util('table',struct2table(execution),fullfile(outDir,'execution_settings.csv'));
try
    [A,b]=surrogate_accuracy_util('constraints');
    for restart=1:numel(o.optimizerSeeds)
        resultFile=fullfile(outDir,sprintf('restart_%02d_results.mat',restart));
        checkpoint=fullfile(outDir,sprintf('restart_%02d_checkpoint.mat',restart));
        if isfile(resultFile), continue; end
        if isfile(checkpoint)
            fprintf('Resuming native checkpoint for restart %d.\n',restart);
            [x,fval,exitflag,output,trials]=surrogateopt(checkpoint);
        else
            rng(o.optimizerSeeds(restart),'twister');
            settings=optimoptions('surrogateopt','Display','iter', ...
                'MaxFunctionEvaluations',o.evaluationsPerRestart, ...
                'MinSurrogatePoints',o.minSurrogatePoints, ...
                'UseParallel',false,'UseVectorized',false,'BatchUpdateInterval',1, ...
                'CheckpointFile',checkpoint,'PlotFcn',[], ...
                'OutputFcn',@(x,v,s) surrogate_accuracy_trace(x,v,s,c,restart));
            assert(isempty(settings.InitialPoints),'Warm-start inputs are prohibited.');
            [x,fval,exitflag,output,trials]=surrogateopt( ...
                @(x) surrogate_accuracy_objective(x,c,restart), ...
                o.lower,o.upper,1:6,A,b,[],[],settings);
        end
        assert(exitflag>=0 && isfinite(fval),'Search did not finish normally. Resume its checkpoint.');
        data=struct('x',x,'fval',fval,'exitflag',exitflag,'output',output,'trials',trials);
        surrogate_accuracy_util('save',resultFile,data);
        T=bayes_A_design('table',trials.X); T.objective=trials.Fval(:);
        surrogate_accuracy_util('table',T,fullfile(outDir,sprintf('restart_%02d_trials.csv',restart)));
    end
    [~,S]=surrogate_accuracy_util('export',outDir);
    assert(~isempty(S),'No configurations were evaluated.');
    frozenFile=fullfile(outDir,'frozen_candidate.mat');
    if isfile(frozenFile)
        a=load(frozenFile); winner=a.winner; winnerId=a.winnerId;
    else
        % S is sorted by error, then a deterministic ID, never by runtime.
        winner=bayes_A_design('matrix',S(1,:)); winnerId=S.config_id(1);
        surrogate_accuracy_util('save',frozenFile,struct('winner',winner,'winnerId',winnerId));
    end
    surrogate_accuracy_util('table',S(1,:),fullfile(outDir,'selected_candidate.csv'));
    fprintf('\nCandidate frozen: %s. Baseline is measured only now.\n',winnerId);
    B=surrogate_accuracy_batch(c,bx,o.screenSeeds,'baseline','post_search');
    E0=surrogate_accuracy_util('score',B);
    comparison=table(E0,S.median_absolute_error(1),S.median_absolute_error(1)<E0, ...
        'VariableNames',{'baseline_median_absolute_error','best_search_median_absolute_error', ...
        'search_beats_baseline'});
    surrogate_accuracy_util('table',comparison,fullfile(outDir,'search_baseline_comparison.csv'));
    [Q,B]=surrogate_accuracy_batch(c,winner,o.confirmSeeds,'confirmation','frozen');
    C=surrogate_accuracy_util('confirmation',B,Q,o); C.config_id=winnerId;
    surrogate_accuracy_util('table',C,fullfile(outDir,'confirmation_summary.csv'));
    [R,S]=surrogate_accuracy_util('export',outDir);
    status="pilot_only";
    if strcmp(o.mode,'full'), status="completed_no_optimality_certificate"; end
    if o.synthetic, status="synthetic_pipeline_test_not_scientific_data"; end
    decision=table(status,height(R),height(S),sum(~R.valid_for_score), ...
        C.observed_error_improvement,C.bootstrap_supports_error_improvement, ...
        'VariableNames',{'status','saved_runs','configuration_batches','invalid_runs', ...
        'observed_confirmation_improvement','bootstrap_supports_improvement'});
    surrogate_accuracy_util('table',decision,fullfile(outDir,'study_decision.csv'));
    surrogate_accuracy_util('save',fullfile(outDir,'study_finished.mat'),struct('decision',decision));
    fprintf('\nSaved %d runs; invalid runs=%d. Read search_configurations.csv and confirmation_summary.csv.\n', ...
        height(R),sum(~R.valid_for_score));
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
validateattributes(o.useParallel,{'logical'},{'scalar'});
if ~isempty(o.numWorkers)
    validateattributes(o.numWorkers,{'numeric'},{'scalar','integer','positive','finite'});
end
for field={'screenSeeds','confirmSeeds','optimizerSeeds'}
    v=o.(field{1});
    validateattributes(v,{'numeric'},{'row','integer','positive','finite','nonempty'});
    assert(numel(unique(v))==numel(v),'Repeated seed IDs.');
end
assert(numel(o.optimizerSeeds)==2 && numel(o.screenSeeds)>=3 && numel(o.confirmSeeds)>=3);
assert(isempty(intersect(o.screenSeeds,o.confirmSeeds)));
for field={'minSurrogatePoints','evaluationsPerRestart','bootstrapSamples','scheduleSeed','bootstrapSeed'}
    validateattributes(o.(field{1}),{'numeric'},{'scalar','positive','integer','finite'});
end
assert(o.minSurrogatePoints>=7 && o.evaluationsPerRestart>o.minSurrogatePoints);
assert(o.bootstrapSamples>=100 && isequal(o.newcomerRatioBounds,[.2 .6]));
assert(isequal(size(o.lower),[1 6]) && isequal(size(o.upper),[1 6]));
assert(all(isfinite([o.lower o.upper])) && all([o.lower o.upper]==fix([o.lower o.upper])));
assert(all(o.lower<o.upper));
end

function restore_session(p,f,r)
cd(f); path(p); rng(r);
end

function signature=source_signature(root,shared,adapter,support,native,model)
files=[dir(fullfile(root,'*.m'));dir(fullfile(shared,'bayes_A_design.m')); ...
    dir(fullfile(shared,'bayes_A_initialize_path.m'));dir(fullfile(adapter,'original_A_adapter.m')); ...
    dir(fullfile(support,'accuracy_first_activate.m'));dir(fullfile(support,'accuracy_first_pool.m')); ...
    dir(fullfile(support,'accuracy_first_worker_init.m')); ...
    dir(fullfile(native,'*.m'));dir(fullfile(model,'*.m'))];
names=string({files.name});
files=files(~startsWith(names,'test_') & ~startsWith(names,'selftest_'));
signature=strings(numel(files),2);
for j=1:numel(files)
    file=fullfile(files(j).folder,files(j).name);
    fid=fopen(file,'rb'); assert(fid>=0,'Cannot read %s',file);
    bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    md=java.security.MessageDigest.getInstance('SHA-256');
    md.update(typecast(bytes,'int8')); digest=typecast(md.digest(),'uint8');
    signature(j,:)=[string(file),string(lower(reshape(dec2hex(digest,2).',1,[])))];
end
signature=sortrows(signature,1);
end
