function A=fpguard_validate_independent(id,d,trace,row,out,o)
% AI-assisted diagnostic implementation, not a replacement experiment.
% Independent RHS and continuous integration: no learned grid labels,
% no native recurrence rules and no stop at the original domain boundary.
ids=unique([trace.winning_chain,trace.first_under_chain],'stable');
fullCount=numel(ids);
ids=ids(1:min(numel(ids),o.maxValidationQueriesPerCase));
fid=fopen(fullfile(out,'validation_scope.txt'),'w');
fprintf(fid,'Ancestry queries: %d; validated: %d; truncated: %d\n', ...
    fullCount,numel(ids),fullCount>numel(ids));
fprintf(fid,'Maximum horizons: %g and %g times the original horizon.\n',o.horizonFactors);
fprintf(fid,'Energy early stop enabled: %d; minimum time: %g.\n', ...
    o.stopAtEnergyCertificate,o.minimumValidationTime); fclose(fid);

points=cell(0,1);
for q=ids
    a=trace.queries(q,:);
    points{end+1,1}=point(q,"initial_state",a.x0,a.v0,0); %#ok<AGROW>
    if a.parent_query>0
        points{end+1,1}=point(q,"cache_hit_state",a.hit_x,a.hit_v,a.parent_query); %#ok<AGROW>
        points{end+1,1}=point(q,"first_writer_state",a.donor_x,a.donor_v,a.parent_query); %#ok<AGROW>
    end
end
P=struct2table(vertcat(points{:}));
writetable(P,fullfile(out,'independent_test_points.csv'));
alpha=double(d.par.alpha); assert(alpha>0);
testStates=[0,0;0.3,-0.7;-1.2,0.4;1.1,0.9];
for k=1:size(testStates,1)
    z=testStates(k,:).';
    assert(norm(rhs_model(id,alpha,z)-sistema(0,z,d.par),Inf)<1e-12, ...
        'Independent model equations do not match the archived model.');
end
results=cell(0,1); trajectories=cell(height(P),2);
for k=1:height(P)
    p=P(k,:); z0=[p.x;p.v];
    fprintf('  independent point %d/%d, query %d, %s\n',k,height(P),p.query,p.role);
    for pass=1:2
        [r,s]=integrate_point(id,d,z0,pass,o);
        r.query=p.query; r.role=p.role; r.parent_query=p.parent_query;
        r.x0=p.x; r.v0=p.v;
        results{end+1,1}=r; trajectories{k,pass}=s; %#ok<AGROW>
    end
    R=struct2table(vertcat(results{:}));
    writetable(R,fullfile(out,'independent_validation.csv'));
    save(fullfile(out,'independent_trajectories.mat'),'P','R','trajectories','-v7.3');
    if p.query==row.winning_query
        plot_point(id,d,p,trajectories(k,:),out);
    end
end
assessment=cell(height(P),1);
for k=1:height(P)
    p=P(k,:); rr=R(R.query==p.query & R.role==p.role,:);
    agrees=height(rr)==2 && rr.outcome(1)==rr.outcome(2);
    targetSupported=agrees && rr.outcome(1)=="target";
    nonTargetSupported=agrees && rr.outcome(1)=="non_target";
    conclusion="unresolved_or_solver_disagreement";
    if targetSupported, conclusion="both_solvers_support_target"; end
    if nonTargetSupported, conclusion="both_solvers_support_non_target"; end
    assessment{k}=struct('query',p.query,'role',p.role,'conclusion',conclusion, ...
        'original_query_label_contradicted',targetSupported && p.role=="initial_state", ...
        'parent_query',p.parent_query);
end
A=struct2table(vertcat(assessment{:}));
writetable(A,fullfile(out,'independent_assessment.csv'));
save(fullfile(out,'independent_assessment.mat'),'A');
end

function p=point(q,role,x,v,parent)
p=struct('query',q,'role',role,'x',x,'v',v,'parent_query',parent);
end

function [r,s]=integrate_point(id,d,z0,pass,o)
alpha=double(d.par.alpha); horizon=double(d.tfinal)*o.horizonFactors(pass);
solver=@ode45; solverName="ode45";
if pass==2, solver=@ode113; solverName="ode113"; end
options=odeset('RelTol',o.validationRelTol(pass),'AbsTol',o.validationAbsTol(pass), ...
    'MaxStep',o.validationMaxStep(pass),'Events',@events);
tic;
sol=solver(@(~,z) rhs_model(id,alpha,z),[0,horizon],z0,options);
runtime=toc;
tEnd=sol.x(end);
t=unique([linspace(0,min(tEnd,50),1001),linspace(0,tEnd,4001)]).';
z=deval(sol,t).';
E=energy_model(id,z(:,1),z(:,2));
[outcome,reason,margin]=physical_outcome(id,z(end,:));
eventIds=[]; if isfield(sol,'ie'), eventIds=sol.ie; end
stoppedAtEvent=~isempty(eventIds);
reachedHorizon=abs(tEnd-horizon)<1e-7*max(1,horizon);
energyRise=max([0;diff(E)]);
if ~reachedHorizon && ~stoppedAtEvent
    outcome="unresolved"; reason="solver_stopped_before_horizon_without_event";
elseif energyRise>1e-7*max(1,abs(E(1)))
    outcome="unresolved"; reason="energy_monotonicity_check_failed";
