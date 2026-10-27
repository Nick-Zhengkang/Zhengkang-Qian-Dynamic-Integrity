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
% Run this script from its own folder. Existing studies are never imported.
mode='full';                         % 'pilot' or 'full'
options=surrogate_accuracy_options(mode);
options.useParallel=true;             % parfor across seeds
options.numWorkers=[];                % All workers allowed by Processes profile
resumeDirectory='';                   % Existing output folder to resume this study
% Optional examples:
% options.evaluationsPerRestart=40;
% options.screenSeeds=85101:85112;      % More seeds can occupy more workers
% options.numWorkers=6;                % Match an existing pool when appropriate

selftest_surrogate_accuracy();
outputDirectory=run_surrogate_accuracy(options,resumeDirectory);
fprintf('\nSurrogate accuracy-only output:\n%s\n',outputDirectory);
