function out=run_all90_parfor(o)
% AI-assisted full 90-case ablation. Only independent runs are parallelized.
root=fileparts(mfilename('fullpath')); oldPath=path; oldDir=pwd; oldRng=rng;
restore=onCleanup(@() restore_environment(oldPath,oldDir,oldRng)); %#ok<NASGU>
cd(root); addpath(root);
assert(license('test','Distrib_Computing_Toolbox'), ...
    'Parallel Computing Toolbox is required for this parfor package.');
pool=gcp('nocreate');
if ~isempty(pool)
    assert(isa(pool,'parallel.ProcessPool'), ...
        'Use a local process pool, not a thread pool. See README.txt.');
    assert(isa(pool.Cluster,'parallel.cluster.Local'), ...
        'This package reads local files and requires a local process pool.');
end
data=char(java.io.File(o.dataDirectory).getCanonicalPath());
assert(isfolder(data),'Original experiment directory not found.');
out=fullfile(o.outputRoot,datestr(now,'yyyymmdd_HHMMSS_FFF'));
canonical=char(java.io.File(out).getCanonicalPath());
assert(~startsWith(lower([canonical filesep]),lower([data filesep])), ...
    'Output must not be inside the original experiment.');
assert(~isfolder(out),'Output already exists.'); mkdir(out);
diary(fullfile(out,'run.log')); diaryGuard=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Original data (read only): %s\nOutput: %s\n',data,out);
audit=diagnostic_hashes(data); writetable(audit,fullfile(out,'original_files_before.csv'));
integrity=onCleanup(@() check_integrity(data,audit,out)); %#ok<NASGU>
verify_ablation_sources(root,data,out);
mkdir(fullfile(out,'source_snapshot'));
for folder=["engines","shared","models"]
    copyfile(fullfile(root,char(folder)),fullfile(out,'source_snapshot',char(folder)));
end
copyfile(fullfile(root,'*.m'),fullfile(out,'source_snapshot'));
copyfile(fullfile(root,'README.txt'),fullfile(out,'source_snapshot'));
ids=[repmat("quadratic_cubic",30,1);repmat("bistable_duffing",30,1); ...
    repmat("genda_cosine_quadratic_drag",30,1)];
seeds=repmat((1:30).',3,1);
cases=table(ids,seeds,'VariableNames',{'model','seed'});
assert(height(unique(cases,'rows'))==90);
writetable(cases,fullfile(out,'selected_cases.csv'));
environment=struct('matlab_version',version,'options',o,'original_data',data);
save(fullfile(out,'environment.mat'),'environment');
if isempty(pool)
    if isempty(o.numWorkers), pool=parpool('Processes');
    else, pool=parpool('Processes',o.numWorkers); end
end
fprintf('Local process pool: %d workers. 90 independent model/seed cases.\n',pool.NumWorkers);
if o.runBaselineControl
    fprintf('Each task runs original control then ablation: 180 searches in total.\n');
end
queue=parallel.pool.DataQueue;
listener=afterEach(queue,@(message) fprintf('%s\n',message)); %#ok<NASGU>
n=height(cases);
parfor k=1:n
    % One worker owns this case's path, RNG, caches, logs and output folder.
    run_ablation_case(root,data,out,ids(k),seeds(k),o,queue);
end
collect_ablation_results(out);
fprintf('\nFinished. Inspect causal_summary.csv and case_status.csv.\n');
end

function check_integrity(data,before,out)
after=diagnostic_hashes(data); writetable(after,fullfile(out,'original_files_after.csv'));
same=isequal(before,after);
fid=fopen(fullfile(out,'ORIGINAL_DATA_INTEGRITY.txt'),'w');
fprintf(fid,'All original source/data bytes unchanged: %d\n',same); fclose(fid);
if ~same, warning('Original files changed during execution. Inspect before interpreting results.'); end
end
function restore_environment(p,d,r)
path(p); cd(d); rng(r);
end
