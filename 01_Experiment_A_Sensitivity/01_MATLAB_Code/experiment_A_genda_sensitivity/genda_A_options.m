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
function o = genda_A_options(mode)
if nargin < 1, mode = 'pilot'; end
o.mode = validatestring(mode, {'pilot','full','smoke'});
o.alpha = .7;
o.useParallel = true;
o.numWorkers = [];
o.scheduleSeed = 621031;
o.seedList = 99101:99102;
o.diagnosticAngles = 8;
o.radiusFactors = [.85 1 1.15];
o.truthHorizon = 4000;
o.truthTolerance = .002;
o.truthRelTol = 1e-11;
o.truthAbsTol = 1e-12;
o.saveTrajectories = false;
if strcmp(mode,'full')
    o.seedList = 99101:99130;
    o.diagnosticAngles = 24;
elseif strcmp(mode,'smoke')
    o.seedList = 99101;
    o.diagnosticAngles = 2;
    o.radiusFactors = [.85 1.15];
end
end
