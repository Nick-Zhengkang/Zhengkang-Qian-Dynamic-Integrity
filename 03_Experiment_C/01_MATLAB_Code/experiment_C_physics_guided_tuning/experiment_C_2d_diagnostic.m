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
function varargout=experiment_C_2d_diagnostic(mode,varargin)
% Isolated classifier audit. Truth never uses the analytical LIM.
switch char(mode)
    case 'points'
        varargout{1}=make_points(varargin{:});
    case 'truth'
        varargout{1}=attach_truth(varargin{:});
    case 'classify'
        varargout{1}=classify_profiles(varargin{:});
    otherwise
        error('Unknown diagnostic mode.');
end
end

function D=make_points(est,a,cfg)
theta=(0:cfg.diagnosticAngles-1)'*2*pi/cfg.diagnosticAngles;
radial=[0.25 0.50 0.75 1.00 1.25];
rows=cell(numel(theta)*numel(radial),1); n=0;
for i=1:numel(radial)
    for j=1:numel(theta)
        n=n+1;
        z=est.target+radial(i)* ...
            [a.nearest_saddle_distance_Lx*cos(theta(j)), ...
             a.velocity_scale_Lv*sin(theta(j))];
        r.point_id=n; r.radius_factor=radial(i); r.angle_rad=theta(j);
        r.x0=z(1); r.v0=z(2);
        rows{n}=r;
    end
end
D=struct2table(vertcat(rows{:}));
end

function D=attach_truth(D,par,est,a,cfg,pathName)
if isfile(pathName)
    prior=readtable(pathName,'TextType','string');
    assert(height(prior)<=height(D),'Truth checkpoint is too long.');
    assert(isequal(prior.point_id,D.point_id(1:height(prior))), ...
        'Truth checkpoint has different point IDs.');
    rows=table2struct(prior);
    if isscalar(rows), rows={rows}; else, rows=num2cell(rows); end
else
    rows=cell(0,1);
end
truthDomain=[est.target(1)-10*a.nearest_saddle_distance_Lx, ...
    -100*a.velocity_scale_Lv, ...
    est.target(1)+10*a.nearest_saddle_distance_Lx, ...
    100*a.velocity_scale_Lv];
for i=numel(rows)+1:height(D)
    timer=tic;
    z0=[D.x0(i) D.v0(i)];
    try
        opts=odeset('RelTol',1e-10,'AbsTol',1e-11, ...
            'Events',@(t,z)domain_event(t,z,truthDomain));
        [~,z,te]=ode45(@(t,x)sistema(t,x,par), ...
            [0 max(4*cfg.tfinal,4000)],z0,opts);
        last=z(end,:);
        label=final_label(par.model,last,te,est.target,a);
        errorText="";
    catch ME
        label=0;
        errorText=string(ME.message);
    end
    r.point_id=D.point_id(i);
    r.radius_factor=D.radius_factor(i);
    r.angle_rad=D.angle_rad(i);
    r.x0=D.x0(i); r.v0=D.v0(i);
    r.truth_label=label;
    r.truth_wall_s=toc(timer);
    r.truth_error=errorText;
    rows{i,1}=r; %#ok<AGROW>
    fprintf('[truth %d/%d] label=%d, wall=%.2fs\n', ...
        i,height(D),label,r.truth_wall_s);
    atomic_csv(struct2table(vertcat(rows{:})),pathName);
end
D=struct2table(vertcat(rows{:}));
end

function label=final_label(model,z,te,target,a)
label=0;
if ~isempty(te)
    if strcmp(model,'quadratic_cubic') && ...
            z(1)>target(1)+a.nearest_saddle_distance_Lx && z(2)>0
        label=2;
    end
    return
end
barrier=a.potential_barrier_deltaV;
if abs(z(1)-target(1)) < 0.1*a.nearest_saddle_distance_Lx && ...
        energy(model,z)-energy(model,target) < 1e-4*barrier
    label=1;
    return
