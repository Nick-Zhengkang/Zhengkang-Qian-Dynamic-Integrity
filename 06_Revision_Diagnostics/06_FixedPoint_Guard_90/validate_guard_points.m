function [winningOutcome,allSupported]=validate_guard_points(id,d,details,ref,folder,o)
% AI-assisted adapter. Numerical independent validation is unchanged.
qs=details.query_records; n=numel(qs);
unsafe=cellfun(@(q) string(q.label)=="non_target",qs);
winningOutcome="no_non_target_query"; allSupported=false;
if ~any(unsafe), return; end
radii=cellfun(@(q) double(q.initial_radius),qs);
ids=find(unsafe); [~,j]=min(radii(ids)); win=ids(j);
first=find(unsafe & radii<ref-1e-10,1);
qstruct=vertcat(qs{:}); points=vertcat(qstruct.initial_state);
assert(isequal(size(points),[n,2]));
query=(1:n).'; x0=points(:,1); v0=points(:,2);
parent_query=zeros(n,1); hit_x=nan(n,1); hit_v=hit_x; donor_x=hit_x; donor_v=hit_x;
Q=table(query,x0,v0,parent_query,hit_x,hit_v,donor_x,donor_v);
trace=struct('queries',Q,'winning_chain',win,'first_under_chain',first);
mkdir(folder);
A=fpguard_validate_independent(id,d,trace,struct('winning_query',win),folder,o);
winningOutcome=A.conclusion(A.query==win & A.role=="initial_state");
assert(isscalar(winningOutcome));
allSupported=all(A.conclusion=="both_solvers_support_non_target");
end
