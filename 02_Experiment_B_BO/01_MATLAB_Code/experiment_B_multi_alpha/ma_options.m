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
function o=ma_options(mode)
% Same eight-variable accuracy-only search; disjoint alpha and seed holdouts.
if nargin<1, mode='pilot'; end
o=struct('version',1,'mode',char(mode),'model','quadratic_cubic', ...
    'trainAlpha',(1:20)/10,'validationAlpha',(1:2:39)/20, ...
    'trainSeeds',103101:103102,'validationSeeds',104101:104105, ...
    'optimizerSeeds',[105101 105102],'scheduleSeed',106101, ...
    'evaluationsPerRestart',8,'initialPoints',4, ...
    'useParallel',true,'numWorkers',[], ...
    'lower',[0 351 2 10 2 2 50 .025], ...
    'upper',[5 1051 10 20 12 5 200 .10]);
switch char(mode)
    case 'pilot'
    case 'full'
        o.trainSeeds=107101:107110;
        o.validationSeeds=108101:108200;
        o.evaluationsPerRestart=200; o.initialPoints=16;
    otherwise
        error('Choose pilot or full.');
end
end
