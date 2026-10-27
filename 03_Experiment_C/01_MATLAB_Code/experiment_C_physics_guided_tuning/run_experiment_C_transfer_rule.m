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
function outDir = run_experiment_C_transfer_rule(model,caseValue,stage,seeds,cfg,resumeDir)
%RUN_EXPERIMENT_C_TRANSFER_RULE Staged, reference-free DynIn GA transfer test.
% Only the caller's stage changes one parameter family. Original model,
% original compute_LIM_FP and type_x0=1 are retained. An unresolved path
% is not treated as validated non-target evidence in the pilot audit.

if nargin < 6, resumeDir = ''; end
model = validatestring(char(model),{'vdp_tmd','four_mass'});
stage = validatestring(char(stage), ...
    {'pilot','grid','Ts','periodic','budget','diagnostic','validate'});
validateattributes(caseValue,{'numeric'},{'scalar','finite'});
validateattributes(seeds,{'numeric'},{'vector','integer','positive','nonempty'});
seeds = unique(seeds(:)','stable');
if strcmp(stage,'validate')
    assert(numel(seeds)>=30 && isempty(intersect(seeds,1:10)), ...
        'Validation needs at least 30 seeds not used in screening (1:10).');
end
required = {'discr','k','Ts','tfinal','rep_periodic','number_of_steps'};
for j = 1:numel(required)
    assert(isfield(cfg,required{j}),'Missing cfg.%s.',required{j});
end
assert(cfg.k >= 3 && cfg.k == floor(cfg.k),'This study requires k >= 3.');
assert(cfg.discr > 10 && cfg.Ts > 0 && cfg.tfinal > 0);

here = fileparts(mfilename('fullpath'));
root = fullfile(fileparts(here),'work','DynIn','DynIn_v1.1.0');
funcDir = fullfile(root,'functions');
if strcmp(model,'vdp_tmd')
    modelDir = fullfile(root,'VanDerPolDuffing_NLTVA');
else
    modelDir = fullfile(root,'Chain_of_4_masses');
end
assert(isfile(fullfile(funcDir,'compute_LIM_FP.m')));
assert(isfile(fullfile(modelDir,'sistema.m')));
if isempty(resumeDir)
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    outDir = fullfile(here,['outputs_transfer_C_' model '_' stage '_' stamp]);
    mkdir(outDir);
else
    outDir = char(resumeDir);
    assert(isfolder(outDir),'Resume directory not found: %s',outDir);
end

oldPath = path;
cleanup = onCleanup(@() path(oldPath)); %#ok<NASGU>
restoredefaultpath;
rehash toolboxcache;
addpath(modelDir,'-begin');
addpath(funcDir,'-begin');
addpath(here,'-begin');
assert(strcmpi(which('compute_LIM_FP'),fullfile(funcDir,'compute_LIM_FP.m')));
assert(strcmpi(which('sistema'),fullfile(modelDir,'sistema.m')));

sys = build_system(model,caseValue);
if cfg.discr^numel(sys.target) > flintmax
    warning(['The original find_index uses double cell IDs; this ', ...
        '%d-D grid exceeds exact integer precision. Interpret ', ...
        'classification and transfer results cautiously.'],numel(sys.target));
end
configPath = fullfile(outDir,'run_configuration.mat');
if isfile(configPath)
    saved = load(configPath,'model','caseValue','stage','seeds','cfg');
    assert(strcmp(saved.model,model) && saved.caseValue==caseValue && ...
        strcmp(saved.stage,stage) && isequal(saved.seeds,seeds) && ...
        isequaln(saved.cfg,cfg), ...
        'Resume directory belongs to another model, stage or configuration.');
else
    save(configPath,'model','caseValue','stage','seeds','cfg');
end
if strcmp(stage,'pilot')
    run_pilot(sys,cfg,outDir);
    return
end
if strcmp(stage,'diagnostic')
    run_diagnostic(sys,cfg,outDir);
    return
end

profiles = make_profiles(model,stage,cfg);
profilePath = fullfile(outDir,'profiles.csv');
schedulePath = fullfile(outDir,'randomized_schedule.csv');
rawPath = fullfile(outDir,'raw_data_all_runs.csv');
if isfile(profilePath)
    saved = readtable(profilePath,'TextType','string');
    assert(isequaln(saved,profiles),'Resume profiles differ from saved profiles.');
else
    writetable(profiles,profilePath);
end

schedule = make_schedule(profiles,seeds,model,caseValue,stage);
if isfile(schedulePath)
    saved = readtable(schedulePath,'TextType','string');
    assert(isequaln(saved,schedule),'Resume schedule differs from saved schedule.');
else
    writetable(schedule,schedulePath);
end
if isfile(rawPath)
    raw = readtable(rawPath,'TextType','string');
    done = string(raw.run_key);
else
    raw = table();
    done = strings(0,1);
end
fprintf('Experiment C: %s / %s; %d runs; type_x0=1\n', ...
    model,stage,height(schedule));
fprintf('Output: %s\n',outDir);
for i = 1:height(schedule)
    key = string(schedule.run_key(i));
    if any(done == key), continue; end
    p = profiles(profiles.profile_id == schedule.profile_id(i),:);
    fprintf('[run %d/%d] START %s seed=%d\n',i,height(schedule), ...
        char(key),schedule.seed(i));
    rng(schedule.algorithm_seed(i),'twister');
    row = execute_run(sys,p,schedule.seed(i),key,i);
    if isempty(raw), raw = row; else, raw = [raw;row]; end %#ok<AGROW>
    atomic_csv(raw,rawPath);
    done(end+1,1) = key; %#ok<AGROW>
    fprintf('[run %d/%d] DONE R=%.6g, wall=%.2fs, status=%s\n', ...
        i,height(schedule),row.R_hat,row.wall_s,char(row.status));
end
summary = make_summary(raw);
writetable(summary,fullfile(outDir,'summary_by_profile.csv'));
fprintf('Raw: %s\nSummary: %s\n',rawPath, ...
    fullfile(outDir,'summary_by_profile.csv'));
end

function sys = build_system(model,value)
sys.model = string(model);
sys.case_value = value;
if strcmp(model,'vdp_tmd')
    [sys.par,~] = coefficients_VDPD_NLTVA(0.97,0.12,0.05,0.3,0,value);
    sys.target = zeros(1,4);
    sys.weight = [abs(sys.par(1)),1,abs(sys.par(13)),1];
    sys.lower = -3*ones(1,4);
    sys.upper = 3*ones(1,4);
else
    [sys.par,sys.weight,x0] = coefficients_chain_of_4_masses(value,0.05);
    assert(isstruct(sys.par),'Invalid four-mass parameter combination.');
    sys.target = zeros(1,8);
    extent = max(abs(x0));
    sys.lower = -5*extent*ones(1,8);
    sys.upper = 4*extent*ones(1,8);
end
assert(all(isfinite(sys.weight)) && all(sys.weight > 0));
end

function profiles = make_profiles(model,stage,cfg)
base = cfg;
switch stage
    case 'grid'
        if strcmp(model,'vdp_tmd'), levels = [351 701 1051];
        else, levels = [501 1001 1501]; end
        field = 'discr';
    case 'Ts'
        levels = cfg.Ts*[0.5 1 2]; field = 'Ts';
    case 'periodic'
        levels = [5 10 30]; field = 'rep_periodic';
    case 'budget'
        if strcmp(model,'vdp_tmd'), levels = [40 100 200];
        else, levels = [100 200 400]; end
        field = 'number_of_steps';
    otherwise
        levels = 1; field = 'frozen';
end
rows = cell(numel(levels),1);
for i = 1:numel(levels)
    p = base;
    if ~strcmp(field,'frozen'), p.(field) = levels(i); end
    p.profile_id = "P" + string(i);
    p.changed_factor = string(field);
    p.changed_value = levels(i);
    rows{i} = p;
end
profiles = struct2table(vertcat(rows{:}));
end

function schedule = make_schedule(profiles,seeds,model,value,stage)
rows = cell(height(profiles)*numel(seeds),1);
n = 0;
for i = 1:height(profiles)
    for s = seeds
        n = n+1;
        r.profile_id = string(profiles.profile_id(i));
        r.seed = s;
        r.run_key = r.profile_id + "_seed_" + string(s);
        r.algorithm_seed = mod(1000003*s+7919*i,2^32-1);
        rows{n} = r;
    end
end
schedule = struct2table(vertcat(rows{:}));
state = rng;
restore = onCleanup(@() rng(state)); %#ok<NASGU>
rng(mod(20260921+round(1000*value)+sum(double(model))+ ...
    sum(double(stage)),2^32-1),'twister');
schedule = schedule(randperm(height(schedule)),:);
schedule.execution_order = (1:height(schedule))';
end

function row = execute_run(sys,p,seed,key,order)
names = {'tfinal','Ts','weight','type_x0','reltol','abstol', ...
    'number_of_steps','num_of_cell_around_equilibrium','num_fig', ...
    'plot_results','plot_results_final','spaceboundary','discr', ...
    'automatic','var1','var2','rep_fix_point','rep_periodic', ...
    'min_periodic_radius','check_min_periodic','check_equilibrium', ...
    'max_check_step','divR','num_gen','num_crossover', ...
    'selected_opt','newcomers','num_almost_clones','bis_iter_max'};
values = {p.tfinal,p.Ts,sys.weight,1,1e-8,1e-8, ...
    p.number_of_steps,p.k,1001,0,0,[sys.lower sys.upper],p.discr, ...
    1,1,2,40,p.rep_periodic,0.005,1,0,10000,40,5,9,3,8,2,5};
assert(numel(names)==numel(values));
row = p;
row.case_value = sys.case_value;
row.seed = seed;
row.run_key = key;
row.execution_order = order;
row.R_hat = NaN;
row.wall_s = NaN;
row.trajectory_evaluations = NaN;
row.horizon_exhausted_proxy = NaN;
row.target_count = NaN;
row.non_target_count = NaN;
row.tail_change = NaN;
row.status = "failed";
row.error_message = "";
timer = tic;
try
    [row.R_hat,out] = compute_LIM_FP(sys.target,sys.par,values{:});
    row.wall_s = toc(timer);
    if isfield(out,'tipo')
        labels = out.tipo(:);
        row.trajectory_evaluations = numel(labels);
        row.target_count = nnz(labels==1);
        row.non_target_count = nnz(labels>=2 & labels<=4);
    end
    if isfield(out,'time_steps_sim')
        row.trajectory_evaluations = nnz(out.time_steps_sim(:)>0);
        row.horizon_exhausted_proxy = nnz( ...
            out.time_steps_sim(:)>=floor(p.tfinal/p.Ts));
    end
    if isfield(out,'R')
        trace = out.R(:);
        trace = trace(isfinite(trace));
        if numel(trace)>=2
            row.tail_change = abs(trace(end)-trace(max(1,end-9))) / ...
                max(abs(trace(end)),eps);
        end
    end
    if isfinite(row.R_hat), row.status = "ok";
    else, row.status = "nonfinite"; end
catch ME
    row.wall_s = toc(timer);
    row.error_message = string(getReport(ME,'basic','hyperlinks','off'));
end
end

function summary = make_summary(raw)
ids = unique(string(raw.profile_id),'stable');
rows = cell(numel(ids),1);
for i = 1:numel(ids)
    g = raw(string(raw.profile_id)==ids(i),:);
    r.profile_id = ids(i);
    r.changed_factor = string(g.changed_factor(1));
    r.changed_value = g.changed_value(1);
    r.n_runs = height(g);
    r.n_success = nnz(string(g.status)=="ok");
    r.median_R = median(g.R_hat,'omitnan');
    finiteR = g.R_hat(isfinite(g.R_hat));
    if isempty(finiteR)
        r.p05_R = NaN; r.p95_R = NaN;
    else
        r.p05_R = prctile(finiteR,5);
        r.p95_R = prctile(finiteR,95);
    end
    r.seed_spread = (r.p95_R-r.p05_R)/max(abs(r.median_R),eps);
    r.median_wall_s = median(g.wall_s,'omitnan');
    r.median_evaluations = median(g.trajectory_evaluations,'omitnan');
    r.total_horizon_exhausted_proxy = ...
        sum(g.horizon_exhausted_proxy,'omitnan');
    r.median_tail_change = median(g.tail_change,'omitnan');
    rows{i} = r;
end
summary = struct2table(vertcat(rows{:}));
end

function run_pilot(sys,cfg,outDir)
% Jacobian sets a starting horizon only. The pilot is not an LIM oracle.
dim = numel(sys.target);
J = zeros(dim);
for j = 1:dim
    h = 1e-6*max(1,abs(sys.target(j)));
    zp = sys.target; zm = zp;
    zp(j) = zp(j)+h; zm(j) = zm(j)-h;
    J(:,j) = (sistema(0,zp,sys.par)-sistema(0,zm,sys.par))/(2*h);
end

ev = eig(J);
rates = -real(ev(real(ev)<0));
assert(~isempty(rates),'No stable Jacobian rate was found.');
slowRate = min(rates);
fastOmega = max(abs(imag(ev)));
if fastOmega > 0
    TsJacobian = min(0.2,max(0.005,(2*pi/fastOmega)/20));
else
    TsJacobian = NaN;
end
maxPilotT = 4000;
if isfield(cfg,'pilot_max_T'), maxPilotT = cfg.pilot_max_T; end
pilotMultiplier = 1;
if isfield(cfg,'pilot_multiplier'), pilotMultiplier = cfg.pilot_multiplier; end
assert(maxPilotT>0 && pilotMultiplier>0);
T = pilotMultiplier*min(maxPilotT,max(200,ceil(8/slowRate/50)*50));
delta = (sys.upper-sys.lower)/cfg.discr;
rho = norm((0.5*cfg.k*delta).*sqrt(sys.weight));
state = rng;
restore = onCleanup(@() rng(state)); %#ok<NASGU>
rng(20260921,'twister');
dirs = randn(24,dim);
dirs = dirs./vecnorm(dirs,2,2);
radial = repmat([3;10;30],8,1);
rows = cell(size(dirs,1),1);
pointPath = fullfile(outDir,'pilot_point_labels.csv');
if isfile(pointPath)
    prior = readtable(pointPath,'TextType','string');
    for j = 1:height(prior)
        rows{prior.point_id(j)} = table2struct(prior(j,:));
    end
end
fprintf('Pilot %s: Jacobian slow rate %.4g, T=%g, 2T=%g\n', ...
    char(sys.model),slowRate,T,2*T);
for i = 1:size(dirs,1)
    if ~isempty(rows{i}), continue; end
    d = dirs(i,:)./sqrt(sys.weight);
    z0 = sys.target + radial(i)*rho*d;
    z0 = min(max(z0,sys.lower+eps),sys.upper-eps);
    timer = tic;
    statusT = "unresolved"; status2T = "unresolved";
    finalDistanceT = NaN; finalDistance2T = NaN;
    try
        opts = odeset('RelTol',1e-10,'AbsTol',1e-11, ...
            'Events',@(t,z) escape_event(t,z,sys.lower,sys.upper));
        [t,z,te] = ode45(@(t,x) sistema(t,x,sys.par),[0 T 2*T],z0,opts);
        if ~isempty(te) && te(1)<T
            statusT = "escaped"; status2T = "escaped";
        else
            atT = interp1(t,z,T,'linear');
            finalDistanceT = norm((atT-sys.target).*sqrt(sys.weight));
            if finalDistanceT<=rho, statusT = "target"; end
            if ~isempty(te)
                status2T = "escaped";
            else
                finalDistance2T = norm((z(end,:)-sys.target).*sqrt(sys.weight));
                if finalDistance2T<=rho, status2T = "target"; end
            end
        end
        errorText = "";
    catch ME
        errorText = string(ME.message);
    end
    r.point_id = i;
    r.shell_multiplier = radial(i);
    r.status_T = statusT;
    r.status_2T = status2T;
    r.distance_T = finalDistanceT;
    r.distance_2T = finalDistance2T;
    r.wall_s = toc(timer);
    r.error_message = errorText;
    rows{i} = r;
    fprintf('[pilot %d/%d] %s -> %s, %.2fs\n', ...
        i,numel(rows),char(statusT),char(status2T),r.wall_s);
    atomic_csv(struct2table(vertcat(rows{1:i})),pointPath);
end
pilot = struct2table(vertcat(rows{:}));
outer = pilot.shell_multiplier>=10;
pass = any(pilot.status_2T(outer)=="target") && ...
    all(pilot.status_T==pilot.status_2T) && ...
    ~any(strlength(pilot.error_message)>0);
audit = table(string(sys.model),sys.case_value,slowRate,TsJacobian,T,2*T,rho, ...
    nnz(pilot.status_T=="target"),nnz(pilot.status_2T=="target"), ...
    nnz(pilot.status_2T=="unresolved"),sum(pilot.wall_s),pass, ...
    'VariableNames',{'model','case_value','jacobian_slow_rate', ...
    'Ts_jacobian_start','T', ...
    'two_T','target_radius','target_at_T','target_at_2T', ...
    'unresolved_at_2T','pilot_wall_s','pilot_pass'});
writetable(audit,fullfile(outDir,'pilot_audit.csv'));
if ~pass
    warning(['Pilot did not pass. Do not freeze tfinal from it. ', ...
        'Add inner/near-boundary probes or extend the horizon.']);
end
end

function [value,isterminal,direction] = escape_event(~,z,lower,upper)
value = min([z(:)'-lower,upper-z(:)']);
isterminal = 1;
direction = -1;
end

function atomic_csv(T,pathName)
[folder,name,ext] = fileparts(pathName);
tmp = fullfile(folder,[name '_writing' ext]);
writetable(T,tmp);
movefile(tmp,pathName,'f');
end
