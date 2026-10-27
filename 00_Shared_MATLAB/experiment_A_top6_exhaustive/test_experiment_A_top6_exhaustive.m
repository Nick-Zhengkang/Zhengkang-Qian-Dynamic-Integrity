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
% Run this whole file. FULL = 3240 configurations x 3 seeds = 9720 runs.
% Completed records are retained. An interrupted, unsaved run is repeated.
root=fileparts(mfilename('fullpath'));
addpath(root,'-begin');
selftest_top6_exhaustive; % Check design and ranking before long integrations.
mode='full'; % 'smoke' performs only two installation-check runs.
resumeDirectory=''; % To resume, paste the existing output directory here.
if isempty(resumeDirectory)
    options=top6_options(mode);
else
    saved=load(fullfile(resumeDirectory,'study_definition.mat'),'options');
    options=saved.options; % Resume the exact saved settings.
end
outputDirectory=run_experiment_A_top6_exhaustive(options,resumeDirectory);
fprintf('\nOutput directory:\n%s\n',outputDirectory);
