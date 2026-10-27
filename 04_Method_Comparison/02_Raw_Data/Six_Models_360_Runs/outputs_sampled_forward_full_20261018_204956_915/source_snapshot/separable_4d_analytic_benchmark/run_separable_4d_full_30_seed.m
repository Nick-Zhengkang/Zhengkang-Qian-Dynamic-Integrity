%% Full 30-seed comparison on the separable 4D analytical benchmark

clear;
clc;

scriptDirectory = fileparts(mfilename('fullpath'));
addpath(scriptDirectory,'-begin');

runMode = "full";
alphaQC = 0.4;
alphaBD = 0.7;
seedList = 1:30;
resumeDirectory = "";

outputDirectory = run_separable_4d_analytic_benchmark( ...
    runMode,alphaQC,alphaBD,seedList,resumeDirectory);

raw = readtable(fullfile(outputDirectory,'raw_data_all_runs.csv'), ...
    'TextType','string');
summary = readtable(fullfile(outputDirectory,'summary_by_method.csv'), ...
    'TextType','string');

expectedMethods = ["fixed_s3_radial_24"; ...
    "adaptive_s3_radial"; ...
    "adaptive_s3_with_trajectory_reuse"];
expectedRuns = numel(seedList)*numel(expectedMethods);

assert(height(raw)==expectedRuns, ...
    'Expected %d runs, but found %d.',expectedRuns,height(raw));
assert(all(raw.success==1 & isfinite(raw.R_hat)), ...
    'At least one run failed. Inspect error_message in the raw CSV.');
assert(all(logical(raw.direction_budget_respected)), ...
    'At least one run exceeded the common direction budget.');

for i=1:numel(expectedMethods)
    rows = raw(string(raw.method)==expectedMethods(i),:);
    assert(height(rows)==numel(seedList) && ...
        numel(unique(rows.seed))==numel(seedList), ...
        'Method %s has missing or duplicate seeds.',expectedMethods(i));
end

fprintf('\nAll %d randomized runs passed integrity checks.\n',expectedRuns);
fprintf('Exact benchmark LIM: %.12g\n',raw.R_reference(1));
fprintf('Output directory:\n%s\n\n',outputDirectory);
disp(summary(:,{'method','median_R_hat','median_relative_error', ...
    'p95_relative_error','within_1_percent_fraction', ...
    'within_2_percent_fraction','within_5_percent_fraction', ...
    'median_queries','median_integrations', ...
    'median_algorithm_runtime_s','audit_pass_fraction'}));
