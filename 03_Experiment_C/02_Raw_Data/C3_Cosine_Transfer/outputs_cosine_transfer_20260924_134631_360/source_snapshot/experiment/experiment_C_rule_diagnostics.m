function varargout=experiment_C_rule_diagnostics(action,varargin)
% Pointwise, reference-LIM-blind calibration and held-out classification.
switch char(action)
    case 'dataset'
        varargout{1}=dataset(varargin{:});
    case 'classify'
        [varargout{1:nargout}]=classify(varargin{:});
    case 'summarize'
        varargout{1}=summarize(varargin{:});
    case 'oracle'
        [varargout{1:nargout}]=oracle(varargin{:});
    otherwise
        error('Unknown diagnostic action.');
end
end

function D=dataset(split,f,cfg,outDir)
split=string(split);
file=fullfile(outDir,char(split+"_truth.csv"));
rows=cell(0,1);
if isfile(file), rows=num2cell(table2struct(readtable(file,'TextType','string'))); end
if split=="calibration"
    nAngles=cfg.calibrationAngles; radii=cfg.calibrationRadii; offset=0.173;
    boundarySteps=cfg.boundaryBisections;
else
    nAngles=cfg.holdoutAngles; radii=cfg.holdoutRadii; offset=0.673;
    boundarySteps=cfg.holdoutBoundaryBisections;
end
theta=((0:nAngles-1)+offset)*2*pi/nAngles;
n=0;
for j=1:nAngles
    for radius=radii
        n=n+1;
        [rows,~]=probe(rows,n,theta(j),radius,"coverage",f,cfg,file);
    end
end
base=struct2table(vertcat(rows{1:n}));
% Follow observed label transitions; never use analytical boundary locations.
for j=1:nAngles
    g=base(abs(base.angle_rad-theta(j))<1e-12 & base.inside_domain,:);
    g=sortrows(g,'radius_factor');
    if height(g)<2, continue; end
    ix=find(g.truth_label(1:end-1)==1 & g.truth_label(2:end)==2,1);
    if isempty(ix), continue; end
    lo=g.radius_factor(ix); hi=g.radius_factor(ix+1);
    for b=1:boundarySteps
        radius=(lo+hi)/2; n=n+1;
        [rows,r]=probe(rows,n,theta(j),radius,"near_boundary",f,cfg,file);
        if r.truth_label==1
            lo=radius;
        elseif r.truth_label==2
            hi=radius;
        else
            break
        end
    end
end
assert(numel(rows)==n,'Diagnostic checkpoint contains unexpected extra points.');
D=struct2table(vertcat(rows{:}));
end

function [rows,r]=probe(rows,n,theta,radius,kind,f,cfg,file)
z=f.target+radius*[f.Lx*cos(theta),f.Lv*sin(theta)];
if n<=numel(rows)
    r=rows{n};
    assert(abs(r.x0-z(1))<1e-12 && abs(r.v0-z(2))<1e-12, ...
        'Diagnostic checkpoint points differ.');
    return
end
timer=tic;
[label,reason,simTime,errorText]=oracle(z,f,cfg);
r=struct('point_id',n,'kind',kind,'radius_factor',radius, ...
    'angle_rad',theta,'x0',z(1),'v0',z(2), ...
    'inside_domain',all(z>f.domain(1:2) & z<f.domain(3:4)), ...
    'truth_label',label,'truth_reason',reason,'truth_sim_time',simTime, ...
    'truth_wall_s',toc(timer),'truth_error',errorText);
rows{n,1}=r;
atomic_csv(struct2table(vertcat(rows{:})),file);
fprintf('[%s point %d] oracle=%d, inside=%d, %s, %.2fs\n', ...
    char(kind),n,label,r.inside_domain,char(reason),r.truth_wall_s);
end

