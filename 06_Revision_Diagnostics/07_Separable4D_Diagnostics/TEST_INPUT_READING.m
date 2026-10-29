% AI-assisted short input test. No integration, parallel pool or output writes.
root=fileparts(mfilename('fullpath'));
addpath(root);
manifest=read_separable4d_csv(fullfile(root,'input_manifest.csv'),'manifest');
audit=read_separable4d_csv(fullfile(root,'static_audit','all30_endpoint_audit.csv'),'audit');
assert(height(manifest)==39 && width(manifest)==4);
assert(all(strlength(manifest.sha256)==64));
for k=1:height(manifest)
    assert(isfile(fullfile(root,manifest.relative_path(k))),'Missing frozen input.');
end
assert(height(audit)==30 && width(audit)==28);
assert(isequal(sort(audit.seed),(1:30)'));
assert(all(audit.lower<audit.upper));
assert(all(abs((audit.lower+audit.upper)/2-audit.midpoint)<1e-12));
assert(sum(audit.midpoint<audit.reference-1e-10)==24);
assert(sum(audit.upper<audit.reference-1e-10)==24);
assert(all(audit.upper_cache_kind==3));
fprintf('PASS: 39 input records and 30 endpoint rows imported with explicit schemas.\n');
