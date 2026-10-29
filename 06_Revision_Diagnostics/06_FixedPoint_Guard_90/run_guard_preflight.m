function run_guard_preflight(root,o,out)
% AI-assisted regression: restore the exact cache before the known failure.
folder=fullfile(out,'preflight'); mkdir(folder);
F=load(fullfile(root,'input','query567_native_trajectory.mat'));
d=F.d; d.modelDir=fullfile(root,'models','quadratic_cubic');
guard=activate_guard_engine(root,"fixed_point_guard",d); %#ok<NASGU>
unit_tests(d);
clear guard
guard=activate_guard_engine(root,"control",d); %#ok<NASGU>
[xOld,cOld,kOld,nOld,rhsOld]=sampled_forward_integrate(d,F.gBefore,F.expected.initial_state);
assert(kOld==F.kind && nOld==F.count && rhsOld==F.rhsCalls);
assert(isequal(cOld,F.cells) && max(abs(xOld-F.xt),[],'all')<1e-10);
clear guard
guard=activate_guard_engine(root,"fixed_point_guard",d); %#ok<NASGU>
[xNew,cNew,kNew,nNew,rhsNew,events]=sampled_forward_integrate(d,F.gBefore,F.expected.initial_state);
save(fullfile(folder,'query567_repaired_replay.mat'), ...
    'd','xOld','cOld','kOld','nOld','rhsOld','xNew','cNew','kNew','nNew','rhsNew','events','-v7.3');
assert(nNew>nOld,'The repaired replay did not continue beyond the old failure.');
assert(max(abs(xNew(1:nOld,:)-xOld),[],'all')<1e-10);
atOldTrigger=events(events(:,1)==nOld,:);
assert(size(atOldTrigger,1)==1 && atOldTrigger(6)==0, ...
    'The exact saved rep_fix_point false decision was not rejected.');
eventTable=array2table(events,'VariableNames', ...
    {'sample','time','x','v','cell_id','accepted','energy','barrier_margin'});
writetable(eventTable,fullfile(folder,'query567_fixed_point_events.csv'));
sample=(1:nNew).'; time=(sample-1)*d.Ts;
writetable(table(sample,time,xNew(:,1),xNew(:,2),cNew, ...
    'VariableNames',{'sample','time','x','v','cell_id'}), ...
    fullfile(folder,'query567_repaired_trajectory.csv'));
query=1; x0=F.expected.initial_state(1); v0=F.expected.initial_state(2);
Q=table(query,x0,v0,0,NaN,NaN,NaN,NaN,'VariableNames', ...
    {'query','x0','v0','parent_query','hit_x','hit_v','donor_x','donor_v'});
trace=struct('queries',Q,'winning_chain',1,'first_under_chain',[]);
validationDir=fullfile(folder,'independent_check'); mkdir(validationDir);
A=fpguard_validate_independent("quadratic_cubic",d,trace,struct('winning_query',1),validationDir,o);
newLabel="non_target"; if kNew==1, newLabel="target"; end
newReason="unchanged_other_rule";
if kNew==1, newReason="target_neighbourhood_or_target_cache";
elseif kNew==0, newReason="unchanged_horizon_forced_non_target";
elseif kNew==3, newReason="unchanged_direct_domain_exit";
elseif kNew==4 && ~isempty(events) && events(end,6)==1
    newReason="confirmed_fixed_point_non_target_well";
elseif kNew==4, newReason="unchanged_periodic_recurrence";
end
report=struct('old_kind',kOld,'old_samples',nOld,'old_trigger_rejected',true, ...
    'new_kind',kNew,'new_samples',nNew,'new_label',newLabel,'new_reason',newReason, ...
    'independent_outcome',A.conclusion(1), ...
    'query_now_correctly_target',newLabel=="target" && A.conclusion(1)=="both_solvers_support_target");
writetable(struct2table(report),fullfile(folder,'query567_regression_summary.csv'));
save(fullfile(folder,'preflight_result.mat'),'report','A');
fprintf('Preflight passed. Old trigger rejected; replay label=%s; independent=%s.\n', ...
    newLabel,A.conclusion(1));
if ~report.query_now_correctly_target
    warning('The fixed-point rejection worked, but another rule or unresolved validation remains.');
end
end

function unit_tests(d)
% Test the certificate without reference radii or tuned search parameters.
cases={"quadratic_cubic",[0,0],[1,0],false; ...
       "quadratic_cubic",[0,0],[0.997,-0.0023],false; ...
       "bistable_duffing",[-1,0],[1,0],true; ...
       "bistable_duffing",[-1,0],[-1,0],false; ...
       "bistable_duffing",[-1,0],[0,0],false; ...
       "bistable_duffing",[-1,0],[1,1],false; ...
       "genda_cosine_quadratic_drag",[0,0],[2*pi,0],true; ...
       "genda_cosine_quadratic_drag",[0,0],[0,0],false; ...
       "genda_cosine_quadratic_drag",[0,0],[pi,0],false; ...
       "genda_cosine_quadratic_drag",[0,0],[2*pi,3],false};
for k=1:size(cases,1)
    test=d; test.model_id=cases{k,1}; test.target=cases{k,2};
    assert(fixed_point_non_target_certificate(cases{k,3},test)==cases{k,4});
end
g=sampled_forward_geometry(d);
z=[g.cell_pos(2,1),g.cell_pos(2,2)];
[kind,cid]=sampled_forward_step(z,g,d,[]); assert(kind==0);
g.cell_d=cid; g.cell_dout=cid;
assert(sampled_forward_step(z,g,d,[])==0,'Negative cache reads must remain disabled.');
g.cell_c=[g.cell_c;cid];
assert(sampled_forward_step(z,g,d,[])==1,'Target cache priority changed.');
g=sampled_forward_geometry(d); outside=z; outside(1)=d.domain(1);
assert(sampled_forward_step(outside,g,d,[])==3);
history=repmat(cid,double(d.repFixPoint)+1,1);
[kind,~,fp]=sampled_forward_step(z,g,d,history);
assert(kind==0 && isempty(fp),'Fixed-point threshold changed.');
history(end+1)=cid;
[kind,~,fp]=sampled_forward_step(z,g,d,history);
assert(kind==0 && ~isempty(fp) && fp(1)==0);
history=repmat([cid;cid+1],double(d.repPeriodic)+2,1);
[kind,~,fp]=sampled_forward_step(z,g,d,history);
assert(kind==4 && isempty(fp),'Periodic rule changed.');
history=[repmat(cid,double(d.repFixPoint)+2,1);history];
[kind,~,fp]=sampled_forward_step(z,g,d,history);
assert(kind==0 && ~isempty(fp),'Rejected fixed-point test fell through to periodic.');
fprintf('Unit tests passed: certificates, counter thresholds, cache and branch priority.\n');
end
