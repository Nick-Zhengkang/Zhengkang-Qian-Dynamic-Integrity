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
function o=surrogate_accuracy_options(mode)
% No historical configurations, initial observations, or time constraints.
if nargin<1, mode='pilot'; end
o=struct('version',1,'mode',char(mode),'synthetic',strcmp(mode,'selftest'), ...
    'useParallel',true,'numWorkers',[], ...
    'lower',[0 351 2 10 2 2],'upper',[5 1051 10 20 12 5], ...
    'newcomerRatioBounds',[.2 .6],'minSurrogatePoints',14, ...
    'evaluationsPerRestart',24,'optimizerSeeds',[89201 89202], ...
    'screenSeeds',85101:85106,'confirmSeeds',86101:86120, ...
    'scheduleSeed',89301,'bootstrapSeed',89401,'bootstrapSamples',5000);
switch char(mode)
    case 'pilot'
    case 'full'
        o.evaluationsPerRestart=120;
        o.screenSeeds=87101:87130;
        o.confirmSeeds=88101:88200;
    case 'selftest'
        o.useParallel=false;
        o.minSurrogatePoints=7;
        o.evaluationsPerRestart=10;
        o.screenSeeds=90101:90103;
        o.confirmSeeds=90201:90203;
        o.bootstrapSamples=200;
    otherwise
        error('Choose pilot, full, or selftest.');
end
end
