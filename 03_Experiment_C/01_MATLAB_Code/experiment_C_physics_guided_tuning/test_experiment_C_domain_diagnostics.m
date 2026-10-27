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
% Domain-only regression diagnostics; original DynIn classification is unchanged.
here=fileparts(mfilename('fullpath'));
addpath(here);
sourceDir=fullfile(here,'outputs_duffing_transfer_20260923_003027_851');
alphaValues=[0.2 0.7 1.0]; % Set 0.7 to diagnose one case first.
resumeDir='';             % This new diagnostic output root, when resuming.
outDir=run_experiment_C_domain_diagnostics(sourceDir,alphaValues,resumeDir);
fprintf('\nDomain diagnostic output:\n%s\n',outDir);
