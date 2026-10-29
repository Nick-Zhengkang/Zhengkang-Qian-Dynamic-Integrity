function T=verify_guard_inputs(root,out,stage)
% AI-assisted SHA-256 audit. JSON avoids CSV header/type inference.
M=jsondecode(fileread(fullfile(root,'input','portable_source_manifest.json')));
for k=1:numel(M), M(k).path=fullfile(root,M(k).path); end
I=jsondecode(fileread(fullfile(root,'input','immutable_manifest.json')));
for k=1:numel(I), I(k).path=fullfile(root,I(k).path); end
M=[M;I];
paths=string({M.path}).'; expected=string({M.sha256}).'; actual=strings(numel(M),1);
bytes=zeros(numel(M),1); matched=false(numel(M),1);
for k=1:numel(M)
    f=dir(paths(k)); assert(isscalar(f),'Missing protected input: %s',paths(k));
    bytes(k)=f.bytes; actual(k)=sha256(paths(k));
    matched(k)=bytes(k)==M(k).bytes && actual(k)==expected(k);
end
T=table(paths,bytes,expected,actual,matched);
writetable(T,fullfile(out,char("input_integrity_"+stage+".csv")));
assert(all(matched),'Protected source/data hashes differ; do not interpret the retest.');
end
function hash=sha256(file)
fid=fopen(file,'rb'); assert(fid>=0); guard=onCleanup(@() fclose(fid)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    b=fread(fid,1024*1024,'*uint8'); md.update(typecast(b,'int8'));
end
h=typecast(md.digest(),'uint8'); hash=string(lower(reshape(dec2hex(h,2).',1,[])));
end
