function ablation_step_selftest(d,mode)
% AI-assisted local unit tests; no ODE calls and no persistent classifier state.
g=sampled_forward_geometry(d);
z=[g.cell_pos(2,1),g.cell_pos(2,2)];
[kind,cid]=sampled_forward_step(z,g,d,[]);
assert(kind==0 && ~ismember(cid,g.cell_c),'Self-test point is not a neutral interior cell.');
base=mode=="baseline";
g.cell_d=cid;
kind=sampled_forward_step(z,g,d,[]);
assert(kind==2*base,'Non-target-cache read policy is wrong.');
g.cell_d=zeros(0,1); g.cell_dout=cid;
kind=sampled_forward_step(z,g,d,[]);
assert(kind==3*base,'Domain-exit-cache read policy is wrong.');
g.cell_d=cid;
kind=sampled_forward_step(z,g,d,[]);
assert(kind==3*base,'Negative-cache precedence is wrong.');
g.cell_c=[g.cell_c;cid];
kind=sampled_forward_step(z,g,d,[]);
assert(kind==1,'Target-cache priority changed.');
g=sampled_forward_geometry(d);
outside=z; outside(1)=d.domain(1);
kind=sampled_forward_step(outside,g,d,[]);
assert(kind==3,'Direct domain-exit classification changed.');
history=repmat(cid,double(d.repFixPoint)+2,1);
kind=sampled_forward_step(z,g,d,history);
assert(kind==4,'Fixed-point recurrence criterion changed.');
history=repmat([cid;cid+1],double(d.repPeriodic)+2,1);
kind=sampled_forward_step(z,g,d,history);
assert(kind==4,'Periodic recurrence criterion changed.');
fprintf('  Step tests PASS: %s; target/domain/recurrence rules preserved.\n',mode);
end
