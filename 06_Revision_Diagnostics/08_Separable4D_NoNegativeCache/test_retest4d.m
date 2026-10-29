function test_retest4d(root)
% AI-assisted preflight: branch semantics, callback handling and saved inputs.
S=load(fullfile(root,'input','separable_qc_bd_4d_settings.mat'));
d=S.dynin; g=sampled_forward_geometry(d);
z=[.5,0,-1,0];
[kind,cid]=sampled_forward_step(z,g,d,zeros(0,1)); assert(kind==0);
h=g; h.cell_d=cid;
assert(sampled_forward_step(z,h,d,zeros(0,1))==2);
h.cell_dout=cid; assert(sampled_forward_step(z,h,d,zeros(0,1))==3);
h.cell_d=[]; h.cell_dout=[];
assert(sampled_forward_step(z,h,d,zeros(0,1))==0);
h.cell_c=[h.cell_c;cid];
assert(sampled_forward_step(z,h,d,zeros(0,1))==1);
outside=z; outside(1)=d.domain(5)+1;
assert(sampled_forward_step(outside,g,d,zeros(0,1))==3,'Direct exit must remain unchanged.');
assert(sampled_forward_step(z,g,d,repmat(cid,d.repFixPoint+1,1))==0);
assert(sampled_forward_step(z,g,d,repmat(cid,d.repFixPoint+2,1))==4);
periodic=repmat([cid;cid+1],d.repPeriodic+2,1);
assert(sampled_forward_step(z,g,d,periodic)==4,'Periodic rule must remain unchanged.');
short=d; short.tfinal=4*d.Ts;
[xt,~,kind,count]=sampled_forward_integrate(short,g,z,@batched);
assert(kind==1 && count==3 && isequal(xt(end,:),d.target));
[~,~,kind,count]=sampled_forward_integrate(short,g,z,@horizon);
assert(kind==0 && count==5,'Native unresolved horizon convention changed.');
failed=false;
try
    sampled_forward_integrate(short,g,z,@incomplete);
catch err
    failed=contains(err.message,'before the horizon');
end
assert(failed,'Incomplete solver return must not be accepted.');
files=dir(fullfile(root,'input','runs','*.mat')); assert(numel(files)==30);
for seed=1:30
    X=load(fullfile(root,'input','runs', ...
        sprintf('separable_qc_bd_4d__proposed_sampled_forward__seed_%d.mat',seed)));
    [e,P]=retest4d_endpoints(X.details,S.problem,seed,X.row.R_hat,X.row.R_reference);
    assert(height(P)==3 && e.upper_query>0 && e.lower_query>0);
    check=retest4d_compare(X.row,X.details,X);
    assert(all(check.matches),'Self-comparison of archived records failed.');
end
fprintf('Preflight passed: frozen rules, callback behavior and all 30 saved endpoint mappings.\n');
    function [t,y]=batched(~,span,~,opts)
        t=span(1:4); y=[z(:),z(:),d.target(:),outside(:)];
        assert(opts.OutputFcn(t,y,[]));
    end
    function [t,y]=horizon(~,span,~,opts)
        t=span; y=repmat(z(:),1,numel(span));
        assert(~opts.OutputFcn(t,y,[]));
    end
    function [t,y]=incomplete(~,span,~,opts)
        t=span(1:2); y=repmat(z(:),1,2); opts.OutputFcn(t,y,[]);
    end
end
