function out=ma_io(action,varargin)
out=[];
switch action
    case 'save'
        file=char(varargin{1}); data=varargin{2}; temp=[file '.tmp.mat'];
        save(temp,'-struct','data','-v7.3');
        [ok,msg]=movefile(temp,file,'f'); assert(ok,'%s',msg);
    case 'hash'
        md=java.security.MessageDigest.getInstance('SHA-256');
        md.update(typecast(uint8(varargin{1}(:)),'int8'));
        out=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
    case 'signature'
        root=varargin{1}; native=varargin{2};
        files=[dir(fullfile(root,'*.m'));dir(fullfile(root,'model','*.m'));dir(fullfile(native,'*.m'))];
        % Editing the launcher's resumeDirectory must not invalidate a resume.
        files=files(~startsWith(string({files.name}),'test_'));
        out=strings(numel(files),2);
        for j=1:numel(files)
            p=fullfile(files(j).folder,files(j).name);
            fid=fopen(p,'rb'); assert(fid>=0); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
            out(j,:)=[string(p),string(ma_io('hash',bytes))];
        end
        out=sortrows(out,1);
    otherwise
        error('Unknown IO action.');
end
end
