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
% Original DynIn GA: original domain versus the frozen radius-preserving domain.
here=fileparts(mfilename('fullpath')); addpath(here);
coverageDir=fullfile(here,'outputs_search_domain_closure_20260924_042002_735');
alphaValues=[0.2 0.7 1.0];
seeds=61:90;             % Same 30 paired seeds as the preceding controlled test.
numberOfSteps=100;       % Same trajectory budget in both arms.
resumeDir='';            % Paste outputs_anchored_GA_* here after interruption.
prepareOnly=false;       % true: validate/freeze inputs without running GA.

outDir=run_experiment_C_anchored_GA(coverageDir,alphaValues,seeds, ...
    numberOfSteps,resumeDir,prepareOnly);
fprintf('\nAnchored GA experiment output:\n%s\n',outDir);
