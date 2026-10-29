function run_separable4d_diagnostic(root,o)
% AI-assisted independent diagnostic orchestration. No parameter tuning.
assert(all(ismember(o.seeds,1:30)) && numel(unique(o.seeds))==numel(o.seeds));
before=verify_inputs(root);
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
out=fullfile(root,'results',stamp);
assert(~isfolder(out),'Refusing to overwrite an existing diagnostic run.');
mkdir(out);
logfile=fullfile(out,'run_log.txt'); diary(logfile);
logguard=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Diagnostic output: %s\n',out);
environment=struct('matlab_version',version,'release',version('-release'), ...
    'computer',computer,'toolboxes',ver,'timestamp',stamp);
save(fullfile(out,'environment.mat'),'environment','o');
writetable(before,fullfile(out,'input_hashes_before.csv'));
copyfile(fullfile(root,'input_manifest.csv'),fullfile(out,'input_manifest.csv'));
snapshot=fullfile(out,'diagnostic_source_snapshot'); mkdir(snapshot);
files=dir(fullfile(root,'*.m'));
for k=1:numel(files), copyfile(fullfile(root,files(k).name),snapshot); end
copyfile(fullfile(root,'engine'),fullfile(snapshot,'engine'));
copyfile(fullfile(root,'native'),fullfile(snapshot,'native'));
copyfile(fullfile(root,'model'),fullfile(snapshot,'model'));
audit=read_separable4d_csv(fullfile(root,'static_audit','all30_endpoint_audit.csv'),'audit');
assert(height(audit)==30 && isequal(sort(audit.seed),(1:30)'), ...
    'The endpoint audit must contain each seed 1:30 exactly once.');
results=cell(numel(o.seeds),1);
if o.useParallel
    assert(license('test','Distrib_Computing_Toolbox'), ...
        'Parallel Computing Toolbox required. Set useParallel=false for serial execution.');
    pool=gcp('nocreate');
    if isempty(pool)
        pool=parpool('Processes',o.numWorkers);
    else
        assert(~isa(pool,'parallel.ThreadPool'),'Use a process pool, not a thread pool.');
    end
    workers=min(o.numWorkers,pool.NumWorkers);
    fprintf('Parallel replay: %d cases, up to %d process workers.\n',numel(o.seeds),workers);
    parfor (i=1:numel(o.seeds),workers)
        seed=o.seeds(i);
        results{i}=separable4d_case(root,out,seed,audit(audit.seed==seed,:),o);
    end
else
    for i=1:numel(o.seeds)
        seed=o.seeds(i);
        results{i}=separable4d_case(root,out,seed,audit(audit.seed==seed,:),o);
    end
end
summary=struct2table(vertcat(results{:}));
writetable(summary,fullfile(out,'case_summary.csv'));
after=verify_inputs(root);
writetable(after,fullfile(out,'input_hashes_after.csv'));
assert(isequal(before,after),'Frozen input hashes changed. Do not interpret results.');
fprintf('Input hashes unchanged. Matched replays: %d/%d.\n',sum(summary.replay_matches),height(summary));
fprintf('Results saved in:\n%s\n',out);
end

function T=verify_inputs(root)
T=read_separable4d_csv(fullfile(root,'input_manifest.csv'),'manifest');
for k=1:height(T)
    path=fullfile(root,char(T.relative_path(k)));
    fid=fopen(path,'rb'); assert(fid>=0,'Missing input: %s',path);
    guard=onCleanup(@() fclose(fid));
    md=java.security.MessageDigest.getInstance('SHA-256');
    while ~feof(fid)
        b=fread(fid,1024*1024,'*uint8');
        if ~isempty(b), md.update(typecast(b,'int8')); end
    end
    h=lower(string(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])));
    assert(h==T.sha256(k),'Frozen input changed: %s',path);
    clear guard;
end
end
