function [action,verified,changeRate,pathChange]=experiment_C_rule_decision(A,B,QA,QB,cfg,block)
% Make the adjustment decision before any analytical LIM is evaluated.
if nargin<6, block='grid'; end
known=QA.inside_domain & ismember(QA.truth_label,[1 2]);
assert(isequal(QA.point_id,QB.point_id),'Diagnostic point order differs.');
if any(known)
    changeRate=mean(QA.predicted_label(known)~=QB.predicted_label(known));
else
    changeRate=NaN;
end
pathChange=0;
if strcmp(block,'sampling')
    both=known & QA.truth_label==2 & QA.predicted_label==2 & QB.predicted_label==2 & ...
        isfinite(QA.sampled_non_target_distance) & isfinite(QB.sampled_non_target_distance);
    if any(both)
        pathChange=max(abs(QA.sampled_non_target_distance(both)- ...
            QB.sampled_non_target_distance(both))./ ...
            max(abs(QB.sampled_non_target_distance(both)),eps));
    else
        pathChange=NaN;
    end
end
verified=A.diagnostic_pass && B.diagnostic_pass && ...
    changeRate<=cfg.labelChangeThreshold && pathChange<=cfg.maxPathDistanceChange;
if verified
    action="retain_verified";
    return
end
old=[A.n_false_safe A.n_false_unsafe A.n_unresolved A.n_exceptions];
new=[B.n_false_safe B.n_false_unsafe B.n_unresolved B.n_exceptions];
needsMoreTime=strcmp(block,'time') && B.n_unresolved>0;
if all(new<=old) && (any(new<old) || changeRate>cfg.labelChangeThreshold || ...
        pathChange>cfg.maxPathDistanceChange || needsMoreTime)
    action="adopt_and_recheck";
elseif any(new>old)
    action="retain_candidate_worse";
else
    action="retain_no_response";
end
end
