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
function outDir = run_experiment_C_2d_rule(model,alpha,stage,seeds,cfg,resumeDir)
%RUN_EXPERIMENT_C_2D_RULE Reference-blind parameter design, then LIM scoring.
if nargin<6, resumeDir=''; end
model = validatestring(char(model), ...
    {'quadratic_cubic','bistable_duffing','cosine_quadratic_drag'});
stage = validatestring(char(stage), ...
    {'pilot','grid','belt','Ts','periodic','budget','validate'});
validateattributes(alpha,{'numeric'},{'scalar','positive','finite'});
validateattributes(seeds,{'numeric'},{'vector','integer','positive','nonempty'});
seeds = unique(seeds(:)','stable');
if strcmp(stage,'validate')
    assert(numel(seeds)>=30 && isempty(intersect(seeds,1:10)), ...
        'Validation needs 30 fresh seeds, e.g. 31:60.');
elseif ~strcmp(stage,'pilot')
    assert(cfg.pilotConfirmed, ...
        'First inspect a passed pilot, then set cfg.pilotConfirmed=true.');
end

here = fileparts(mfilename('fullpath'));
modelDir = fullfile(here,'transfer_2d_model');
funcDir = fullfile(fileparts(here),'work','DynIn', ...
    'DynIn_v1.1.0','functions');
assert(isfile(fullfile(funcDir,'compute_LIM_FP.m')));
assert(isfile(fullfile(modelDir,'sistema.m')));
if isempty(resumeDir)
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    outDir = fullfile(here,['outputs_2d_rule_' model '_' stage '_' stamp]);
    mkdir(outDir);
else
    outDir = char(resumeDir);
    assert(isfolder(outDir),'Resume folder not found.');
end
oldPath = path;
pathGuard = onCleanup(@()path(oldPath)); %#ok<NASGU>
restoredefaultpath;
rehash toolboxcache;
addpath(here,'-begin');
addpath(funcDir,'-begin');
addpath(modelDir,'-begin');
assert(strcmpi(which('compute_LIM_FP'),fullfile(funcDir,'compute_LIM_FP.m')));
assert(strcmpi(which('sistema'),fullfile(modelDir,'sistema.m')));

options = struct('beta_target',cfg.beta,'eta_grid',cfg.eta, ...
    'samples_per_period',cfg.samplesPerPeriod, ...
    'domain_margin_fraction',cfg.domainMargin);
[estimate,audit] = estimate_dynin_parameters_from_physics( ...
    model,alpha,NaN,options);
par = struct('model',string(model),'alpha',alpha);
configPath = fullfile(outDir,'run_configuration.mat');
if isfile(configPath)
    prior = load(configPath);
    assert(strcmp(prior.model,model) && prior.alpha==alpha && ...
        strcmp(prior.stage,stage) && isequaln(prior.cfg,cfg) && ...
        isequal(prior.seeds,seeds),'Resume configuration differs.');
else
    save(configPath,'model','alpha','stage','seeds','cfg');
end
writetable(struct2table(audit),fullfile(outDir,'physical_scale_audit.csv'));
if strcmp(stage,'pilot')
    experiment_C_2d_pilot(par,estimate,audit,cfg,outDir);
    return
end

profiles = make_profiles(stage,model,estimate,audit,cfg);
profilePath = fullfile(outDir,'profiles.csv');
if isfile(profilePath)
    saved = readtable(profilePath,'TextType','string');
    assert(isequaln(saved,profiles),'Resume profiles differ.');
else
    writetable(profiles,profilePath);
end
schedule = make_schedule(profiles,seeds,model,alpha,stage);
schedulePath = fullfile(outDir,'randomized_schedule.csv');
if isfile(schedulePath)
    saved = readtable(schedulePath,'TextType','string');
    assert(isequaln(saved,schedule),'Resume schedule differs.');
else
    writetable(schedule,schedulePath);
end

% Fixed initial states and long-integration labels do not use reference LIM.
diagnostic = experiment_C_2d_diagnostic('points',estimate,audit,cfg);
truthPath = fullfile(outDir,'diagnostic_truth.csv');
diagnostic = experiment_C_2d_diagnostic('truth', ...
    diagnostic,par,estimate,audit,cfg,truthPath);
diagnosticSummary = experiment_C_2d_diagnostic('classify', ...
    diagnostic,profiles,par,estimate,outDir);
writetable(diagnosticSummary,fullfile(outDir,'diagnostic_by_profile.csv'));

rawPath = fullfile(outDir,'raw_data_all_runs.csv');
if isfile(rawPath)
    raw = readtable(rawPath,'TextType','string');
    completed = string(raw.run_key);
else
    raw = table();
    completed = strings(0,1);
end
[Rref,referenceResidual] = experiment_C_2d_reference(model,alpha);
fprintf('DynIn GA 2-D rule: %s alpha=%.3g, stage=%s, %d runs\n', ...
    model,alpha,stage,height(schedule));
fprintf('Reference is used only for post-run scoring: %.8g\n',Rref);
for i=1:height(schedule)
    key = string(schedule.run_key(i));
    if any(completed==key), continue; end
    p = profiles(profiles.profile_id==schedule.profile_id(i),:);
    rng(schedule.algorithm_seed(i),'twister');
    fprintf('[run %d/%d] START profile=%s seed=%d\n', ...
        i,height(schedule),char(p.profile_id),schedule.seed(i));
    row = run_ga(p,par,estimate.target,estimate.weight, ...
        estimate.domain,Rref,key,schedule.seed(i),i);
    if isempty(raw), raw=row; else, raw=[raw;row]; end %#ok<AGROW>
    atomic_csv(raw,rawPath);
    completed(end+1,1)=key; %#ok<AGROW>
    fprintf('[run %d/%d] DONE R=%.6g, rel.err=%.3g, wall=%.2fs, %s\n', ...
        i,height(schedule),row.R_hat,row.relative_error, ...
        row.wall_s,char(row.status));
end
summary = summarize_runs(raw,diagnosticSummary);
writetable(summary,fullfile(outDir,'summary_by_profile.csv'));
referenceAudit = table(string(model),alpha,Rref,referenceResidual, ...
    'VariableNames',{'model','alpha','reference_LIM','reference_residual'});
writetable(referenceAudit,fullfile(outDir,'reference_audit.csv'));
fprintf('Raw: %s\nSummary: %s\n',rawPath, ...
    fullfile(outDir,'summary_by_profile.csv'));
end

function P = make_profiles(stage,model,est,a,cfg)
base = struct('discr',est.discr,'k',est.num_of_cell_around_equilibrium, ...
    'Ts',est.Ts,'tfinal',cfg.tfinal,'rep_periodic',cfg.repPeriodic, ...
    'number_of_steps',cfg.numberOfSteps,'beta',cfg.beta,'eta',cfg.eta);
base.k=target_cells(model,est.target,est.domain,base.discr, ...
    cfg.beta,a.potential_barrier_deltaV,a.local_curvature);
switch stage
    case 'grid'
        levels = est.discr*[0.5 1 2]; field='discr';
    case 'belt'
        levels = cfg.beta*[0.5 1 2]; field='beta';
    case 'Ts'
        levels = est.Ts*[0.5 1 2]; field='Ts';
    case 'periodic'
        levels = [5 10 30]; field='rep_periodic';
    case 'budget'
        levels = [50 100 200]; field='number_of_steps';
    otherwise
        levels=1; field='frozen';
end
rows = cell(numel(levels),1);
for i=1:numel(levels)
    p=base;
    if strcmp(field,'discr')
        p.discr=round(levels(i));
        if mod(p.discr,2)==0, p.discr=p.discr+1; end
        p.k=target_cells(model,est.target,est.domain,p.discr, ...
            cfg.beta,a.potential_barrier_deltaV,a.local_curvature);
    elseif strcmp(field,'beta')
        p.beta=levels(i);
        p.k=target_cells(model,est.target,est.domain,p.discr, ...
            p.beta,a.potential_barrier_deltaV,a.local_curvature);
    elseif ~strcmp(field,'frozen')
        p.(field)=levels(i);
    end
    p.achieved_eta=max( ...
        (est.domain(3)-est.domain(1))/(p.discr*a.nearest_saddle_distance_Lx), ...
        (est.domain(4)-est.domain(2))/(p.discr*a.velocity_scale_Lv));
    p.achieved_samples_per_period=a.local_period/p.Ts;
    p.profile_id="P"+string(i);
    p.changed_factor=string(field);
    p.changed_value=levels(i);
    rows{i}=p;
end
P=struct2table(vertcat(rows{:}));
end

function k=target_cells(model,target,domain,N,beta,barrier,curvature)
dx=(domain(3)-domain(1))/N;
dv=(domain(4)-domain(2))/N;
qx=sqrt(beta*barrier/curvature);
vv=sqrt(beta*barrier);
k=2*floor(min(qx/dx,vv/dv))+1;
while k>=3
    % Include up to half a cell of offset between xe and its center cell.
    q=0.5*(k+1)*dx; v=0.5*(k+1)*dv;
    energy=max(potential(model,target(1)+q), ...
        potential(model,target(1)-q))-potential(model,target(1)) ...
        +0.5*v^2;
    if energy<=beta*barrier, break; end
    k=k-2;
end
assert(k>=3,['Grid cannot contain a three-cell target belt at the ', ...
    'chosen energy fraction; increase discr or beta.']);
end

function V=potential(model,x)
switch char(model)
    case 'quadratic_cubic', V=0.5*x.^2-x.^3/3;
    case 'bistable_duffing', V=-0.5*x.^2+0.25*x.^4;
    case 'cosine_quadratic_drag', V=1-cos(x);
end
end

function S=make_schedule(P,seeds,model,alpha,stage)
rows=cell(height(P)*numel(seeds),1); n=0;
for i=1:height(P)
    for s=seeds
        n=n+1;
        r.profile_id=string(P.profile_id(i));
        r.seed=s;
        r.run_key=r.profile_id+"_seed_"+string(s);
        r.algorithm_seed=mod(s*1000003+i*7919,2^32-1);
        rows{n}=r;
    end
end
S=struct2table(vertcat(rows{:}));
state=rng; guard=onCleanup(@()rng(state)); %#ok<NASGU>
rng(mod(20260922+round(alpha*10000)+sum(double(model))+ ...
    sum(double(stage)),2^32-1),'twister');
S=S(randperm(height(S)),:);
S.execution_order=(1:height(S))';
end

function row=run_ga(p,par,target,weight,domain,Rref,key,seed,order)
values={p.tfinal,p.Ts,weight,1,1e-8,1e-8, ...
    p.number_of_steps,p.k,1001,0,0,domain,p.discr,1, ...
    1,2,40,p.rep_periodic,0.005,0,0,10000,40,5,9,3,8,2,5};
assert(numel(values)==29);
row=p;
row.run_key=key; row.seed=seed; row.execution_order=order;
row.R_hat=NaN; row.relative_error=NaN;
row.signed_error=NaN; row.wall_s=NaN;
row.trajectory_evaluations=NaN;
row.horizon_exhausted_proxy=NaN;
row.status="failed"; row.error_message="";
timer=tic;
try
    [R,out]=compute_LIM_FP(target,par,values{:});
    row.wall_s=toc(timer);
    row.R_hat=R;
    row.relative_error=abs(R-Rref)/Rref;
    row.signed_error=(R-Rref)/Rref;
    if isfield(out,'time_steps_sim')
        row.trajectory_evaluations=nnz(out.time_steps_sim(:)>0);
        row.horizon_exhausted_proxy=nnz( ...
            out.time_steps_sim(:)>=floor(p.tfinal/p.Ts));
    end
    if isfinite(R), row.status="ok";
    else, row.status="nonfinite"; end
catch ME
    row.wall_s=toc(timer);
    row.error_message=string(getReport(ME,'basic','hyperlinks','off'));
end
end

function T=summarize_runs(raw,diagSummary)
ids=unique(string(raw.profile_id),'stable');
rows=cell(numel(ids),1);
for i=1:numel(ids)
    g=raw(string(raw.profile_id)==ids(i),:);
    r.profile_id=ids(i);
    r.changed_factor=string(g.changed_factor(1));
    r.changed_value=g.changed_value(1);
    r.discr=g.discr(1); r.k=g.k(1); r.Ts=g.Ts(1);
    r.achieved_eta=g.achieved_eta(1);
    r.achieved_samples_per_period=g.achieved_samples_per_period(1);
    r.tfinal=g.tfinal(1); r.number_of_steps=g.number_of_steps(1);
    r.n_runs=height(g);
    r.n_success=nnz(string(g.status)=="ok");
    r.median_relative_error=median(g.relative_error,'omitnan');
    good=g.relative_error(isfinite(g.relative_error));
    if isempty(good), r.p95_relative_error=NaN;
    else, r.p95_relative_error=prctile(good,95); end
    r.within_1pct_rate=mean(g.relative_error<=0.01);
    signed=g.signed_error(isfinite(g.signed_error));
    if isempty(signed), r.unsafe_overestimate_rate=NaN;
    else, r.unsafe_overestimate_rate=mean(signed>0); end
    r.median_wall_s=median(g.wall_s,'omitnan');
    r.median_trajectory_evaluations= ...
        median(g.trajectory_evaluations,'omitnan');
    r.total_horizon_exhausted_proxy= ...
        sum(g.horizon_exhausted_proxy,'omitnan');
    d=diagSummary(diagSummary.profile_id==ids(i),:);
    r.false_safe_rate=d.false_safe_rate;
    r.false_unsafe_rate=d.false_unsafe_rate;
    r.classifier_unresolved_rate=d.classifier_unresolved_rate;
    r.truth_unresolved_rate=d.truth_unresolved_rate;
    r.diagnostic_wall_s=d.wall_s;
    rows{i}=r;
end
T=struct2table(vertcat(rows{:}));
end

function atomic_csv(T,pathName)
[folder,name,ext]=fileparts(pathName);
tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp);
movefile(tmp,pathName,'f');
end
