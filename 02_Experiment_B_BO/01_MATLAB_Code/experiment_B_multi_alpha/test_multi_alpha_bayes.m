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
% Start with pilot. Change only mode to 'full' for the full preregistered budget.
scriptRoot=fileparts(mfilename('fullpath'));
addpath(scriptRoot);
options=ma_options('full');
options.useParallel=true;
options.numWorkers=[]; % Existing local process pool or local profile capacity.
resumeDirectory='';   % Paste an interrupted output folder here to resume.
selftest_multi_alpha_bayes;
outputDirectory=run_multi_alpha_bayes(options,resumeDirectory);
fprintf('\nMulti-alpha Bayesian output:\n%s\n',outputDirectory);
