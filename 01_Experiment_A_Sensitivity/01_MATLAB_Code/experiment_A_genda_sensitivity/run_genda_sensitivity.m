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
function outDir = run_genda_sensitivity(o,resumeDir)
% New Experiment A: original DynIn, Genda Duffing, analytical-equation LIM.
if nargin<1 || isempty(o), o=genda_A_options('pilot'); end
if nargin<2, resumeDir=''; end
validate_options(o);
oldPath=path; oldFolder=pwd; oldRng=rng;
cleanup=onCleanup(@() restore_session(oldPath,oldFolder,oldRng));
if ~isempty(resumeDir)
    [ok,info]=fileattrib(resumeDir); assert(ok && info.directory,'Resume folder not found.');
    resumeDir=info.Name;
end
c=genda_A_setup(o);
D=genda_A_design(c.base,o.mode);
signature=source_signature(c);
definition=struct('options',o,'base',c.base,'design',D, ...
    'signature',signature,'matlab_version',version);
if isempty(resumeDir)
    outDir=fullfile(c.root,['outputs_genda_A_' o.mode '_' ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
    for name={'records','diagnostics','source_snapshot'}, mkdir(fullfile(outDir,name{1})); end
    surrogate_accuracy_util('save',fullfile(outDir,'study_definition.mat'),definition);
    for j=1:size(signature,1)
        [~,name,ext]=fileparts(signature(j,1));
        copyfile(signature(j,1),fullfile(outDir,'source_snapshot',sprintf('%03d_%s',j,name+ext)));
    end
    surrogate_accuracy_util('table',D,fullfile(outDir,'experiment_A_design.csv'));
    surrogate_accuracy_util('table',c.referenceAudit,fullfile(outDir,'analytical_reference_audit.csv'));
    surrogate_accuracy_util('save',fullfile(outDir,'analytical_reference.mat'), ...
        struct('reference',c.reference,'audit',c.referenceAudit));
    info=table(string(c.base.model),o.alpha,string(mat2str(c.base.xe)), ...
        string(mat2str(c.base.weight)),string(mat2str(c.base.spaceboundary)), ...
        c.base.reference_LIM,string(c.reference.kind),string(c.reference.published_source), ...
        'VariableNames',{'model','alpha','target','distance_weights','domain', ...
        'reference_LIM','reference_kind','reference_source'});
    surrogate_accuracy_util('table',info,fullfile(outDir,'model_definition.csv'));
else
    outDir=resumeDir;
    previous=load(fullfile(outDir,'study_definition.mat'));
    assert(isequaln(previous,definition), ...
        'gendaA:ResumeMismatch','Options, model, numerical sources or MATLAB version changed. Start a new study.');
end
c.outDir=outDir;
fprintf('\nGENDA EXPERIMENT A (%s): %d configurations x %d seeds = %d runs.\n%s\n', ...
    o.mode,height(D),numel(o.seedList),height(D)*numel(o.seedList),outDir);
fprintf('Reference LIM %.15f; quadratic damping alpha %.1f; Euclidean distance.\n',c.base.reference_LIM,o.alpha);
if isfile(fullfile(outDir,'study_finished.mat'))
    genda_A_export(outDir); fprintf('Already complete; exported saved records without rerunning.\n'); return
end
% Resume per diagnostic point as well as per native run.
c.diagnostic=genda_A_diagnostics(c);
execution=start_pool(c);
file=fullfile(outDir,'execution_settings.mat');
if isfile(file)
    prior=load(file,'execution');
    assert(isequaln(prior.execution,execution), ...
        'Worker count/host/settings changed. Start a new study for comparable timings.');
else
    surrogate_accuracy_util('save',file,struct('execution',execution));
end
surrogate_accuracy_util('table',struct2table(execution),fullfile(outDir,'execution_settings.csv'));
[ci,si]=ndgrid(1:height(D),1:numel(o.seedList));
stream=RandStream('mt19937ar','Seed',o.scheduleSeed);
order=randperm(stream,numel(ci)); ci=ci(order); si=si(order);
schedule=table((1:numel(ci)).',D.config_id(ci(:)),reshape(o.seedList(si),[],1), ...
    'VariableNames',{'execution_order','config_id','seed'});
surrogate_accuracy_util('table',schedule,fullfile(outDir,'execution_schedule.csv'));
present=false(height(schedule),1);
for j=1:height(schedule)
    key=schedule.config_id(j)+"__seed_"+schedule.seed(j)+".mat";
    present(j)=isfile(fullfile(outDir,'records',key));
end
todo=find(~present); batchSize=max(1,2*execution.workers);
fprintf('%d saved, %d remaining. Each completed run has its own checkpoint.\n',nnz(present),numel(todo));
try
    for first=1:batchSize:numel(todo)
        ix=todo(first:min(first+batchSize-1,numel(todo)));
        configs=cell(numel(ix),1); seeds=zeros(numel(ix),1); rows=cell(numel(ix),1);
        for j=1:numel(ix)
            configs{j}=table2struct(D(ci(ix(j)),:)); seeds(j)=schedule.seed(ix(j));
        end
        if o.useParallel
            parfor j=1:numel(ix)
                rows{j}=genda_A_job(c,configs{j},seeds(j),ix(j));
            end
        else
            for j=1:numel(ix), rows{j}=genda_A_job(c,configs{j},seeds(j),ix(j)); end
        end
        completed=vertcat(rows{:});
        assert(isequal([completed.seed].',seeds) && isequal([completed.execution_order].',ix(:)), ...
            'Completed jobs do not match the randomized schedule.');
        R=genda_A_export(outDir);
        fprintf('Saved %d/%d; native failures=%d; diagnostic failures=%d.\n', ...
            height(R),height(schedule),nnz(~R.success),nnz(R.success & ~R.diagnostic_success));
    end
catch ME
    genda_A_export(outDir);
    rethrow(ME)
end
R=genda_A_export(outDir);
assert(height(R)==height(schedule),'Missing records. Resume this directory.');
finished=struct('n_runs',height(R),'native_failures',nnz(~R.success), ...
    'diagnostic_failures',nnz(R.success & ~R.diagnostic_success), ...
    'finished_at',string(datetime('now')));
surrogate_accuracy_util('save',fullfile(outDir,'study_finished.mat'),finished);
fprintf('\nFinished. Read summary_by_parameter_and_level.csv and sensitivity_ranking.csv.\n%s\n',outDir);
end

function execution=start_pool(c)
o=c.options;
execution=struct('parallel',o.useParallel,'workers',1,'threads_per_worker',maxNumCompThreads, ...
    'host',string(getenv('COMPUTERNAME')));
if o.useParallel
    assert(license('test','Distrib_Computing_Toolbox'),'Parallel Computing Toolbox is required.');
    cluster=parcluster('Processes'); wanted=cluster.NumWorkers;
    if ~isempty(o.numWorkers), wanted=o.numWorkers; end
    assert(wanted<=cluster.NumWorkers,'Worker count exceeds the local Processes profile limit.');
    pool=gcp('nocreate');
    if isempty(pool)
        cluster.NumThreads=1; pool=parpool(cluster,wanted);
    else
        assert(isa(pool,'parallel.ProcessPool') && isa(pool.Cluster,'parallel.cluster.Local'), ...
            'Use a local Processes pool, not Threads or a remote pool.');
        assert(pool.NumWorkers==wanted,'Existing pool size differs. Close it or set numWorkers explicitly.');
    end
    initialization=parfevalOnAll(pool,@genda_A_worker,0,c);
    fetchOutputs(initialization);
    execution.workers=pool.NumWorkers; execution.threads_per_worker=1;
else
    genda_A_worker(c);
end
fprintf('Execution: %d workers; warm-up excluded from core timings.\n',execution.workers);
end

function validate_options(o)
validatestring(o.mode,{'pilot','full','smoke'});
assert(o.alpha==.7,'This study fixes alpha=0.7 to match Experiment B.');
validateattributes(o.seedList,{'numeric'},{'row','integer','positive','finite','nonempty','<',2^32-100000});
assert(numel(unique(o.seedList))==numel(o.seedList),'Duplicate seeds.');
validateattributes(o.useParallel,{'logical'},{'scalar'});
validateattributes(o.saveTrajectories,{'logical'},{'scalar'});
if ~isempty(o.numWorkers), validateattributes(o.numWorkers,{'numeric'},{'scalar','integer','positive'}); end
for field={'diagnosticAngles','scheduleSeed'}
    validateattributes(o.(field{1}),{'numeric'},{'scalar','integer','positive','finite'});
end
for field={'truthHorizon','truthTolerance','truthRelTol','truthAbsTol'}
    validateattributes(o.(field{1}),{'numeric'},{'scalar','positive','finite'});
end
validateattributes(o.radiusFactors,{'numeric'},{'row','positive','finite','nonempty'});
assert(~strcmp(o.mode,'full') || numel(o.seedList)==30, ...
    'gendaA:FullSeedCount','Full Experiment A uses 30 common seeds.');
end

function signature=source_signature(c)
files=[dir(fullfile(c.root,'*.m'));dir(fullfile(c.model,'*.m')); ...
    dir(fullfile(c.adapter,'original_A_adapter.m'));dir(fullfile(c.native,'*.m')); ...
    dir(fullfile(c.utility,'surrogate_accuracy_util.m')); ...
    dir(fullfile(c.referenceFunctions,'+limbench','reference.m')); ...
    dir(fullfile(c.referenceFunctions,'+limbench','private','reference_bistable_duffing.m'))];
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

function restore_session(p,f,r)
cd(f); path(p); rng(r);
end
