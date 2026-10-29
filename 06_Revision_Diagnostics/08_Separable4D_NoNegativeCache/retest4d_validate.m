function assessment=retest4d_validate(d,P,out,o)
% AI-assisted independent validation; no cache, recurrence or domain-exit label.
% The basin is the product of the two independent component basins. Both
% components must support target; either component suffices for non-target.
% P uses actual query IDs. A midpoint or the exact target has query ID 0.
% Physics and solver controls match the completed separable-4D diagnostic.
assert(height(P)>0 && size(P.state,2)==4);
P.point_id=(1:height(P))';
writetable(P,fullfile(out,'independent_test_points.csv'));
testStates=[0,0,-1,0;.3,-.7,-1.2,.4;1.1,.9,.8,-.6];
for k=1:size(testStates,1)
    z=testStates(k,:).';
    assert(norm(rhs(z,d.par)-sistema(0,z,d.par),Inf)<1e-12,'Independent RHS differs from frozen model.');
end
results=cell(0,1); trajectories=cell(height(P),2);
for k=1:height(P)
    for pass=1:2
        [r,s]=integrate_point(P.state(k,:).',d,pass,o);
        r.point_id=k; r.role=P.role(k); r.query=P.query(k); r.parent_query=P.parent_query(k);
        results{end+1,1}=r; trajectories{k,pass}=s; %#ok<AGROW>
    end
    R=struct2table(vertcat(results{:}));
    writetable(R,fullfile(out,'independent_validation.csv'));
    fprintf('Seed %d: independent point %d/%d: %s / %s.\n', ...
        o.seed,k,height(P),R.outcome(end-1),R.outcome(end));
end
rows=cell(height(P),1);
for k=1:height(P)
    rr=R(R.point_id==k,:); conclusion="unresolved_or_solver_disagreement";
    if height(rr)==2 && all(rr.outcome=="target"), conclusion="both_solvers_support_target"; end
    if height(rr)==2 && all(rr.outcome=="non_target"), conclusion="both_solvers_support_non_target"; end
    contradicted=(P.original_label(k)=="non_target" && conclusion=="both_solvers_support_target") || ...
        (P.original_label(k)=="target" && conclusion=="both_solvers_support_non_target");
    rows{k}=struct('point_id',k,'role',P.role(k),'query',P.query(k), ...
        'parent_query',P.parent_query(k),'original_label',P.original_label(k), ...
        'conclusion',conclusion,'original_label_contradicted',contradicted);
end
assessment=struct2table(vertcat(rows{:}));
writetable(assessment,fullfile(out,'independent_assessment.csv'));
save(fullfile(out,'independent_trajectories.mat'),'P','R','assessment','trajectories','o','-v7.3');
end

function [r,s]=integrate_point(z0,d,pass,o)
solver=@ode45; name="ode45";
if pass==2, solver=@ode113; name="ode113"; end
horizon=o.validationHorizons(pass);
opts=odeset('RelTol',o.validationRelTol(pass),'AbsTol',o.validationAbsTol(pass), ...
    'MaxStep',o.validationMaxStep(pass),'Events',@events);
timer=tic; sol=solver(@(~,z) rhs(z,d.par),[0,horizon],z0,opts); elapsed=toc(timer);
tEnd=sol.x(end);
t=unique([linspace(0,min(tEnd,50),1001),linspace(0,tEnd,4001)]).';
z=deval(sol,t).'; E=energies(z);
[outcome,reason,qcLabel,bdLabel]=physical(z(end,:));
eventIds=[]; if isfield(sol,'ie'), eventIds=sol.ie; end
reachedHorizon=abs(tEnd-horizon)<1e-7*max(1,horizon);
energyRise=max([zeros(1,2);diff(E)],[],1);
if ~reachedHorizon && isempty(eventIds)
    outcome="unresolved"; reason="solver_stopped_without_event";
elseif any(energyRise>1e-7*max(ones(1,2),abs(E(1,:))))
    outcome="unresolved"; reason="sampled_component_energy_monotonicity_failed";
end
distance=sqrt(sum((z-d.target).^2.*d.weight,2));
outside=any(z<=d.domain(1:4) | z>=d.domain(5:8),2);
r=struct('solver',name,'requested_horizon',horizon,'end_time',tEnd, ...
    'rel_tol',o.validationRelTol(pass),'abs_tol',o.validationAbsTol(pass), ...
    'max_step',o.validationMaxStep(pass),'outcome',outcome,'reason',reason, ...
    'qc_outcome',qcLabel,'bd_outcome',bdLabel,'final_state',z(end,:), ...
    'final_target_distance',distance(end),'final_component_energy',E(end,:), ...
    'sampled_max_energy_increase',energyRise,'sampled_original_domain_exit',any(outside), ...
    'safety_stop',any(eventIds==1),'physical_test_stop',any(eventIds==2),'runtime_s',elapsed);
s=struct('solver',name,'t',t,'states',z,'energy',E,'distance',distance, ...
    'outcome',outcome,'reason',reason,'event_ids',eventIds);
    function [value,isterminal,direction]=events(tNow,state)
        e=energies(state.');
        qcTarget=max(e(1)-1/6+1e-6,state(1)-1+1e-6);
        bdTarget=max(e(2)-1/4+1e-6,state(3)+1e-6);
        bdOther=max(e(2)-1/4+1e-6,-state(3)+1e-6);
        qcEscape=max(1+1e-6-state(1),1e-6-state(2));
        sufficient=min(max(qcTarget,bdTarget),min(qcEscape,bdOther));
        value=[o.safetyStateLimit-max(abs(state));max(o.minimumValidationTime-tNow,sufficient)];
        isterminal=[1;1]; direction=[-1;-1];
    end
end

function dz=rhs(z,par)
dz=[z(2);-par.alpha_qc*abs(z(2))*z(2)-z(1)+z(1)^2; ...
    z(4);-par.alpha_bd*abs(z(4))*z(4)+z(3)-z(3)^3];
end

function e=energies(z)
e=[.5*z(:,2).^2+.5*z(:,1).^2-z(:,1).^3/3, ...
   .5*z(:,4).^2+.25*(z(:,3).^2-1).^2];
end

function [label,reason,qc,bd]=physical(z)
e=energies(z); qc="unresolved"; bd="unresolved";
if z(1)>1+1e-8 && z(2)>=0
    qc="non_target";
elseif z(1)<1 && e(1)<1/6-1e-7
    qc="target";
end
if e(2)<1/4-1e-7
    if z(3)<0, bd="target"; elseif z(3)>0, bd="non_target"; end
end
label="unresolved"; reason="component_tests_inconclusive";
if qc=="non_target" || bd=="non_target"
    label="non_target"; reason="one_component_in_other_well_or_escape_region";
elseif qc=="target" && bd=="target"
    label="target"; reason="both_components_trapped_in_target_wells";
end
end
