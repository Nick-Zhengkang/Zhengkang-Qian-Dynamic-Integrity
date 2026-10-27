function outDir=run_multi_alpha_bayes(o,resumeDir)
if nargin<1, o=ma_options('pilot'); end
if nargin<2, resumeDir=''; end
validate_options(o);
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
native=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
assert(isfile(fullfile(native,'compute_LIM_FP.m')));
oldPath=path; oldFolder=pwd; oldRng=rng;
cleanup=onCleanup(@() restore(oldPath,oldFolder,oldRng));
cd(root); addpath(root,'-begin');
assert(exist('bayesopt','file')==2 && license('test','Statistics_Toolbox'), ...
    'Statistics and Machine Learning Toolbox is required.');
signature=ma_io('signature',root,native);
definition=struct('options',o,'signature',signature,'matlab_version',version);
if isempty(resumeDir)
    outDir=fullfile(root,['outputs_multi_alpha_' o.mode '_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    assert(~isfolder(outDir)); mkdir(outDir);
    for folder={'records','observations','source_snapshot'}, mkdir(fullfile(outDir,folder{1})); end
    ma_io('save',fullfile(outDir,'definition.mat'),definition);
    copyfile(fullfile(root,'*.m'),fullfile(outDir,'source_snapshot'));
    copyfile(fullfile(root,'model'),fullfile(outDir,'source_snapshot','model'));
    copyfile(native,fullfile(outDir,'source_snapshot','native'));
    copyfile(fullfile(root,'README.md'),fullfile(outDir,'source_snapshot'));
else
    [ok,attr]=fileattrib(resumeDir); assert(ok && attr.directory,'Resume folder not found.');
    outDir=attr.Name; saved=load(fullfile(outDir,'definition.mat'));
    assert(isequaln(saved,definition),'Options, code or MATLAB version changed; start a new study.');
end
if isfile(fullfile(outDir,'study_finished.mat'))
    fprintf('Study already complete: %s\n',outDir); return
end
target=[0 0]; if strcmp(o.model,'bistable_duffing'), target=[-1 0]; end
c=struct('options',o,'root',root,'native',native,'modelDir',fullfile(root,'model'), ...
    'outDir',outDir,'bx',ma_design('baseline'),'target',target);
refFile=fullfile(outDir,'references.mat');
if isfile(refFile)
    saved=load(refFile); c.trainRef=saved.trainRef; c.validationRef=saved.validationRef;
else
    c.trainRef=zeros(size(o.trainAlpha)); c.validationRef=zeros(size(o.validationAlpha));
    audits=cell(numel(o.trainAlpha)+numel(o.validationAlpha),1); k=0;
    for j=1:numel(o.trainAlpha)
        [c.trainRef(j),A]=ma_reference(o.model,o.trainAlpha(j)); k=k+1;
        A.split=repmat("train",height(A),1); audits{k}=A;
    end
    for j=1:numel(o.validationAlpha)
        [c.validationRef(j),A]=ma_reference(o.model,o.validationAlpha(j)); k=k+1;
        A.split=repmat("validation",height(A),1); audits{k}=A;
    end
    audit=vertcat(audits{:});
    writetable(audit,fullfile(outDir,'reference_audit.csv'));
    ma_io('save',refFile,struct('trainRef',c.trainRef,'validationRef',c.validationRef,'audit',audit));
end
split=[repmat("train",numel(o.trainAlpha),1);repmat("validation",numel(o.validationAlpha),1)];
alphas=[o.trainAlpha';o.validationAlpha']; references=[c.trainRef';c.validationRef'];
writetable(table(split,alphas,references),fullfile(outDir,'reference_by_alpha.csv'));
baseline=ma_design('config',c.bx,o.model);
writetable(struct2table(baseline),fullfile(outDir,'transferred_baseline.csv'));
ma_io('save',fullfile(outDir,'context.mat'),struct('context',c));
ntrain=numel(o.trainAlpha)*numel(o.trainSeeds); nval=numel(o.validationAlpha)*numel(o.validationSeeds);
budget=2*o.evaluationsPerRestart*ntrain+ntrain+2*nval;
fprintf('\nMULTI-ALPHA %s, model %s\n%s\n',upper(o.mode),o.model,outDir);
fprintf('Training: %d alpha values x %d seeds, %d runs per configuration.\n', ...
    numel(o.trainAlpha),numel(o.trainSeeds),ntrain);
fprintf('2 x %d BO evaluations, %d initial random points per restart.\n',o.evaluationsPerRestart,o.initialPoints);
fprintf('Validation: %d unseen alphas x %d new seeds x 2 profiles.\n',numel(o.validationAlpha),numel(o.validationSeeds));
fprintf('At most %d saved solver runs, excluding warm-ups; repeated configurations use cached runs.\n',budget);
fprintf('Objective: pooled median absolute error across all training alpha/seed pairs; no time gate.\n');
execution=start_pool(o);
executionFile=fullfile(outDir,'execution.mat');
if isfile(executionFile)
    previous=load(executionFile);
    assert(isequaln(previous.execution,execution),'Pool size or execution settings changed.');
else
    ma_io('save',executionFile,struct('execution',execution));
end
writetable(struct2table(execution),fullfile(outDir,'execution_settings.csv'));
try
    names=ma_design('names'); vars=optimizableVariable(names{1},[o.lower(1) o.upper(1)],'Type','integer');
    for j=2:8
        kind='integer'; if j==8, kind='real'; end
        vars(j)=optimizableVariable(names{j},[o.lower(j) o.upper(j)],'Type',kind);
    end
    allTrace=table();
    for restart=1:2
        completeFile=fullfile(outDir,sprintf('restart_%d_complete.mat',restart));
        checkpoint=fullfile(outDir,sprintf('restart_%d_checkpoint.mat',restart));
        if isfile(completeFile)
            saved=load(completeFile); results=saved.BayesoptResults;
        elseif isfile(checkpoint)
            saved=load(checkpoint); results=saved.BayesoptResults;
            assert(~any(results.ErrorTrace==1),'Failed objective in checkpoint. Inspect failure records; start a corrected study.');
            remaining=o.evaluationsPerRestart-results.NumObjectiveEvaluations;
            assert(remaining>=0); rng(saved.optimizerRng);
            if remaining>0, results=resume(results,'MaxObjectiveEvaluations',remaining); end
        else
            rng(o.optimizerSeeds(restart),'twister');
            results=bayesopt(@(T) ma_objective(T,c),vars, ...
                'NumSeedPoints',o.initialPoints,'MaxObjectiveEvaluations',o.evaluationsPerRestart, ...
                'XConstraintFcn',@(T) ma_design('feasible',T,o), ...
                'IsObjectiveDeterministic',true,'AcquisitionFunctionName','expected-improvement-plus', ...
                'UseParallel',false,'PlotFcn',{},'Verbose',1, ...
                'OutputFcn',@(R,state) ma_checkpoint(R,state,c,restart));
        end
        assert(results.NumObjectiveEvaluations==o.evaluationsPerRestart ...
            && ~any(results.ErrorTrace==1) && all(isfinite(results.ObjectiveTrace)), ...
            'Incomplete or failed BO search; no candidate will be validated.');
        ma_checkpoint(results,'done',c,restart);
        ma_io('save',completeFile,struct('BayesoptResults',results));
        trace=results.XTrace; trace.objective=results.ObjectiveTrace;
        trace.restart=repmat(restart,height(trace),1); trace.evaluation=(1:height(trace))';
        if isempty(allTrace), allTrace=trace; else, allTrace=[allTrace;trace]; end %#ok<AGROW>
    end
    allTrace=sortrows(allTrace,{'objective','restart','evaluation'});
    writetable(allTrace,fullfile(outDir,'search_configurations.csv'));
    best=ma_design('matrix',allTrace(1,:)); frozenFile=fullfile(outDir,'frozen_candidate.mat');
    if isfile(frozenFile)
        saved=load(frozenFile); assert(isequal(best,saved.winner)); winner=saved.winner;
    else
        winner=best;
        ma_io('save',frozenFile,struct('winner',winner,'trainingObjective',allTrace.objective(1), ...
            'selectedBeforeValidation',true,'frozenAt',string(datetime('now'))));
    end
    writetable(struct2table(ma_design('config',winner,o.model)),fullfile(outDir,'frozen_candidate_parameters.csv'));
    fprintf('\nCandidate frozen using training only. Starting baseline and held-out comparisons.\n');
    BT=ma_batch(c,c.bx,'baseline_train'); QT=ma_batch(c,winner,'train');
    training=[BT;QT]; writetable(training,fullfile(outDir,'training_selected_raw.csv'));
    [TC,~]=ma_report('compare',training);
    writetable(TC,fullfile(outDir,'training_comparison.csv'));
    V=ma_batch(c,winner,'validation');
    writetable(V,fullfile(outDir,'validation_raw.csv'));
    profiles=ma_report('profile',V); [C,P]=ma_report('compare',V);
    writetable(profiles,fullfile(outDir,'validation_by_alpha_and_profile.csv'));
    writetable(C(2:end,:),fullfile(outDir,'validation_comparison_by_alpha.csv'));
    overall=C(1,:); overall.alpha=[];
    overall.n_alpha=numel(o.validationAlpha); overall.seeds_per_alpha=numel(o.validationSeeds);
    overall.alphas_improved=sum(C.candidate_has_lower_median(2:end));
    overall.worst_alpha_candidate_median=max(C.candidate_median_absolute_error(2:end));
    overall.worst_alpha_baseline_median=max(C.baseline_median_absolute_error(2:end));
    overall.mode=string(o.mode);
    writetable(overall,fullfile(outDir,'validation_overall.csv'));
    writetable(P,fullfile(outDir,'validation_paired.csv'));
    ma_io('save',fullfile(outDir,'study_finished.mat'),struct('overall',overall,'completedAt',string(datetime('now'))));
    disp(overall);
    fprintf('Finished. Read validation_overall.csv and validation_comparison_by_alpha.csv.\n');
catch ME
    ma_io('save',fullfile(outDir,'last_failure.mat'), ...
        struct('identifier',ME.identifier,'message',ME.message,'stack',ME.stack));
    rethrow(ME)
end
end

function validate_options(o)
assert(o.version==1 && any(strcmp(o.mode,{'pilot','full'})));
assert(any(strcmp(o.model,{'quadratic_cubic','bistable_duffing'})));
for key={'trainAlpha','validationAlpha'}
    x=o.(key{1}); validateattributes(x,{'numeric'},{'row','finite','>=',.05,'<=',2,'nonempty'});
    assert(numel(unique(x))==numel(x));
end
assert(all(abs(o.trainAlpha(:)-o.validationAlpha(:)')>1e-10,'all'),'Alpha sets overlap.');
for key={'trainSeeds','validationSeeds','optimizerSeeds'}
    x=o.(key{1}); validateattributes(x,{'numeric'},{'row','integer','positive','finite','nonempty'});
    assert(numel(unique(x))==numel(x));
end
assert(isempty(intersect(o.trainSeeds,o.validationSeeds)) && numel(o.optimizerSeeds)==2);
assert(o.evaluationsPerRestart>o.initialPoints && o.initialPoints>=2);
validateattributes(o.evaluationsPerRestart,{'numeric'},{'scalar','integer','positive'});
validateattributes(o.initialPoints,{'numeric'},{'scalar','integer','positive'});
validateattributes(o.useParallel,{'logical'},{'scalar'});
assert(isequal(o.lower,[0 351 2 10 2 2 50 .025]) && isequal(o.upper,[5 1051 10 20 12 5 200 .10]));
assert(ma_design('feasible',ma_design('baseline'),o));
if strcmp(o.mode,'full')
    assert(numel(o.trainSeeds)==10 && numel(o.validationSeeds)==100 ...
        && o.evaluationsPerRestart==200 && o.initialPoints==16);
end
end

function execution=start_pool(o)
execution=struct('parallel',o.useParallel,'workers',1,'threads_per_worker',1, ...
    'host',string(getenv('COMPUTERNAME')));
if o.useParallel
    assert(license('test','Distrib_Computing_Toolbox'));
    pool=gcp('nocreate');
    if isempty(pool)
        cluster=parcluster('Processes'); cluster.NumThreads=1; n=cluster.NumWorkers;
        if ~isempty(o.numWorkers), n=o.numWorkers; end
        validateattributes(n,{'numeric'},{'scalar','integer','positive','<=',cluster.NumWorkers});
        pool=parpool(cluster,n);
    else
        assert(isa(pool,'parallel.ProcessPool') && isa(pool.Cluster,'parallel.cluster.Local'), ...
            'Use a local process pool, not Threads or a remote cluster.');
        if ~isempty(o.numWorkers), assert(pool.NumWorkers==o.numWorkers); end
    end
    execution.workers=pool.NumWorkers;
end
end

function restore(p,f,r)
path(p); cd(f); rng(r);
end
