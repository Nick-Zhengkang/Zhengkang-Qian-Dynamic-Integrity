function [r,h,q]=run(method,m,c)
% RUN One fully timed search, excluding reference, disk IO, and plotting.
% Call rng(seed,'twister') before this function. No reseeding inside it.
% proposed_method is the frozen angular_improved policy, not the old polish.
if nargin<3, c=limbench.defaults(); end
validateattributes(c.queryBudget,{'numeric'},{'scalar','integer','positive'});
validateattributes(c.maxSeconds,{'numeric'},{'scalar','positive'});
validateattributes(c.maxRadius,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(c.scanStep,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(c.timeStages,{'numeric'},{'vector','positive','finite'});
assert(all(diff(c.timeStages)>0),'Integration stage times must increase.');
assert(numel(m.target)==2 && numel(m.weight)==2 && all(m.weight>0));
method=char(method);
assert(ismember(string(method),["proposed_method","coarse_GA","fine_GA", ...
    "dynin_original_bisection","energy_informed"]),'Unknown method.');
timer=tic;
oracle=@(x) limbench.classify(x,m,c);
if strcmp(method,'proposed_method')
    [r,h,q]=angular_engine('angular_improved',m,c,oracle,timer);
else
    [r,h,q]=baseline_engine(method,m,c,oracle,timer);
end
r.version=c.version;
r.profile='common_direct_classifier';
r.runtime=toc(timer);
% Include bookkeeping and table construction in every full-run time.
h(end+1,:)={r.queries,r.R,r.runtime,r.rhs,r.unknown,r.directions,r.odeCalls};
end
