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
% Frozen quadratic-cubic BO candidate transferred to bistable Duffing.
root=fileparts(mfilename('fullpath'));
addpath(root);
selftest_duffing_transfer;
mode='pilot'; % pilot: 10 seeds/alpha; full: 100 seeds/alpha.
resumeDirectory=''; % Paste an interrupted output folder here to resume.
outputDirectory=run_duffing_transfer(mode,resumeDirectory);
fprintf('\nDuffing transfer output:\n%s\n',outputDirectory);
