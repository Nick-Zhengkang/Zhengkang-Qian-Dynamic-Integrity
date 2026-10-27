% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Proposed-method implementation, comparison, or supporting model code.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
function sampled_forward_callback_tests(d,g)
% Synthetic callbacks exercise batches and native rule edge cases in 2D/4D.
dim=numel(d.target); z=d.target;
z(1)=.5*(d.target(1)+d.domain(dim+1));
outside=z; outside(1)=d.domain(dim+1)+1;
[kind,cid]=sampled_forward_step(z,g,d,zeros(0,1));
assert(kind==0,'Test probe unexpectedly belongs to a known cell.');
calls=0;
[xt,~,kind,count]=sampled_forward_integrate(d,g,z,@batched);
assert(calls==1 && kind==1 && count==3 && isequal(xt(end,:),d.target));
calls=0;
[~,~,kind,count]=sampled_forward_integrate(d,g,z,@exit_first);
assert(calls==1 && kind==3 && count==2);
calls=0;
[~,~,kind,count]=sampled_forward_integrate(d,g,z,@whole_horizon);
assert(calls==1 && kind==0 && count==round(d.tfinal/d.Ts)+1);
failed=false;
try
    sampled_forward_integrate(d,g,z,@incomplete);
catch ME
    failed=contains(ME.message,'before the horizon');
end
assert(failed,'Incomplete integration must not be converted into a horizon label.');

h=g; h.cell_c=cid; h.cell_d=cid; h.cell_dout=cid;
assert(sampled_forward_step(z,h,d,zeros(0,1))==1,'Target priority changed.');
h.cell_c=zeros(0,1);
assert(sampled_forward_step(z,h,d,zeros(0,1))==3,'Native exit-label priority changed.');
h.cell_dout=zeros(0,1);
assert(sampled_forward_step(z,h,d,zeros(0,1))==2);
h.cell_d=zeros(0,1);
assert(sampled_forward_step(z,h,d,repmat(cid,d.repFixPoint+1,1))==0);
assert(sampled_forward_step(z,h,d,repmat(cid,d.repFixPoint+2,1))==4);
other=cid+1;
history=repmat([cid;other],d.repPeriodic+1,1);
assert(sampled_forward_step(z,h,d,history)==0);
history=repmat([cid;other],d.repPeriodic+2,1);
assert(sampled_forward_step(z,h,d,history)==4);

% The continuous factory must propagate only the classified sampled prefix.
[~,expectedCells,nativeKind]=sampled_forward_integrate(d,g,z);
fresh=sampled_forward_classifier(d); [q,n]=fresh.classify(z);
assert(n==1 && q.native_tipo==nativeKind);
expectedCells=unique(expectedCells,'stable'); learned=expectedCells(1:end-1);
expected=g;
if nativeKind==1, expected.cell_c=[g.cell_c;learned];
elseif nativeKind==3, expected.cell_dout=[g.cell_dout;learned];
else, expected.cell_d=[g.cell_d;learned];
end
assert(isequal(fresh.state(),expected),'Continuous label propagation changed.');

    function [t,y]=batched(~,span,~,opts)
        calls=calls+1; cb=opts.OutputFcn;
        cb([span(1),span(end)],z(:),'init');
        t=span(1:4); y=[z(:),z(:),d.target(:),outside(:)];
        stop=cb(t,y,[]); assert(stop);
        cb([],[],'done');
    end
    function [t,y]=exit_first(~,span,~,opts)
        calls=calls+1;
        t=span(1:3); y=[z(:),outside(:),d.target(:)];
        stop=opts.OutputFcn(t,y,[]); assert(stop);
    end
    function [t,y]=whole_horizon(~,span,~,opts)
        calls=calls+1;
        t=span; y=repmat(z(:),1,numel(t));
        stop=opts.OutputFcn(t,y,[]); assert(~stop);
    end
    function [t,y]=incomplete(~,span,~,opts)
        t=span(1:2); y=repmat(z(:),1,2);
        opts.OutputFcn(t,y,[]);
    end
end
