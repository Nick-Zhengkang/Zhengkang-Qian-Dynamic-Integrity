function T=retest4d_verify(root)
% AI-assisted explicit CSV and SHA-256 integrity check, independent of pwd.
T=read_separable4d_csv(fullfile(root,'package_manifest.csv'),'manifest');
for k=1:height(T)
    file=fullfile(root,char(T.relative_path(k)));
    fid=fopen(file,'rb'); assert(fid>=0,'Missing file: %s',file);
    cleanup=onCleanup(@() fclose(fid));
    md=java.security.MessageDigest.getInstance('SHA-256');
    while ~feof(fid)
        bytes=fread(fid,1024*1024,'*uint8');
        if ~isempty(bytes), md.update(typecast(bytes,'int8')); end
    end
    hash=lower(string(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])));
    assert(hash==T.sha256(k),'Changed package file: %s',file);
    clear cleanup;
end
end

