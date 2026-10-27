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
function o=bayes8_options(mode)
% More configurations, ten common seeds, accuracy-only objective.
if nargin<1, mode='pilot'; end
o=struct('version',1,'mode',char(mode),'synthetic',strcmp(mode,'selftest'), ...
    'modelId','genda_bistable_duffing','alpha',0.7, ...
    'useParallel',true,'numWorkers',[], ...
    'lower',[0 351 2 10 2 2 50 .025],'upper',[5 1051 10 20 12 5 200 .10], ...
    'newcomerRatioBounds',[.2 .6],'initialPoints',16, ...
    'evaluationsPerRestart',32,'optimizerSeeds',[99201 99202], ...
    'screenSeeds',95101:95110,'confirmSeeds',96101:96120, ...
    'scheduleSeed',99301,'bootstrapSeed',99401,'bootstrapSamples',5000);
switch char(mode)
    case 'pilot'
    case 'full'
        o.evaluationsPerRestart=200;
        o.screenSeeds=97101:97110;
        o.confirmSeeds=98101:98200;
    case 'selftest'
        o.useParallel=false;
        o.initialPoints=3; o.evaluationsPerRestart=8;
        o.screenSeeds=99501:99503; o.confirmSeeds=99601:99603;
        o.bootstrapSamples=200;
    otherwise
        error('Choose pilot, full, or selftest.');
end
end
