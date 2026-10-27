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
% Test transferable parameter-selection rules for original DynIn GA.
% Start with quadratic_cubic/0.4. Keep the rule constants unchanged when
% moving to another model; the numerical settings are computed again.
clearvars;
model = 'quadratic_cubic'; % quadratic_cubic, bistable_duffing, cosine_quadratic_drag
alpha = 0.4;
mode = 'develop';         % smoke, develop, confirm
resumeDir = '';          % exact output folder for an interrupted experiment

cfg = experiment_C_rule_defaults(mode);
% develop: seeds 1:10; confirm: fresh seeds 31:60.
% Optional later search-budget comparison: cfg.budgets = [100 200];
test_experiment_C_rule_helpers;
outDir = run_experiment_C_2d_hypotheses(model,alpha,cfg,resumeDir);
fprintf('\nExperiment output:\n%s\n',outDir);
