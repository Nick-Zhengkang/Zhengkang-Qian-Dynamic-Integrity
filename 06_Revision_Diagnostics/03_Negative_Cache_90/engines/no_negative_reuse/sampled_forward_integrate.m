function [xt,cells,kind,count,rhsCalls]=sampled_forward_integrate(d,g,z0,solver)
% One solver call. Only requested Ts samples can change a classification.
% The optional solver injection is for callback regression tests only.
if nargin<4, solver=@ode45; end
nSteps=round(d.tfinal/d.Ts);
assert(nSteps>=2 && abs(nSteps*d.Ts-d.tfinal)<1e-10*max(1,d.tfinal), ...
    'tfinal must be an integer multiple of Ts, with at least two intervals.');
times=(0:nSteps)*d.Ts; dim=numel(d.target);
xt=zeros(nSteps+1,dim); cells=zeros(nSteps+1,1);
count=1; kind=0; rhsCalls=0; xt(1,:)=reshape(z0,1,[]);
coordinates=zeros(1,dim);
for j=1:dim
    index=find(g.cell_pos(:,j)>=z0(j)-g.dh(j)/2 & ...
        g.cell_pos(:,j)<=z0(j)+g.dh(j)/2,1);
    assert(~isempty(index),'Initial state has no native grid cell.');
    coordinates(j)=index;
end
cells(1)=find_index(coordinates,dim,d.discr);
% Preserve the effective MaxStep of native ode45 on each [0,Ts] segment.
% Do not quietly relax this parameter while changing the restart policy.
options=odeset('RelTol',d.RelTol,'AbsTol',d.AbsTol,'MaxStep',.1*d.Ts, ...
    'OutputFcn',@observe,'Refine',1);
[~,~]=solver(@rhs,times,z0(:),options);
assert(kind~=0 || count==nSteps+1, ...
    'ODE stopped before the horizon without a sampled classification. No labels were learned.');
xt=xt(1:count,:); cells=cells(1:count);

    function dz=rhs(t,z)
        rhsCalls=rhsCalls+1;
        dz=sistema(t,z,d.par);
    end
    function stop=observe(t,y,flag)
        stop=false;
        if ~isempty(flag), return; end
        for k=1:numel(t)
            if kind~=0, stop=true; return; end
            index=round(t(k)/d.Ts);
            tolerance=64*eps(max(1,d.tfinal));
            assert(abs(t(k)-index*d.Ts)<=tolerance, ...
                'OutputFcn supplied a point off the configured sampling grid.');
            if index<count, continue; end % Initial or repeated output sample.
            assert(index==count && count<=nSteps,'Missing or out-of-order sample.');
            z=y(:,k).';
            assert(all(isfinite(z)),'Nonfinite sampled trajectory.');
            [nextKind,cellId]=sampled_forward_step(z,g,d,cells(1:count));
            count=count+1; xt(count,:)=z; cells(count)=cellId; kind=nextKind;
            if kind~=0
                % Do not classify or propagate later samples in this batch.
                stop=true; return
            end
        end
    end
end
