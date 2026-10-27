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
% First stop the old MATLAB computation with Ctrl+C, then run this script.
% Completed results are checked and copied; the original output is retained.
here=fileparts(mfilename('fullpath'));
addpath(here);
clear experiment_C_rule_diagnostics test_experiment_C_rule_helpers;
sourceDir=fullfile(here, ...
    'outputs_rule_hypotheses_quadratic_cubic_20260922_044059_823');
outDir=repair_and_resume_C_rule(sourceDir);
fprintf('\nResumed experiment output:\n%s\n',outDir);
