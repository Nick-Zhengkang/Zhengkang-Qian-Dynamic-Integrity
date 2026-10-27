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
function run_diagnostic(sys,cfg,outDir)
% Fixed-point classification audit independent of GA's stored-cell history.
% Only a long-horizon domain escape is confirmed non-target. Bounded
% trajectories away from the target remain unresolved, not false-safe.
dim = numel(sys.target);
dh = (sys.upper-sys.lower)/cfg.discr;
cellPos = zeros(cfg.discr,dim);
for j = 1:dim
    cellPos(:,j) = sys.lower(j)+dh(j)/2+(0:cfg.discr-1)'*dh(j);
end
centerCell = zeros(dim,1);
for j = 1:dim
    [~,centerCell(j)] = min(abs(cellPos(:,j)-sys.target(j)));
end
targetCells = [find_index(centerCell,dim,cfg.discr); ...
    find_cells_around_a_cell(dim,centerCell,cfg.discr,cfg.k)];
state = rng;
restore = onCleanup(@() rng(state)); %#ok<NASGU>
rng(20260922,'twister');
dirs = randn(24,dim);
dirs = dirs./vecnorm(dirs,2,2);
rho = norm((0.5*cfg.k*dh).*sqrt(sys.weight));
shell = repmat([3;10;30],8,1);
rows = cell(numel(shell),1);
pointPath = fullfile(outDir,'diagnostic_points.csv');
if isfile(pointPath)
    prior = readtable(pointPath,'TextType','string');
    for j = 1:height(prior)
        rows{prior.point_id(j)} = table2struct(prior(j,:));
    end
end
for i = 1:numel(shell)
    if ~isempty(rows{i}), continue; end
    d = dirs(i,:)./sqrt(sys.weight);
    z0 = sys.target+shell(i)*rho*d;
    z0 = min(max(z0,sys.lower+eps),sys.upper-eps);
    timer = tic;
    try
        [~,~,~,tipo] = simulation_DI(dim,sys.par,z0,cfg.tfinal,cfg.Ts, ...
            [1e-8 1e-8],[sys.lower sys.upper],cfg.discr, ...
            targetCells,[],[],cellPos,dh,40,cfg.rep_periodic, ...
            0.005,1,sys.weight);
        classifierError = "";
    catch ME
        tipo = NaN;
        classifierError = string(ME.message);
    end
    try
        opts = odeset('RelTol',1e-10,'AbsTol',1e-11, ...
            'Events',@(t,z) escape_event(t,z,sys.lower,sys.upper));
        [~,z,te] = ode45(@(t,x) sistema(t,x,sys.par), ...
            [0 4*cfg.tfinal],z0,opts);
        if ~isempty(te)
            truth = "escaped";
        elseif norm((z(end,:)-sys.target).*sqrt(sys.weight))<=rho
            truth = "target";
        else
            truth = "unresolved";
        end
        referenceError = "";
    catch ME
        truth = "failed";
        referenceError = string(ME.message);
    end
    r.point_id = i;
    r.shell_multiplier = shell(i);
    r.dynin_tipo = tipo;
    r.long_horizon_label = truth;
    r.false_safe = double(truth=="escaped" && tipo==1);
    r.false_unsafe = double(truth=="target" && ismember(tipo,[2 3 4]));
    r.wall_s = toc(timer);
    r.classifier_error = classifierError;
    r.reference_error = referenceError;
    rows{i} = r;
    fprintf('[diagnostic %d/%d] DynIn=%g; long=%s; %.2fs\n', ...
        i,numel(rows),tipo,char(truth),r.wall_s);
    atomic_csv(struct2table(vertcat(rows{1:i})),pointPath);
end
D = struct2table(vertcat(rows{:}));
S = table(nnz(D.long_horizon_label=="escaped"), ...
    nnz(D.long_horizon_label=="target"), ...
    nnz(D.long_horizon_label=="unresolved"), ...
    sum(D.false_safe),sum(D.false_unsafe),sum(D.wall_s), ...
    'VariableNames',{'confirmed_escape','confirmed_target', ...
    'unresolved','false_safe_count','false_unsafe_count','wall_s'});
writetable(S,fullfile(outDir,'diagnostic_summary.csv'));
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
