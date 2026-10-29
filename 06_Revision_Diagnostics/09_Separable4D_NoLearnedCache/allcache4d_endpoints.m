function [s,P]=allcache4d_endpoints(details,p,seed,estimate,reference)
% AI-assisted endpoint extraction. The reference is post-search reporting only.
s=struct('seed',seed,'reference',reference,'midpoint',estimate,'lower',NaN, ...
    'upper',NaN,'winning_ray',NaN,'tied_winning_rays',0,'lower_query',0, ...
    'upper_query',0,'first_non_target_below_query',0);
P=table();
if ~isfinite(estimate), return; end
rays=details.rays; values=[rays.boundary_radius];
winners=find(isfinite(values) & abs(values-estimate)<1e-12);
assert(~isempty(winners),'No ray matches the reported midpoint.');
s.winning_ray=winners(1); s.tied_winning_rays=numel(winners);
ray=rays(s.winning_ray); s.lower=ray.bracket_lower; s.upper=ray.bracket_upper;
assert(isfinite(s.upper) && s.upper>=s.lower && abs((s.upper+s.lower)/2-estimate)<1e-10);
zlo=p.target+s.lower*ray.direction./p.sqrtWeight;
zhi=p.target+s.upper*ray.direction./p.sqrtWeight;
zmid=p.target+estimate*ray.direction./p.sqrtWeight;
Q=allcache4d_query_table(details.query_records);
hit=find(max(abs(Q.initial_state-zhi),[],2)<1e-10 & Q.label=="non_target",1);
assert(~isempty(hit),'Winning upper endpoint has no recorded non-target query.'); s.upper_query=hit;
if s.lower>0
    hit=find(max(abs(Q.initial_state-zlo),[],2)<1e-10 & Q.label=="target",1);
    assert(~isempty(hit),'Winning lower endpoint has no recorded target query.'); s.lower_query=hit;
end
hit=find(Q.label=="non_target" & Q.radius<reference-1e-10,1);
if ~isempty(hit), s.first_non_target_below_query=hit; end
rows={point("winning_lower",s.lower_query,zlo,"target"), ...
    point("winning_upper",s.upper_query,zhi,"non_target"), ...
    point("reported_midpoint",0,zmid,"not_classified_as_midpoint")};
P=struct2table(vertcat(rows{:}));
end

function p=point(role,q,z,label)
p=struct('role',role,'query',q,'state',reshape(z,1,[]),'parent_query',0,'original_label',label);
end

