clear; clc; close all;

%% Fixed hyperparameter LIM-alpha comparison, original DynIn pure GA
% Model:
%   x'' + alpha*abs(x')*x' + x - x^2 = 0
%
% Hyperparameter combination extracted from the revised report:
%   spaceboundary = [-1.0 -1.0 1.0 1.0]
%   discr = 169
%   num_of_cell_around_equilibrium = 15
%   number_of_steps = 100
%   Ts = 0.2
%   num_gen = 10
%   type_x0 = 1, pure GA

%% User controls
originalFunctionsDir = 'C:\Users\-qian-\Documents\Codex\2026-06-28\github\work\DynIn\DynIn_v1.1.0\functions';

alpha_list = linspace(0.05, 2.0, 16);

spaceboundary = [-1.0 -1.0 1.0 1.0];
discr = 169;
num_of_cell_around_equilibrium = 15;
number_of_steps = 100;
Ts = 0.2;
num_gen = 10;

tfinal = 1000;
xe0 = [0 0];
automatic = 1;
rng_base = 20260719;

%% Locate original DynIn functions
if ~exist(fullfile(originalFunctionsDir,'compute_LIM_FP.m'),'file')
    fprintf('\nCannot find compute_LIM_FP.m at:\n%s\n\n', originalFunctionsDir);
    selectedDir = uigetdir(pwd,'Select original DynIn functions folder');
    if isequal(selectedDir,0) || ~exist(fullfile(selectedDir,'compute_LIM_FP.m'),'file')
        error('Cannot find original DynIn compute_LIM_FP.m.');
    end
    originalFunctionsDir = selectedDir;
end

restoredefaultpath;
rehash toolboxcache;
addpath(originalFunctionsDir,'-begin');

computePath = which('compute_LIM_FP');
simulationPath = which('simulation_DI');
fprintf('Using original DynIn functions folder:\n%s\n\n', originalFunctionsDir);
fprintf('compute_LIM_FP:\n%s\n', computePath);
fprintf('simulation_DI:\n%s\n\n', simulationPath);

if isempty(computePath) || contains(lower(computePath),'adaptive')
    error('compute_LIM_FP path is not the original DynIn function. Check MATLAB path.');
end

%% Create local sistema.m for the quadratic-cubic oscillator
scriptRoot = fileparts(mfilename('fullpath'));
if isempty(scriptRoot)
    scriptRoot = pwd;
end

modelDir = fullfile(scriptRoot,'test_model_quadratic_cubic');
if ~isfolder(modelDir)
    mkdir(modelDir);
end

sistemaPath = fullfile(modelDir,'sistema.m');
fid = fopen(sistemaPath,'w');
fprintf(fid, 'function xprime = sistema(~, x, par)\n');
fprintf(fid, '    xprime = zeros(2,1);\n');
fprintf(fid, '    xprime(1) = x(2);\n');
fprintf(fid, '    xprime(2) = -par.alpha * abs(x(2)) * x(2) - x(1) + x(1)^2;\n');
fprintf(fid, 'end\n');
fclose(fid);
addpath(modelDir,'-begin');
fprintf('sistema:\n%s\n\n', which('sistema'));

%% Output folder
outDir = fullfile(scriptRoot,'outputs_fixed_hyperparameter_LIM_alpha_pure_GA_original');
if ~isfolder(outDir)
    mkdir(outDir);
end

%% Analytical reference
R_ref = zeros(size(alpha_list));
for ia = 1:numel(alpha_list)
    R_ref(ia) = quadratic_cubic_reference_LIM(alpha_list(ia));
end

%% Algorithm parameters
args = struct();
args.type_x0 = 1;
args.tfinal = tfinal;
args.Ts = Ts;
args.weight = ones(1,2);
args.number_of_steps = number_of_steps;
args.num_of_cell_around_equilibrium = num_of_cell_around_equilibrium;
args.plot_results = 0;
args.plot_results_final = 0;
args.automatic = automatic;
args.spaceboundary = spaceboundary;
args.discr = discr;
args.reltol = 1e-8;
args.abstol = 1e-8;
args.check_equilibrium = 1;
args.rep_fix_point = 40;
args.rep_periodic = 10;
args.min_periodic_radius = 0.005;
args.check_min_periodic = 0;
args.num_gen = num_gen;
args.num_crossover = 9;
args.selected_opt = 3;
args.newcomers = 8;
args.num_almost_clones = 2;
args.bis_iter_max = 5;

%% Run fixed-parameter LIM-alpha curve
R_num = NaN(size(alpha_list));
runtime = NaN(size(alpha_list));

fprintf('\nFixed hyperparameter combination:\n');
fprintf('spaceboundary = [%.3g %.3g %.3g %.3g]\n', spaceboundary);
fprintf('discr = %d\n', discr);
fprintf('num_of_cell_around_equilibrium = %d\n', num_of_cell_around_equilibrium);
fprintf('number_of_steps = %d\n', number_of_steps);
fprintf('Ts = %.6g\n', Ts);
fprintf('num_gen = %d\n\n', num_gen);

for ia = 1:numel(alpha_list)
    alpha = alpha_list(ia);
    par.alpha = alpha;

    rng(rng_base + ia);
    fprintf('Run %2d/%2d: alpha = %.5f ... ', ia, numel(alpha_list), alpha);

    tStart = tic;
    try
        [R_final,OutL] = call_compute_LIM_FP_original(xe0,par,args);
        R_num(ia) = R_final;
        if isfield(OutL,'total_time') && isfinite(OutL.total_time)
            runtime(ia) = OutL.total_time;
        else
            runtime(ia) = toc(tStart);
        end
        fprintf('R_num = %.8f, R_ref = %.8f, abs err = %.3e, time = %.2fs\n', ...
            R_num(ia), R_ref(ia), abs(R_num(ia)-R_ref(ia)), runtime(ia));
    catch ME
        runtime(ia) = toc(tStart);
        fprintf('FAILED: %s\n', ME.message);
    end
end

[R2_raw,mae,rmse] = fit_metrics(R_num,R_ref);
total_runtime = nansum_local(runtime);

fprintf('\nSummary:\n');
fprintf('raw R2 = %.8f\n', R2_raw);
fprintf('MAE    = %.8f\n', mae);
fprintf('RMSE   = %.8f\n', rmse);
fprintf('total runtime = %.2fs\n\n', total_runtime);

%% Figures
figCurve = figure('Color','w','Name','fixed_hyperparameter_LIM_alpha_curve','Position',[80 120 1500 650]);
plot(alpha_list,R_ref,'k-','LineWidth',2.4); hold on;
plot(alpha_list,R_num,'o-','LineWidth',1.8,'MarkerSize',7);
grid on; box on;
xlabel('\alpha');
ylabel('LIM');
title(sprintf('LIM-alpha comparison, pure GA, discr=%d, eq cells=%d, steps=%d, Ts=%.3g, num\\_gen=%d', ...
    discr,num_of_cell_around_equilibrium,number_of_steps,Ts,num_gen));
legend({'Analytical reference','Numerical DynIn LIM'},'Location','best');
curvePath = fullfile(outDir,'fixed_hyperparameter_LIM_alpha_curve.png');
saveas(figCurve,curvePath);

figErr = figure('Color','w','Name','fixed_hyperparameter_LIM_alpha_error','Position',[80 120 1500 650]);
plot(alpha_list,abs(R_num-R_ref),'o-','LineWidth',1.8,'MarkerSize',7);
grid on; box on;
xlabel('\alpha');
ylabel('|R_{num} - R_{ref}|');
title(sprintf('Absolute LIM error, R^2 = %.5f, RMSE = %.5f', R2_raw, rmse));
errPath = fullfile(outDir,'fixed_hyperparameter_LIM_alpha_abs_error.png');
saveas(figErr,errPath);

figRuntime = figure('Color','w','Name','fixed_hyperparameter_runtime_by_alpha','Position',[80 120 1500 650]);
plot(alpha_list,runtime,'o-','LineWidth',1.8,'MarkerSize',7);
grid on; box on;
xlabel('\alpha');
ylabel('runtime (s)');
title(sprintf('Runtime by alpha, total runtime = %.2fs', total_runtime));
runtimePath = fullfile(outDir,'fixed_hyperparameter_runtime_by_alpha.png');
saveas(figRuntime,runtimePath);

%% Save results and HTML report
results = struct();
results.alpha_list = alpha_list;
results.spaceboundary = spaceboundary;
results.discr = discr;
results.num_of_cell_around_equilibrium = num_of_cell_around_equilibrium;
results.number_of_steps = number_of_steps;
results.Ts = Ts;
results.num_gen = num_gen;
results.tfinal = tfinal;
results.R_ref = R_ref;
results.R_num = R_num;
results.runtime = runtime;
results.R2_raw = R2_raw;
results.mae = mae;
results.rmse = rmse;
results.total_runtime = total_runtime;
results.args = args;
results.originalFunctionsDir = originalFunctionsDir;
results.computePath = computePath;
results.simulationPath = simulationPath;

matPath = fullfile(outDir,'fixed_hyperparameter_LIM_alpha_results.mat');
save(matPath,'results');

csvPath = fullfile(outDir,'fixed_hyperparameter_LIM_alpha_results.csv');
T = table(alpha_list(:),R_ref(:),R_num(:),abs(R_num(:)-R_ref(:)),runtime(:), ...
    'VariableNames',{'alpha','R_ref','R_num','abs_error','runtime'});
writetable(T,csvPath);

htmlPath = fullfile(outDir,'fixed_hyperparameter_LIM_alpha_report.html');
write_fixed_html_report(htmlPath,curvePath,errPath,runtimePath,results);

fprintf('Done.\n');
fprintf('Curve figure:\n%s\n',curvePath);
fprintf('Error figure:\n%s\n',errPath);
fprintf('Runtime figure:\n%s\n',runtimePath);
fprintf('HTML report:\n%s\n',htmlPath);
fprintf('CSV results:\n%s\n',csvPath);
fprintf('MAT results:\n%s\n',matPath);

%% Local functions
function [R_final,OutL,OutH] = call_compute_LIM_FP_original(xe0,par,args)
    vals = struct_to_original_optional_order(args,xe0);
    [R_final,OutL,OutH] = compute_LIM_FP(xe0,par,vals{:});
end

function vals = struct_to_original_optional_order(args,xe0)
    dim = numel(xe0);
    defaults = struct();
    defaults.tfinal = 1000;
    defaults.Ts = 0.05;
    defaults.weight = ones(1,dim);
    defaults.type_x0 = 1;
    defaults.reltol = 1e-6;
    defaults.abstol = 1e-6;
    defaults.number_of_steps = 50;
    defaults.num_of_cell_around_equilibrium = 3;
    defaults.num_fig = round(rand*10000);
    defaults.plot_results = 1;
    defaults.plot_results_final = 0;
    defaults.spaceboundary = [xe0-10,xe0+10];
    defaults.discr = 1001;
    defaults.automatic = 0;
    defaults.var1 = 1;
    defaults.var2 = 2;
    defaults.rep_fix_point = 40;
    defaults.rep_periodic = 10;
    defaults.min_periodic_radius = 0.005;
    defaults.check_min_periodic = 0;
    defaults.check_equilibrium = 1;
    defaults.max_check_step = 10000;
    defaults.divR = 40;
    defaults.num_gen = 5;
    defaults.num_crossover = 9;
    defaults.selected_opt = 3;
    defaults.newcomers = 8;
    defaults.num_almost_clones = 2;
    defaults.bis_iter_max = 5;

    f = fieldnames(args);
    for k = 1:numel(f)
        if isfield(defaults,f{k})
            defaults.(f{k}) = args.(f{k});
        end
    end

    order = {'tfinal','Ts','weight','type_x0','reltol','abstol','number_of_steps', ...
        'num_of_cell_around_equilibrium','num_fig','plot_results','plot_results_final', ...
        'spaceboundary','discr','automatic','var1','var2','rep_fix_point','rep_periodic', ...
        'min_periodic_radius','check_min_periodic','check_equilibrium','max_check_step', ...
        'divR','num_gen','num_crossover','selected_opt','newcomers','num_almost_clones','bis_iter_max'};

    vals = cell(size(order));
    for k = 1:numel(order)
        vals{k} = defaults.(order{k});
    end
end

function [R2_raw,mae,rmse] = fit_metrics(R_num,R_ref)
    R_num = real(R_num(:));
    R_ref = real(R_ref(:));
    valid = isfinite(R_num) & isfinite(R_ref);
    R_num = R_num(valid);
    R_ref = R_ref(valid);
    if numel(R_num) < 2
        R2_raw = NaN; mae = NaN; rmse = NaN;
        return
    end
    SSres = sum((R_num-R_ref).^2);
    SStot = sum((R_ref-mean(R_ref)).^2);
    R2_raw = 1 - SSres/SStot;
    mae = mean(abs(R_num-R_ref));
    rmse = sqrt(mean((R_num-R_ref).^2));
end

function R = quadratic_cubic_reference_LIM(alpha)
    alpha = double(alpha);
    if alpha <= 0
        error('alpha must be positive.');
    end

    r_int = interior_radius(alpha);
    if alpha < 1
        r_end = endpoint_radius(alpha);
        R = min(r_end,r_int);
    else
        R = r_int;
    end
end

function r = interior_radius(alpha)
    f = @(x) alpha*p_plus_branch(x,alpha) - x.^2;
    xs = linspace(1e-8,1-1e-8,600);
    fs = arrayfun(f,xs);
    idx = find(fs(1:end-1).*fs(2:end) <= 0,1,'first');
    if isempty(idx)
        [~,idx0] = min(abs(fs));
        xstar = xs(idx0);
    else
        xstar = fzero(f,[xs(idx),xs(idx+1)]);
    end
    pstar = p_plus_branch(xstar,alpha);
    r = sqrt(xstar.^2 + pstar);
end

function r = endpoint_radius(alpha)
    f = @(x) p_plus_branch(x,alpha);
    xs = linspace(-4,-1e-8,1200);
    fs = arrayfun(f,xs);
    idx = find(fs(1:end-1).*fs(2:end) <= 0,1,'last');
    if isempty(idx)
        [~,idx0] = min(abs(fs));
        xL = xs(idx0);
    else
        xL = fzero(f,[xs(idx),xs(idx+1)]);
    end
    r = -xL;
end

function p = p_plus_branch(x,alpha)
    k = 2*alpha;
    A = (2*x.^2 - 2*x)/k + (-4*x + 2)/k^2 + 4/k^3;
    A1 = -2/k^2 + 4/k^3;
    p = A - exp(k*(1-x))*A1;
end

function s = nansum_local(x,dim)
    if nargin < 2
        dim = 1;
    end
    x(~isfinite(x)) = 0;
    s = sum(x,dim);
end

function write_fixed_html_report(htmlPath,curvePath,errPath,runtimePath,results)
    fid = fopen(htmlPath,'w');
    if fid < 0
        warning('Could not write HTML report.');
        return
    end
    cleaner = onCleanup(@() fclose(fid));

    [~,curveName,curveExt] = fileparts(curvePath);
    [~,errName,errExt] = fileparts(errPath);
    [~,runtimeName,runtimeExt] = fileparts(runtimePath);
    curveFile = [curveName curveExt];
    errFile = [errName errExt];
    runtimeFile = [runtimeName runtimeExt];

    fprintf(fid,'<!doctype html><html><head><meta charset="utf-8"><title>Fixed hyperparameter LIM-alpha report</title>');
    fprintf(fid,'<style>body{font-family:Arial,Helvetica,sans-serif;margin:28px;line-height:1.45;color:#222} ');
    fprintf(fid,'table{border-collapse:collapse;margin:16px 0}td,th{border:1px solid #ccc;padding:6px 10px;text-align:right} ');
    fprintf(fid,'th{background:#f4f4f4} img{max-width:100%%;border:1px solid #ddd;margin:10px 0 26px 0}</style></head><body>');
    fprintf(fid,'<h1>Fixed hyperparameter LIM-alpha comparison</h1>');
    fprintf(fid,'<p>Original DynIn uniform-cell algorithm with pure GA initial-condition selection, type_x0 = 1.</p>');
    fprintf(fid,'<h2>Hyperparameters</h2><table>');
    fprintf(fid,'<tr><th>spaceboundary</th><td>[%.3g %.3g %.3g %.3g]</td></tr>',results.spaceboundary);
    fprintf(fid,'<tr><th>discr</th><td>%d</td></tr>',results.discr);
    fprintf(fid,'<tr><th>num_of_cell_around_equilibrium</th><td>%d</td></tr>',results.num_of_cell_around_equilibrium);
    fprintf(fid,'<tr><th>number_of_steps</th><td>%d</td></tr>',results.number_of_steps);
    fprintf(fid,'<tr><th>Ts</th><td>%.6g</td></tr>',results.Ts);
    fprintf(fid,'<tr><th>num_gen</th><td>%d</td></tr>',results.num_gen);
    fprintf(fid,'</table>');
    fprintf(fid,'<h2>Summary</h2><table>');
    fprintf(fid,'<tr><th>raw R^2</th><td>%.8f</td></tr>',results.R2_raw);
    fprintf(fid,'<tr><th>MAE</th><td>%.8f</td></tr>',results.mae);
    fprintf(fid,'<tr><th>RMSE</th><td>%.8f</td></tr>',results.rmse);
    fprintf(fid,'<tr><th>total runtime s</th><td>%.2f</td></tr>',results.total_runtime);
    fprintf(fid,'</table>');
    fprintf(fid,'<p><b>Original compute_LIM_FP:</b><br><code>%s</code></p>',results.computePath);
    fprintf(fid,'<h2>Per-alpha results</h2><table><tr><th>alpha</th><th>R_ref</th><th>R_num</th><th>abs error</th><th>runtime s</th></tr>');
    for i = 1:numel(results.alpha_list)
        fprintf(fid,'<tr><td>%.6f</td><td>%.8f</td><td>%.8f</td><td>%.8f</td><td>%.2f</td></tr>', ...
            results.alpha_list(i),results.R_ref(i),results.R_num(i), ...
            abs(results.R_num(i)-results.R_ref(i)),results.runtime(i));
    end
    fprintf(fid,'</table>');
    fprintf(fid,'<h2>Figures</h2>');
    fprintf(fid,'<h3>LIM-alpha curve</h3><img src="%s">',curveFile);
    fprintf(fid,'<h3>Absolute error</h3><img src="%s">',errFile);
    fprintf(fid,'<h3>Runtime by alpha</h3><img src="%s">',runtimeFile);
    fprintf(fid,'</body></html>');
end
