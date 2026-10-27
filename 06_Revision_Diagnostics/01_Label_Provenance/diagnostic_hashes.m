function T=diagnostic_hashes(root)
% AI-assisted code. SHA-256 audit of every original experiment file.
files=dir(fullfile(root,'**','*')); files=files(~[files.isdir]);
names=strings(numel(files),1); hashes=names; bytes=zeros(numel(files),1);
for k=1:numel(files)
    file=fullfile(files(k).folder,files(k).name);
    names(k)=string(file(numel(root)+2:end)); bytes(k)=files(k).bytes;
    fid=fopen(file,'rb'); assert(fid>=0,'Cannot read %s',file);
    closer=onCleanup(@() fclose(fid));
    md=java.security.MessageDigest.getInstance('SHA-256');
    while ~feof(fid)
        block=fread(fid,1024*1024,'*uint8');
        if ~isempty(block), md.update(typecast(block,'int8')); end
    end
    hashes(k)=lower(string(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])));
    clear closer;
end
T=sortrows(table(names,bytes,hashes,'VariableNames',{'relative_path','bytes','sha256'}),'relative_path');
end
