function verify_freeze()
% VERIFY_FREEZE Reject unnoticed edits to versioned package files before runs.
% Uses MATLAB's bundled JVM, not an additional toolbox. Outside run timers.
assert(usejava('jvm'),'limbench:NoJVM','Start MATLAB with its JVM to verify the frozen package.');
root=fileparts(fileparts(mfilename('fullpath')));
manifest=jsondecode(fileread(fullfile(root,'FREEZE_MANIFEST.json')));
for k=1:numel(manifest.package_files)
    entry=manifest.package_files(k);
    file=fullfile(root,entry.relative_path);
    fid=fopen(file,'rb');
    assert(fid>=0,'limbench:MissingFile','Missing frozen package file: %s',file);
    cleanup=onCleanup(@()fclose(fid));
    bytes=fread(fid,Inf,'*uint8');
    clear cleanup
    md=java.security.MessageDigest.getInstance('SHA-256');
    md.update(typecast(bytes(:),'int8'));
    hash=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
    assert(strcmpi(hash,entry.sha256),'limbench:FreezeChanged', ...
        'Frozen file changed: %s. Restore v1 or explicitly create a new version.',entry.relative_path);
end
end
