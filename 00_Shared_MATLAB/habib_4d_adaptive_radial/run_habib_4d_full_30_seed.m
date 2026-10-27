% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Proposed-method implementation, comparison, or supporting model code.
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
%% Full 30-seed Habib 4D comparison with randomized execution order
% Primary cost measures: trajectory queries and integrations.
% Secondary cost measure: median runtime after randomized execution.

clear;
clc;

scriptDirectory = fileparts(mfilename('fullpath'));
addpath(scriptDirectory,'-begin');

runMode = "full";
mu1Values = 0.075;
seedList = 1:30;

% Resume the completed experiment and rerun only unsuccessful records.
% Set this back to "" when starting a completely new 30-seed experiment.
resumeDirectory = "C:\Users\-qian-\Documents\Codex\2026-06-28\github\habib_4d_adaptive_radial\outputs_habib_4d_20260925_050739_743";

outputDirectory = run_habib_4d_adaptive_radial_benchmark( ...
    runMode,mu1Values,seedList,resumeDirectory);

rawPath = fullfile(outputDirectory,'raw_data_all_runs.csv');
summaryPath = fullfile(outputDirectory,'summary_by_method.csv');
pairedPath = fullfile(outputDirectory,'paired_contrasts_by_seed.csv');
raw = readtable(rawPath,'TextType','string');
summary = readtable(summaryPath,'TextType','string');
paired = readtable(pairedPath,'TextType','string');

expectedMethods = ["fixed_s3_radial_24"; ...
    "adaptive_s3_radial"; ...
    "adaptive_s3_with_trajectory_reuse"];
expectedRuns = numel(seedList)*numel(expectedMethods)*numel(mu1Values);

assert(height(raw)==expectedRuns, ...
    'Expected %d completed runs, but found %d.',expectedRuns,height(raw));
failed = raw.success~=1 | ~isfinite(raw.R_hat);
if any(failed)
    disp(raw(failed,{'execution_order','seed','method','stop_status', ...
        'query_count','integration_count','algorithm_runtime_s', ...
        'error_message'}));
    error(['At least one run has no finite result. Rerun this script ' ...
        'with the same resumeDirectory to retry only those rows.']);
end
assert(all(logical(raw.direction_budget_respected)), ...
    'At least one run exceeded the strict direction budget.');

for i = 1:numel(expectedMethods)
    methodRows = raw(string(raw.method)==expectedMethods(i),:);
    assert(height(methodRows)==numel(seedList), ...
        'Method %s does not contain all 30 seeds.',char(expectedMethods(i)));
    assert(numel(unique(methodRows.seed))==numel(seedList), ...
        'Method %s contains duplicate or missing seeds.',char(expectedMethods(i)));
end

fprintf('\nAll %d randomized runs completed and passed integrity checks.\n', ...
    expectedRuns);
fprintf('Primary cost comparison: query_count and integration_count.\n');
fprintf('Runtime comparison: median_algorithm_runtime_s.\n');
fprintf('Output directory:\n%s\n\n',outputDirectory);

disp(summary(:,{'method','n_runs','median_R_hat','median_queries', ...
    'median_integrations','median_algorithm_runtime_s', ...
    'direction_limit_fraction','converged_fraction', ...
    'audit_pass_fraction'}));
disp(paired);

