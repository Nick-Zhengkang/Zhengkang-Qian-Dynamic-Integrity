function out=run_allcache4d(root,o)
% AI-assisted independent orchestration. No automatic parameter adjustment.
assert(all(ismember(o.seeds,1:30)) && numel(unique(o.seeds))==numel(o.seeds));
validateattributes(o.numWorkers,{'numeric'},{'scalar','integer','positive'});
assert(license('test','Distrib_Computing_Toolbox'),'Parallel Computing Toolbox required.');
before=allcache4d_verify(root);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
out=fullfile(root,'results',stamp);
assert(~isfolder(out),'Refusing to overwrite completed output.'); mkdir(out);
diary(fullfile(out,'run_log.txt')); logguard=onCleanup(@() diary('off')); %#ok<NASGU>
environment=struct('matlab_version',version,'release',version('-release'), ...
    'computer',computer,'toolboxes',ver,'timestamp',stamp);
save(fullfile(out,'environment.mat'),'environment','o');
writetable(before,fullfile(out,'input_hashes_before.csv'));
snap=fullfile(out,'source_snapshot'); mkdir(snap);
files=dir(fullfile(root,'*.m'));
for k=1:numel(files), copyfile(fullfile(root,files(k).name),snap); end
for name=["engine","native","model"]
    copyfile(fullfile(root,name),fullfile(snap,name));
end
copyfile(fullfile(root,'package_manifest.csv'),out);
copyfile(fullfile(root,'README.txt'),out);
oldpath=path; pathguard=onCleanup(@() path(oldpath)); %#ok<NASGU>
addpath(root,fullfile(root,'engine'),fullfile(root,'native'),fullfile(root,'model'),'-begin');
test_allcache4d(root);
pool=gcp('nocreate');
if isempty(pool), pool=parpool('Processes',o.numWorkers); end
assert(~isa(pool,'parallel.ThreadPool'),'A process pool is required.');
workers=min(o.numWorkers,pool.NumWorkers);
fprintf('30-seed package: %d selected seeds, %d workers.\n',numel(o.seeds),workers);
fprintf('Each seed: previous no-negative-cache control -> no learned cache -> independent checks.\n');
results=cell(numel(o.seeds),1);
parfor (i=1:numel(o.seeds),workers)
    results{i}=allcache4d_case(root,out,o.seeds(i),o);
end
summary=struct2table(vertcat(results{:}));
writetable(summary,fullfile(out,'case_summary.csv'));
after=allcache4d_verify(root);
writetable(after,fullfile(out,'input_hashes_after.csv'));
assert(isequal(before,after),'Package inputs or source changed during execution.');
fid=fopen(fullfile(out,'SUMMARY.txt'),'w'); assert(fid>=0);
guard=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'Selected seeds: %d\n',height(summary));
fprintf(fid,'Previous no-negative-cache searches reproduced: %d\n',sum(summary.control_matches));
fprintf(fid,'Repair searches completed without harness error: %d\n',sum(summary.repair_completed));
fprintf(fid,'Corrected finite midpoint estimates: %d\n',sum(isfinite(summary.repaired_midpoint)));
fprintf(fid,'Corrected midpoints below reference: %d\n',sum(summary.midpoint_below_reference));
fprintf(fid,'Corrected upper endpoints below reference: %d\n',sum(summary.upper_below_reference));
fprintf(fid,'Independent upper non-target support: %d\n',sum(summary.upper_validation=="both_solvers_support_non_target"));
fprintf(fid,'Independent lower target support: %d\n',sum(summary.lower_validation=="both_solvers_support_target"));
fprintf(fid,'Previous lower-point labels agreeing with independent checks: %d\n',sum(summary.previous_lower_agrees));
fprintf(fid,'Runs with learned target cache hits: %d\n',sum(summary.learned_target_cache_hits>0));
fprintf(fid,'Runs with negative cache hits: %d\n',sum(summary.negative_cache_hits>0));
fprintf(fid,'Corrected provenance replays matched: %d\n',sum(summary.provenance_matches));
fprintf(fid,'Runs passing the defined endpoint checks: %d\n',sum(summary.endpoint_checks_pass));
fprintf(fid,'Searches with unresolved classifications: %d\n',sum(summary.unresolved_count>0));
fprintf(fid,'Cases with an execution error: %d\n',sum(strlength(summary.error_message)>0));
fprintf(fid,'Counts are not proof of global classifier correctness or nearest-boundary accuracy.\n');
fprintf('Previous controls matched: %d/%d. Endpoint checks passed: %d/%d.\n', ...
    sum(summary.control_matches),height(summary),sum(summary.endpoint_checks_pass),height(summary));
fprintf('Results saved in:\n%s\n',out);
end

