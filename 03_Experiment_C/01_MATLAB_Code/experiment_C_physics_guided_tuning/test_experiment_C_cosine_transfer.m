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
% Original benchmark: Genda cosine potential with quadratic drag.
% Run this file. Only change resumeDir to continue an interrupted experiment.
here=fileparts(mfilename('fullpath'));
addpath(here);
alpha=0.05;
seeds=91:120;
number_of_steps=100;
mode='full'; % 'prepare': configuration only; 'diagnostics': no GA; 'full': both.
resumeDir='';
outDir=run_experiment_C_cosine_transfer(alpha,seeds,number_of_steps,mode,resumeDir);
fprintf('\nCosine transfer output:\n%s\n',outDir);
