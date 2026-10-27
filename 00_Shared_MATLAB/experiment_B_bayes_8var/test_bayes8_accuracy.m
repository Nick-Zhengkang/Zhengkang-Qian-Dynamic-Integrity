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
% Eight-variable Genda Duffing BO. Run this entry from its own folder.
mode='full';                     % Change to 'full' after checking pilot output
options=bayes8_options(mode);
options.useParallel=true;         % parfor across seeds; no nested parallelism
options.numWorkers=[];            % All workers allowed by the Processes profile
resumeDirectory='';              % Only an output folder from THIS 8-variable study

selftest_bayes8_accuracy();
outputDirectory=run_bayes8_accuracy(options,resumeDirectory);
fprintf('\nEight-variable accuracy-only Bayesian output:\n%s\n',outputDirectory);