function [label,reason,simTime,errorText]=oracle(z0,f,cfg)
errorText=""; simTime=0;
[label,reason]=experiment_C_rule_physics('trap',f.model,z0,f,cfg.oracleEnergyMargin);
if label~=0, return; end
T=min(cfg.oracleMaxTime,max(cfg.oraclePeriods*f.period,4*f.timeFromDecay));
try
    opts=odeset('RelTol',cfg.oracleRelTol,'AbsTol',cfg.oracleAbsTol, ...
        'MaxStep',f.period/20,'Events',@(t,z)oracle_event(t,z,f,cfg));
    [t,z]=ode45(@(t,z)experiment_C_rule_physics('rhs',f.model,f.alpha,z), ...
        [0 T],z0,opts);
    simTime=t(end);
    % The event lies inside the trapping threshold by a numerical margin.
    [label,reason]=experiment_C_rule_physics('trap',f.model,z(end,:), ...
        f,0.5*cfg.oracleEnergyMargin);
    if label==0, reason="oracle_horizon_or_saddle"; end
catch ME
    label=0; reason="oracle_exception"; errorText=string(ME.message);
end
end

function [value,isterminal,direction]=oracle_event(~,z,f,cfg)
E=0.5*z(2)^2+experiment_C_rule_physics('potential',f.model,z(1));
Emin=experiment_C_rule_physics('potential',f.model,f.target(1));
value=E-Emin-(1-cfg.oracleEnergyMargin)*f.barrier;
isterminal=1; direction=-1;
if f.model=="quadratic_cubic"
    % Detect entry into x>1,v>0, including turns beyond the old x=1.01 plane.
    value=[value;max(1+1e-8-z(1),1e-8-z(2))]; isterminal=[1;1]; direction=[-1;-1];
end
end

function [S,Q,key]=classify(D,split,p,f,cfg,outDir)
key=string(sprintf('%s_N%d_k%d_T%.12g_dt%.12g_rep%d', ...
    char(split),p.discr,p.k,p.tfinal,p.Ts,p.rep_periodic));
key=replace(key,'.','p');
folder=fullfile(outDir,'classifier_cache');
if ~isfolder(folder), mkdir(folder); end
file=fullfile(folder,char(key+".csv"));
settingsFile=fullfile(folder,char(key+".mat"));
if isfile(settingsFile)
    old=load(settingsFile,'p');
    % belt_mode is irrelevant once the same k and geometry were selected.
    fields={'discr','k','Ts','tfinal','rep_periodic'};
    for i=1:numel(fields)
        assert(isequaln(old.p.(fields{i}),p.(fields{i})),'Classifier cache collision.');
    end
else
    save(settingsFile,'p');
end
rows=cell(0,1);
if isfile(file)
    rows=num2cell(table2struct(readtable(file,'TextType','string')));
    assert(numel(rows)<=height(D),'Classifier cache has extra points.');
