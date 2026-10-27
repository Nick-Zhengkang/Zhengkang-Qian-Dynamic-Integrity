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
%% Experiment C: refined high-dimensional parameter-transfer test
% Habib four-dimensional Duffing-Van der Pol + NLTVA benchmark.
% The original model and DynIn GA selector are retained unchanged.

clear; clc;

%% USER SETTINGS
phase = 'screening';
seed_list = 1:10;

% Available phases:
%   'smoke'        - one case, one seed, five classification profiles
%   'design'       - run the reference-blind pilot calibration only
%   'screening'    - 3 cases x 7 profiles x 10 paired seeds
%   'confirmation' - Habib paper baseline N=40 and frozen N=40/100/200;
%                    use 30 new paired seeds, e.g. 101:130, after screening

%% RUN
script_root = fileparts(mfilename('fullpath'));
addpath(script_root,'-begin');
outDir = run_experiment_C_highdim_vdp_tmd(seed_list,phase);

fprintf('\nExperiment output:\n%s\n',outDir);
