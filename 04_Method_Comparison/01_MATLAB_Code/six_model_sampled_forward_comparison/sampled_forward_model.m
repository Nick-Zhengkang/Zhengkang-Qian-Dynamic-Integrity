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
function [p,c,s,api]=sampled_forward_model(row,d,o)
% Model-specific numbers; the Proposed classification logic is shared.
api=[]; id=string(row.model_id);
if row.dimension==4
    if id=="habib_vdp_tmd_4d"
        api=run_habib_4d_adaptive_radial_benchmark("refinement_api");
        c=api.configuration(o.mode); p=api.problem(.075,c);
    else
        api=run_separable_4d_analytic_benchmark("refinement_api");
        c=api.configuration(o.mode); p=api.problem(.4,.7,c);
    end
    c.postAuditDirections=0; c.postAuditBudget=0;
    c.maxWallSeconds=o.proposedMaxSeconds;
    if o.mode~="smoke", c.queryBudget=o.proposed4DQueryBudget; end
else
    c=struct(); p=struct('name',id);
    s=limbench.defaults();
    names=fieldnames(s);
    s=rmfield(s,names(startsWith(names,'energy')));
    % Retain the original 2D angle policy. The old 3-second guard is not
    % suitable after removing the fast classifier; report the new guard.
    s.maxSeconds=o.proposedMaxSeconds; s.queryBudget=o.proposed2DQueryBudget;
    if o.mode=="smoke"
        s.queryBudget=12; s.initialDirections=4; s.maxDirections=6;
        s.minRounds=1;
    end
end
% All classifier controls come from the same configuration as DynIn.
dim=numel(d.target);
p.target=reshape(d.target,1,[]); p.weight=reshape(d.weight,1,[]);
p.sqrtWeight=sqrt(p.weight);
p.lower=d.domain(1:dim); p.upper=d.domain(dim+1:end);
p.cellWidth=(p.upper-p.lower)/d.discr;
p.targetHalfWidth=.5*d.targetCells*p.cellWidth;
p.targetMetricRadius=sqrt(sum(p.weight.*p.targetHalfWidth.^2));
common={'discr','targetCells','tfinal','Ts','RelTol','AbsTol','repFixPoint','repPeriodic'};
for j=1:numel(common), c.(common{j})=d.(common{j}); end
c.retryUnresolved=false; c.retryHorizonFactor=1;
c.MaxStep=.1*d.Ts; c.minPeriodicRadius=.005; c.checkMinPeriodic=false;
c.automatic=1; c.nativeConfig=d;
radiusCap=min([p.sqrtWeight.*(p.target-p.lower),p.sqrtWeight.*(p.upper-p.target)]);
if dim==4, c.maxRadius=radiusCap; s=c; else, s.maxRadius=radiusCap; end
assert(all(p.target>p.lower & p.target<p.upper));
assert(all(p.targetHalfWidth>0) && all(p.targetHalfWidth<min(p.target-p.lower,p.upper-p.target)));
end