end
switch char(model)
    case 'bistable_duffing'
        if norm(z-[1 0])<0.03, label=2; end
    case 'cosine_quadratic_drag'
        well=round(z(1)/(2*pi));
        if well~=0 && norm(z-[2*pi*well 0])<0.03, label=2; end
end
end

function E=energy(model,z)
switch char(model)
    case 'quadratic_cubic', V=0.5*z(1)^2-z(1)^3/3;
    case 'bistable_duffing', V=-0.5*z(1)^2+0.25*z(1)^4;
    case 'cosine_quadratic_drag', V=1-cos(z(1));
end
E=0.5*z(2)^2+V;
end

function S=classify_profiles(D,P,par,est,outDir)
pathName=fullfile(outDir,'diagnostic_by_profile.csv');
if isfile(pathName)
    prior=readtable(pathName,'TextType','string');
    rows=num2cell(table2struct(prior));
else
    rows=cell(0,1);
end
done=strings(numel(rows),1);
for j=1:numel(rows), done(j)=string(rows{j}.profile_id); end
for i=1:height(P)
    p=P(i,:);
    if any(done==string(p.profile_id)), continue; end
    timer=tic;
    dh=(est.domain(3:4)-est.domain(1:2))/p.discr;
    cellPos=zeros(p.discr,2);
    for j=1:2
        cellPos(:,j)=est.domain(j)+dh(j)/2+(0:p.discr-1)'*dh(j);
    end
    center=zeros(2,1);
    for j=1:2
        [~,center(j)]=min(abs(cellPos(:,j)-est.target(j)));
    end
    safeCells=[find_index(center,2,p.discr); ...
        find_cells_around_a_cell(2,center,p.discr,p.k)];
    pred=zeros(height(D),1);
    for j=1:height(D)
        z0=[D.x0(j) D.v0(j)];
        if any(z0<=est.domain(1:2)) || any(z0>=est.domain(3:4))
            continue
        end
        try
            [~,~,~,pred(j)]=simulation_DI(2,par,z0,p.tfinal,p.Ts, ...
                [1e-8 1e-8],est.domain,p.discr,safeCells,[],[], ...
                cellPos,dh,40,p.rep_periodic,0.005,0,est.weight);
        catch
            pred(j)=0;
        end
    end
    truth=D.truth_label;
    nonTarget=truth==2; target=truth==1;
    resolved=nonTarget|target;
    r.profile_id=string(p.profile_id);
    r.n_points=height(D);
    r.n_true_target=nnz(target);
    r.n_true_non_target=nnz(nonTarget);
    r.n_truth_unresolved=nnz(~resolved);
    r.n_false_safe=nnz(pred==1 & nonTarget);
    r.n_false_unsafe=nnz(ismember(pred,[2 3 4]) & target);
    r.false_safe_rate=rate(r.n_false_safe,r.n_true_non_target);
    r.false_unsafe_rate=rate(r.n_false_unsafe,r.n_true_target);
    r.classifier_unresolved_rate=rate(nnz(pred==0 & resolved),nnz(resolved));
    r.truth_unresolved_rate=nnz(~resolved)/height(D);
    r.wall_s=toc(timer);
    rows{end+1,1}=r; %#ok<AGROW>
    atomic_csv(struct2table(vertcat(rows{:})),pathName);
    done(end+1,1)=r.profile_id; %#ok<AGROW>
    fprintf('[diagnostic %d/%d] FSR=%g, FUR=%g, unresolved=%g\n', ...
        i,height(P),r.false_safe_rate,r.false_unsafe_rate, ...
        r.classifier_unresolved_rate);
end
S=struct2table(vertcat(rows{:}));
end

function y=rate(num,den)
if den==0, y=NaN; else, y=num/den; end
end

function [value,isterminal,direction]=domain_event(~,z,domain)
value=min([z(1)-domain(1),z(2)-domain(2), ...
    domain(3)-z(1),domain(4)-z(2)]);
isterminal=1; direction=-1;
end

function atomic_csv(T,pathName)
[folder,name,ext]=fileparts(pathName);
tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp); movefile(tmp,pathName,'f');
end
