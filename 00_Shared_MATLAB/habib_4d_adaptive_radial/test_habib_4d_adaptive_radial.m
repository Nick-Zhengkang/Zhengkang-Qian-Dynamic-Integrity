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
%% Habib 4D Duffing-van der Pol + TMD benchmark
% Start with "pilot". Use "full" only after the pilot has no systematic
% unresolved classifications.

clear;
clc;

runMode = "pilot";   % "pilot" = 3 seeds, "full" = 30 seeds
mu1Values = 0.075;   % Habib example; e.g. [0.065 0.075 0.095]

if runMode == "full"
    seedList = 1:30;
else
    seedList = 1:3;
end

resumeDirectory = ""; % Put an existing output folder here to resume it.

outputDirectory = run_habib_4d_adaptive_radial_benchmark( ...
    runMode,mu1Values,seedList,resumeDirectory);

fprintf('\nExperiment output:\n%s\n',outputDirectory);