end
dh=(f.domain(3:4)-f.domain(1:2))/p.discr;
centers=zeros(p.discr,2);
for j=1:2
    centers(:,j)=f.domain(j)+((0:p.discr-1)'+0.5)*dh(j);
end
center=zeros(2,1);
for j=1:2, [~,center(j)]=min(abs(centers(:,j)-f.target(j))); end
safe=[find_index(center,2,p.discr);find_cells_around_a_cell(2,center,p.discr,p.k)];
par=struct('model',f.model,'alpha',f.alpha);
for i=numel(rows)+1:height(D)
    r=table2struct(D(i,:));
    r.predicted_label=0; r.raw_tipo=0; r.classifier_status="domain_excluded";
    r.integration_time=0; r.classifier_wall_s=0; r.classifier_error="";
    r.new_solution_points=0;
    r.sampled_non_target_distance=NaN;
    if r.inside_domain
        timer=tic;
        try
            [trajectory,~,~,tipo,newSolution,count]=simulation_DI(2,par,[r.x0 r.v0], ...
                p.tfinal,p.Ts,[cfg.relTol cfg.absTol],f.domain,p.discr, ...
                safe,[],[],centers,dh,cfg.repFixPoint,p.rep_periodic, ...
                0.005,0,f.weight);
            r.raw_tipo=tipo;
            r.integration_time=max(0,count-1)*p.Ts;
            r.new_solution_points=size(newSolution,1);
            if tipo==1
                r.predicted_label=1; r.classifier_status="target";
            elseif ismember(tipo,[2 3 4])
                r.predicted_label=2;
                r.sampled_non_target_distance=min(sqrt(sum( ...
                    (trajectory-f.target).^2.*f.weight,2)));
                names=["known_non_target","domain_exit","new_attractor"];
                r.classifier_status=names(tipo-1);
            else
                r.classifier_status="horizon_unresolved";
            end
        catch ME
            r.classifier_status="classifier_exception";
            r.classifier_error=string(ME.message);
        end
        r.classifier_wall_s=toc(timer);
    end
    rows{i,1}=r;
    atomic_csv(struct2table(vertcat(rows{:})),file);
    if mod(i,10)==0 || i==height(D)
        fprintf('[diagnostic %s %d/%d] N=%d k=%d T=%.3g Ts=%.3g\n', ...
            char(split),i,height(D),p.discr,p.k,p.tfinal,p.Ts);
    end
end
Q=struct2table(vertcat(rows{:}));
assert(isequal(Q.point_id,D.point_id) && max(abs(Q.x0-D.x0))<1e-12 && ...
    max(abs(Q.v0-D.v0))<1e-12,'Classifier cache uses different points.');
S=summarize(Q,cfg);
S.cache_key=key;
end

function S=summarize(Q,cfg)
inside=logical(Q.inside_domain);
known=inside & ismember(Q.truth_label,[1 2]);
target=known & Q.truth_label==1; nonTarget=known & Q.truth_label==2;
S=struct();
S.n_points=height(Q);
S.n_inside=nnz(inside);
S.n_domain_excluded=nnz(~inside);
S.n_truth_unresolved=nnz(inside & Q.truth_label==0);
S.n_true_target=nnz(target); S.n_true_non_target=nnz(nonTarget);
S.n_near_boundary_known=nnz(known & string(Q.kind)=="near_boundary");
S.n_false_safe=nnz(nonTarget & Q.predicted_label==1);
S.n_false_unsafe=nnz(target & Q.predicted_label==2);
S.n_unresolved=nnz(known & Q.predicted_label==0);
S.n_exceptions=nnz(inside & string(Q.classifier_status)=="classifier_exception");
S.n_domain_exit_false_unsafe=nnz(target & Q.raw_tipo==3);
S.n_new_attractor_false_unsafe=nnz(target & Q.raw_tipo==4);
S.false_safe_rate=ratio(S.n_false_safe,S.n_true_non_target);
S.false_unsafe_rate=ratio(S.n_false_unsafe,S.n_true_target);
S.unresolved_rate=ratio(S.n_unresolved,nnz(known));
S.truth_unresolved_rate=ratio(S.n_truth_unresolved,S.n_inside);
S.classifier_wall_s=sum(Q.classifier_wall_s);
S.diagnostic_pass=S.n_true_target>=cfg.minClassCount && ...
    S.n_true_non_target>=cfg.minClassCount && ...
    S.n_near_boundary_known>=cfg.minBoundaryPoints && S.n_exceptions==0 && ...
    S.false_safe_rate<=cfg.maxFalseSafe && S.false_unsafe_rate<=cfg.maxFalseUnsafe && ...
    S.unresolved_rate<=cfg.maxUnresolved && ...
    S.truth_unresolved_rate<=cfg.maxTruthUnresolved;
end

function y=ratio(n,d)
if d==0, y=NaN; else, y=n/d; end
end

function atomic_csv(T,file)
[folder,name,ext]=fileparts(file);
tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end
