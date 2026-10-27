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


