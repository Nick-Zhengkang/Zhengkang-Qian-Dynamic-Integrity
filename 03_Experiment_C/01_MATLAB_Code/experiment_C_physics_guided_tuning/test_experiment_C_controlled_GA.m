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
% Controlled full-GA test of the independently validated domain rule.
% Open this file in MATLAB and press Run. Original DynIn files are unchanged.
here=fileparts(mfilename('fullpath'));
addpath(here);

mode='confirm';             % confirm: fresh seeds 61:90; develop: 1:10; smoke: 1
alphaValues=[0.2 0.7 1.0];
numberOfSteps=100;          % Identical trajectory budget for both domains.

domainDiagnosticDir=fullfile(here, ...
    'outputs_domain_diagnostics_20260923_202423_727');
independentValidationDir=fullfile(here, ...
    'outputs_domain_independent_validation_20260924_004648_294');

resumeDir=''; % To resume, paste the outputs_controlled_GA_domain_* folder here.

outDir=run_experiment_C_controlled_GA(domainDiagnosticDir, ...
    independentValidationDir,mode,alphaValues,numberOfSteps,resumeDir);
fprintf('\nControlled GA output:\n%s\n',outDir);
