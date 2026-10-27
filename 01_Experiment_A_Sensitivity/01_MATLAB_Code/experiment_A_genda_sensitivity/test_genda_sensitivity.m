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
% Edit only these options before running. Keep the old Experiment A intact.
root = fileparts(mfilename('fullpath'));
addpath(root);
options = genda_A_options('full'); % 'pilot': 58 runs; 'full': 870 runs (30 seeds)
options.useParallel = true;
options.numWorkers = []; % All workers allowed by the local Processes profile
resumeDirectory = ''; % Resume only a matching new 30-seed full study, not old 10-seed outputs
selftest_genda_sensitivity;
outputDirectory = run_genda_sensitivity(options, resumeDirectory);
fprintf('\nGenda Experiment A output:\n%s\n', outputDirectory);
