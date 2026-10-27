function [r,h,q]=proposed_four_models(m,c)
% Adapter only: reuse the byte-identical frozen angular_engine.
if any(strcmp(m.name,{'quadratic_cubic','bistable_duffing'}))
    [r,h,q]=limbench.proposed(m,c);
    return
end
assert(any(strcmp(m.name,{'paper_unforced_duffing','genda_cosine_quadratic_drag'})));
timer=tic;
oracle=@(x) fourbench.classify_extension(x,m,c);
[r,h,q]=angular_engine('angular_improved',m,c,oracle,timer);
r.version=c.version;
r.profile='frozen_angular_policy_new_physical_classifier';
r.runtime=toc(timer);
h(end+1,:)={r.queries,r.R,r.runtime,r.rhs,r.unknown,r.directions,r.odeCalls};
end
