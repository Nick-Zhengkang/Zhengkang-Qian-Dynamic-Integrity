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
% Open this file in MATLAB and press Run. No original DynIn files are changed.
here=fileparts(mfilename('fullpath'));
addpath(here);

mode='develop';             % develop: seeds 1:10; confirm: 31:60; smoke: 1
alphaValues=[0.2 0.7 1.0];  % Use 0.7 alone to run just one damping case.
resumeDir='';               % Paste this suite's output directory to resume.

outDir=run_experiment_C_duffing_transfer(mode,alphaValues,resumeDir);
fprintf('\nDuffing transfer output:\n%s\n',outDir);
