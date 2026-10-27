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
%% DynIn GA versus proposed adaptive-angle method on six benchmarks

clear;
clc;

scriptDirectory = fileparts(mfilename('fullpath'));
addpath(scriptDirectory,'-begin');

runMode = "full";  % "pilot" = 3 paired seeds, "full" = 30 paired seeds
if runMode == "full"
    seedList = 1:30;
else
    seedList = 1:3;
end

resumeDirectory = "";

outputDirectory = run_six_model_dynin_vs_proposed( ...
    runMode,seedList,resumeDirectory);

fprintf('\nSix-model comparison output:\n%s\n',outputDirectory);
