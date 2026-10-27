% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
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
function experiment_C_2d_pilot(par,est,a,cfg,outDir)
% T -> 2T stability check. No analytical LIM is read.
T=cfg.pilotMultiplier*max(est.tfinal,20*a.local_period);
angles=(0:15)'*2*pi/16;
radii=[0.15 0.35 0.65 0.95];
rows=cell(numel(angles)*numel(radii),1);
pointPath=fullfile(outDir,'pilot_point_labels.csv');
if isfile(pointPath)
    prior=readtable(pointPath,'TextType','string');
    assert(ismember('pilot_rule_version',prior.Properties.VariableNames) && ...
        all(prior.pilot_rule_version==2), ...
        'Pilot classifier changed; start a new output folder.');
    for j=1:height(prior)
        rows{prior.point_id(j)}=table2struct(prior(j,:));
    end
end
n=0;
fprintf('2-D pilot: T=%.1f; 2T=%.1f; %d fixed points\n',T,2*T,numel(rows));
for i=1:numel(radii)
    for j=1:numel(angles)
        n=n+1;
        if ~isempty(rows{n}), continue; end
        proposed=est.target+radii(i)* ...
            [a.nearest_saddle_distance_Lx*cos(angles(j)), ...
             a.velocity_scale_Lv*sin(angles(j))];
        z0=fit_inside_domain(proposed,est.target,est.domain);
        timer=tic;
        atT="unresolved"; at2T="unresolved";
        dT=NaN; d2T=NaN; errorText="";
        try
            opts=odeset('RelTol',1e-10,'AbsTol',1e-11);
            if strcmp(par.model,'quadratic_cubic')
                opts=odeset(opts,'Events', ...
                    @(t,z)right_escape_event(t,z,est.domain(3)));
                [t,z,te]=ode45(@(t,x)sistema(t,x,par), ...
                    [0 T 2*T],z0,opts);
            else
                [t,z]=ode45(@(t,x)sistema(t,x,par), ...
                    [0 T 2*T],z0,opts);
                te=[];
            end
            if ~isempty(te) && te(1)<T
                atT="non_target"; at2T="non_target";
            else
                zT=interp1(t,z,T,'linear');
                dT=energy_above_target(par.model,zT,est.target);
                atT=state_label(par.model,zT,est.target,a,cfg,dT);
                if ~isempty(te)
                    at2T="non_target";
                else
                    d2T=energy_above_target(par.model,z(end,:),est.target);
                    at2T=state_label(par.model,z(end,:),est.target,a,cfg,d2T);
                end
            end
        catch ME
            errorText=string(ME.message);
        end
        r.pilot_rule_version=2;
        r.point_id=n; r.radius_factor=radii(i); r.angle_rad=angles(j);
        r.x0=z0(1); r.v0=z0(2);
        r.status_T=atT; r.status_2T=at2T;
        r.energy_T=dT; r.energy_2T=d2T;
        r.wall_s=toc(timer); r.error_message=errorText;
        rows{n}=r;
        fprintf('[pilot %d/%d] %s -> %s (%.2fs)\n', ...
            n,numel(rows),char(atT),char(at2T),r.wall_s);
        atomic_csv(struct2table(vertcat(rows{1:n})),pointPath);
    end
end
P=struct2table(vertcat(rows{:}));
pass=nnz(P.status_2T=="target")>=4 && ...
    all(P.status_T==P.status_2T) && ...
    ~any(strlength(P.error_message)>0);
recommendedT=NaN;
if pass, recommendedT=2*T; end
audit=table(2,string(par.model),par.alpha,T,2*T,recommendedT, ...
    nnz(P.status_T=="target"),nnz(P.status_2T=="target"), ...
    nnz(P.status_2T=="non_target"), ...
    nnz(P.status_2T=="unresolved"),sum(P.wall_s),pass, ...
    'VariableNames',{'pilot_rule_version','model','alpha','T','two_T', ...
    'recommended_tfinal', ...
    'target_at_T','target_at_2T','non_target_at_2T','unresolved_at_2T', ...
    'pilot_wall_s','pilot_pass'});
writetable(audit,fullfile(outDir,'pilot_audit.csv'));
if ~pass
    warning(['Pilot labels changed or target evidence is insufficient. ', ...
        'Do not freeze tfinal; inspect the point CSV and extend T.']);
end
end

function z=fit_inside_domain(proposed,target,domain)
delta=proposed-target;
scale=1;
for j=1:2
    if delta(j)>0
        scale=min(scale,0.9*(domain(j+2)-target(j))/delta(j));
    elseif delta(j)<0
        scale=min(scale,0.9*(domain(j)-target(j))/delta(j));
    end
end
z=target+scale*delta;
end

function label=state_label(model,z,target,a,cfg,E)
label="unresolved";
qx=a.target_position_tolerance;
vv=a.target_velocity_tolerance;
if abs(z(1)-target(1))<=qx && abs(z(2))<=vv && ...
        E<=cfg.beta*a.potential_barrier_deltaV
    label="target";
    return
end
switch char(model)
    case 'bistable_duffing'
        if abs(z(1)-1)<=qx && abs(z(2))<=vv
            label="non_target";
        end
    case 'cosine_quadratic_drag'
        other=round(z(1)/(2*pi));
        if other~=0 && abs(z(1)-2*pi*other)<=qx && abs(z(2))<=vv
            label="non_target";
        end
end
end

function E=energy_above_target(model,z,target)
E=0.5*z(2)^2+potential(model,z(1))-potential(model,target(1));
end

function V=potential(model,x)
switch char(model)
    case 'quadratic_cubic', V=0.5*x.^2-x.^3/3;
    case 'bistable_duffing', V=-0.5*x.^2+0.25*x.^4;
    case 'cosine_quadratic_drag', V=1-cos(x);
end
end

function [value,isterminal,direction]=right_escape_event(~,z,rightEdge)
value=rightEdge-z(1);
isterminal=1; direction=-1;
end

function atomic_csv(T,pathName)
[folder,name,ext]=fileparts(pathName);
tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp); movefile(tmp,pathName,'f');
end
