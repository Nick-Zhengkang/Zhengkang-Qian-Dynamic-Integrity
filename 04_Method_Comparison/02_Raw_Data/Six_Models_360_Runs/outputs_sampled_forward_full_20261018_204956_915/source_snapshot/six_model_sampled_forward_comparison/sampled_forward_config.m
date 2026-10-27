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

