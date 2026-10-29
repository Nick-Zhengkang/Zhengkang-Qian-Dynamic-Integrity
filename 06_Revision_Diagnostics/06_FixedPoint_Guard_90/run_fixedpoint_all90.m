function out=run_fixedpoint_all90(o)
% AI-assisted independent retest, not an edit to the published experiment.
root=fileparts(mfilename('fullpath')); oldPath=path; oldRng=rng; oldDir=pwd;
restore=onCleanup(@() restore_state(oldPath,oldRng,oldDir)); %#ok<NASGU>
% MATLAB gives the current folder priority over addpath entries.
cd(root); addpath(root,'-begin');
assert(license('test','Distrib_Computing_Toolbox'), ...
    'Parallel Computing Toolbox is required.');
assert(isfolder(o.previousResults),'Previous 90-case results folder is missing.');
expected=fullfile(fileparts(root),'03_Negative_Cache_90', ...
    'results','20261028_040701_540');
assert(strcmpi(canonical(o.previousResults),canonical(expected)), ...
    'Inputs must be the audited previous run, not a different result directory.');
assert(strcmpi(canonical(o.outputRoot),canonical(fullfile(root,'results'))), ...
    'Write outputs only under this independent package/results.');
out=fullfile(o.outputRoot,datestr(now,'yyyymmdd_HHMMSS_FFF'));
assert(~isfolder(out)); mkdir(out);
diary(fullfile(out,'run.log')); logGuard=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Read-only prior results: %s\nNew results: %s\n',o.previousResults,out);
verify_guard_inputs(root,out,"before");
integrity=onCleanup(@() final_integrity(root,out)); %#ok<NASGU>
snapshot=fullfile(out,'source_snapshot'); mkdir(snapshot);
for folder=["engines","shared","models","input"]
    copyfile(fullfile(root,folder),fullfile(snapshot,folder));
end
copyfile(fullfile(root,'*.m'),snapshot);
copyfile(fullfile(root,'README.md'),snapshot);
copyfile(fullfile(root,'RECORDED_RUN_README.txt'),snapshot);
environment=struct('matlab_version',version,'release',version('-release'), ...
    'toolboxes',ver,'options',o,'computer',computer);
save(fullfile(out,'environment.mat'),'environment');
run_guard_preflight(root,o,out);
pool=gcp('nocreate');
if isempty(pool), pool=parpool('Processes',o.numWorkers); end
assert(isa(pool,'parallel.ProcessPool') && isa(pool.Cluster,'parallel.cluster.Local'), ...
    'Use a local process pool, not threads or a remote cluster.');
ids=[repmat("quadratic_cubic",30,1);repmat("bistable_duffing",30,1); ...
    repmat("genda_cosine_quadratic_drag",30,1)];
seeds=repmat((1:30).',3,1);
writetable(table(ids,seeds),fullfile(out,'selected_cases.csv'));
fprintf('90 paired tasks, %d workers: old no-negative-cache control + repair.\n',pool.NumWorkers);
fprintf('Search settings and wall-time guards are unchanged; guard hits are flagged.\n');
queue=parallel.pool.DataQueue;
listener=afterEach(queue,@(s) fprintf('%s\n',s)); %#ok<NASGU>
results=cell(90,1);
parfor k=1:90
    results{k}=run_fixedpoint_case(root,o,out,ids(k),seeds(k),queue);
end
save(fullfile(out,'all_case_results.mat'),'results');
collect_fixedpoint_results(out);
verify_guard_inputs(root,out,"after");
fprintf('Finished. Read summary_by_model.csv and per_case_summary.csv.\n');
end
function final_integrity(root,out)
try
    verify_guard_inputs(root,out,"after");
catch ME
    warning('Input integrity audit failed: %s',ME.message);
end
end
function p=canonical(p)
p=char(java.io.File(p).getCanonicalPath());
end
function restore_state(p,r,folder)
path(p); rng(r); cd(folder);
end
