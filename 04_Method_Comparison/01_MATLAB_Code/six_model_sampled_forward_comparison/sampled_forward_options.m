% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Proposed-method implementation, comparison, or supporting model code.
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
function o=sampled_forward_options(mode)
if nargin<1, mode="pilot"; end
mode=string(mode);
assert(isscalar(mode) && any(mode==["pilot","full","smoke"]));
o=struct('version',"sampled-single-ode-v1",'mode',mode, ...
    'benchmarks',"all",'seeds',1:3, ...
    'refinement2D',1,'refinement4D',1,'runSelfTests',true, ...
    'scheduleSeed',20261018,'proposedMaxSeconds',3600, ...
    'proposed2DQueryBudget',4096,'proposed4DQueryBudget',700);
if mode=="full", o.seeds=1:30; end
if mode=="smoke", o.seeds=1; end
end


