%% Pilot: strict direction budget for Habib's 4D model
% This pilot creates a fresh output folder. It does not resume or overwrite
% the earlier run made before the strict direction-cap correction.

clear;
clc;

runMode = "pilot";
mu1Values = 0.075;
seedList = 1:3;
resumeDirectory = "";

outputDirectory = run_habib_4d_adaptive_radial_benchmark( ...
    runMode,mu1Values,seedList,resumeDirectory);

rawPath = fullfile(outputDirectory,'raw_data_all_runs.csv');
raw = readtable(rawPath,'TextType','string');

if any(~logical(raw.direction_budget_respected))
    bad = raw(~logical(raw.direction_budget_respected), ...
        {'seed','method','direction_count','direction_budget','stop_status'});
    disp(bad);
    error('The strict direction budget was exceeded.');
end

adaptive = raw(startsWith(string(raw.method),'adaptive_'), ...
    {'seed','method','R_hat','stop_status','direction_count', ...
    'direction_budget','query_count','post_audit_pass'});

fprintf('\nDirection-budget check passed for all %d runs.\n',height(raw));
fprintf('Pilot output:\n%s\n\n',outputDirectory);
disp(adaptive);

