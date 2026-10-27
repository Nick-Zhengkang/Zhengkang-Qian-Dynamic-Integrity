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
function d=sampled_forward_config(d,o)
% Odd factors preserve the effective native target width, k*domain/discr.
d.baseDiscr=d.discr; d.baseRequestedK=d.targetCells;
k=floor(abs(d.targetCells)); if mod(k,2)==0, k=k-1; end
assert(k>=1);
d.baseEffectiveK=k;
if numel(d.target)==2, f=o.refinement2D; else, f=o.refinement4D; end
validateattributes(f,{'numeric'},{'scalar','integer','positive','finite'});
assert(mod(f,2)==1,'Refinement factor must be odd.');
d.refinementFactor=f; d.discr=d.baseDiscr*f; d.targetCells=k*f;
assert(d.targetCells^numel(d.target)<=2e5, ...
    'Target-cell initialization is too large. Reduce the refinement factor for this dimension.');
assert(abs(d.targetCells/d.discr-k/d.baseDiscr)<1e-12);
end

