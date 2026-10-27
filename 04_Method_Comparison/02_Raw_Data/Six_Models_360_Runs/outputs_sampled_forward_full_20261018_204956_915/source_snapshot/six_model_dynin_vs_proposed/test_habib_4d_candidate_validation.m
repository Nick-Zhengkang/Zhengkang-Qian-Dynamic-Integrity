%% Independent validation of the Habib 4D proposed-method candidate
% This supplementary test does not rerun or modify the search algorithm.
% It reads the saved best rays from the six-model pilot and validates the
% corresponding initial conditions with a different ODE solver, stricter
% tolerances, longer horizons, and an expanded escape domain.

clear;
clc;

scriptDirectory = fileparts(mfilename('fullpath'));
addpath(scriptDirectory,'-begin');

sixModelOutputDirectory = [ ...
    "C:\Users\-qian-\Documents\Codex\2026-06-28\github\" + ...
    "six_model_dynin_vs_proposed\" + ...
    "outputs_six_model_20260925_223949_354"];

% Leave empty to validate every available adaptive-angle seed. For the
% current pilot this automatically selects seeds 1:3.
seedList = [];

validationOutputDirectory = run_habib_4d_candidate_validation( ...
    sixModelOutputDirectory,seedList);

fprintf('\nIndependent validation output:\n%s\n', ...
    validationOutputDirectory);