end
target=reshape(double(d.target),1,[]); weight=reshape(double(d.weight),1,[]);
distance=sqrt(sum((z-target).^2.*weight,2));
domain=double(d.domain);
outside=any(z<=domain(1:2) | z>=domain(3:4),2);
firstExit=find(outside,1); exitTime=NaN;
if ~isempty(firstExit), exitTime=t(firstExit); end
r=struct('solver',solverName,'requested_horizon',horizon,'actual_end_time',tEnd, ...
    'rel_tol',o.validationRelTol(pass),'abs_tol',o.validationAbsTol(pass), ...
    'max_step',o.validationMaxStep(pass),'outcome',outcome,'reason',reason, ...
    'final_x',z(end,1),'final_v',z(end,2),'final_target_distance',distance(end), ...
    'final_energy',E(end),'energy_barrier_margin',margin, ...
    'max_sampled_energy_increase',energyRise,'sampled_original_domain_exit',any(outside), ...
    'first_sampled_original_exit_time',exitTime,'energy_stop',any(eventIds==2), ...
    'safety_stop',any(eventIds==1),'runtime_s',runtime);
s=struct('solver',solverName,'t',t,'states',z,'energy',E,'distance',distance, ...
    'outcome',outcome,'reason',reason,'event_ids',eventIds);

    function [value,isterminal,direction]=events(tNow,state)
        e=energy_model(id,state(1),state(2));
        energyValue=1;
        % Separate event margin from the classification margin to avoid
        % floating-point ambiguity at an event lying exactly on the limit.
        eligible=~(id=="quadratic_cubic" && state(1)>=1);
        if o.stopAtEnergyCertificate && eligible
            energyValue=max(o.minimumValidationTime-tNow,e-barrier(id)+1e-6);
        end
        value=[o.safetyStateLimit-max(abs(state));energyValue];
        isterminal=[1;1]; direction=[-1;-1];
    end
end

function dz=rhs_model(id,alpha,z)
x=z(1); v=z(2);
switch id
    case "quadratic_cubic", force=-x+x^2;
    case "bistable_duffing", force=x-x^3;
    case "genda_cosine_quadratic_drag", force=-sin(x);
    otherwise, error('Unsupported model.');
end
dz=[v;-alpha*abs(v)*v+force];
end

function E=energy_model(id,x,v)
switch id
    case "quadratic_cubic", U=0.5*x.^2-x.^3/3;
    case "bistable_duffing", U=0.25*(x.^2-1).^2;
    case "genda_cosine_quadratic_drag", U=1-cos(x);
    otherwise, error('Unsupported model.');
end
E=0.5*v.^2+U;
end

function b=barrier(id)
switch id
    case "quadratic_cubic", b=1/6;
    case "bistable_duffing", b=1/4;
    case "genda_cosine_quadratic_drag", b=2;
    otherwise, error('Unsupported model.');
end
end

function [label,reason,margin]=physical_outcome(id,z)
x=z(1); v=z(2); margin=barrier(id)-energy_model(id,x,v);
label="unresolved"; reason="no_sufficient_physical_test_passed";
if id=="quadratic_cubic" && x>1+1e-8 && v>=0
    label="non_target"; reason="forward_invariant_escape_region"; return
end
if margin<=1e-7, return; end
switch id
    case "quadratic_cubic"
        if x<1, label="target"; reason="target_well_energy_trap"; end
    case "bistable_duffing"
        if x<0
            label="target"; reason="left_target_well_energy_trap";
        elseif x>0
            label="non_target"; reason="right_other_well_energy_trap";
        end
    case "genda_cosine_quadratic_drag"
        if abs(x)<pi
            label="target"; reason="central_target_well_energy_trap";
        else
            label="non_target"; reason="other_well_energy_trap";
        end
end
end

function plot_point(id,d,p,solutions,out)
fig=figure('Visible','off','Color','w','Position',[100,100,1100,700]);
guard=onCleanup(@() close(fig)); %#ok<NASGU>
tl=tiledlayout(fig,2,2,'TileSpacing','compact');
ax1=nexttile(tl); hold(ax1,'on'); xlabel(ax1,'Time'); ylabel(ax1,'Position x');
ax2=nexttile(tl); hold(ax2,'on'); xlabel(ax2,'Position x'); ylabel(ax2,'Velocity v');
ax3=nexttile(tl); hold(ax3,'on'); xlabel(ax3,'Time'); ylabel(ax3,'Distance to target');
ax3.YScale='log';
ax4=nexttile(tl); hold(ax4,'on'); xlabel(ax4,'Time'); ylabel(ax4,'Energy');
for j=1:numel(solutions)
    s=solutions{j};
    plot(ax1,s.t,s.states(:,1),'DisplayName',s.solver);
    plot(ax2,s.states(:,1),s.states(:,2),'DisplayName',s.solver);
    plot(ax3,s.t,max(s.distance,1e-15),'DisplayName',s.solver);
    plot(ax4,s.t,s.energy,'DisplayName',s.solver);
end
domain=double(d.domain);
rectangle(ax2,'Position',[domain(1:2),domain(3:4)-domain(1:2)], ...
    'EdgeColor',[0.5,0.5,0.5],'LineStyle','--');
yline(ax4,barrier(id),'--','Potential barrier');
for ax=[ax1,ax2,ax3,ax4], grid(ax,'on'); end
legend(ax1,'Location','best');
title(tl,sprintf('%s | query %d | %s',id,p.query,p.role),'Interpreter','none');
exportgraphics(fig,fullfile(out,sprintf('winning_query_%d_%s.png',p.query,p.role)), ...
    'Resolution',150);
end
