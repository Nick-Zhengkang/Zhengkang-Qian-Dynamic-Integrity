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
function execution=bayes8_pool(o,context)
execution=struct('parallel',o.useParallel,'workers',1, ...
    'threads_per_worker',maxNumCompThreads,'host',string(getenv('COMPUTERNAME')));
if o.useParallel
    assert(license('test','Distrib_Computing_Toolbox'), ...
        'Parallel Computing Toolbox is required for parfor mode.');
    cluster=parcluster('Processes');
    wanted=cluster.NumWorkers;
    if ~isempty(o.numWorkers), wanted=o.numWorkers; end
    assert(wanted<=cluster.NumWorkers,'Requested workers exceed the local Processes profile limit.');
    pool=gcp('nocreate');
    if isempty(pool)
        cluster.NumThreads=1;
        pool=parpool(cluster,wanted);
    else
        assert(isa(pool,'parallel.ProcessPool') && isa(pool.Cluster,'parallel.cluster.Local'), ...
            'Use a local process pool, not Threads or a remote pool. Close the other pool first.');
        assert(pool.NumWorkers==wanted, ...
            'Existing pool has %d workers; requested %d. Close it or set options.numWorkers explicitly.', ...
            pool.NumWorkers,wanted);
    end
    % Initialize and warm every worker before any timed experiment.
    initialization=parfevalOnAll(pool,@bayes8_worker_init,0,context);
    fetchOutputs(initialization);
    execution.workers=pool.NumWorkers; execution.threads_per_worker=1;
    fprintf('PARFOR: %d process workers, one computational thread per worker.\n',pool.NumWorkers);
    fprintf('Active search tasks <= min(%d workers, %d seeds); no nested BO parallelism.\n', ...
        pool.NumWorkers,numel(o.screenSeeds));
else
    bayes8_worker_init(context);
    fprintf('SERIAL mode explicitly selected.\n');
end
end
