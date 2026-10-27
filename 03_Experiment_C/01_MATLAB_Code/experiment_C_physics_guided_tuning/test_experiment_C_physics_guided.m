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
%% Experiment C: physics-guided DynIn GA tuning
% Edit only the three lines in the USER SETTINGS section.
% The original DynIn source is called unchanged with type_x0 = 1.

clear; clc;

%% USER SETTINGS
benchmark_name = 'habib_vdp_tmd';
phase = 'screening';
seed_list = 1:10;

% Available models:
%   'quadratic_cubic'
%   'bistable_duffing'
%   'cosine_quadratic_drag'
%   'tilted_washboard'
%   'habib_vdp_tmd'          - Habib 4-D Duffing-VdP + NLTVA benchmark
%
% Available phases:
%   'screening'    - 10 seeds; cumulative parameter blocks and N=50/100/200
%   'confirmation' - 30 seeds; only frozen physics profiles N=50/100/200
%   'smoke'        - one seed and first case for a quick installation check
%   'design'       - write estimated parameters without running DynIn

%% RUN
script_root = fileparts(mfilename('fullpath'));
addpath(script_root,'-begin');
outDir = run_selected_benchmark(benchmark_name,seed_list,phase);

fprintf('\nExperiment output:\n%s\n',outDir);

function outDir = run_selected_benchmark(benchmarkName,seedList,phase)
    if strcmp(benchmarkName,'habib_vdp_tmd')
        outDir = run_experiment_C_highdim_vdp_tmd(seedList,phase);
    else
        outDir = run_experiment_C_physics_guided( ...
            benchmarkName,seedList,phase);
    end
end
