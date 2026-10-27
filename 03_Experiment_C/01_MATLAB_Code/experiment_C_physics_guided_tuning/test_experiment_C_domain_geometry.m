% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
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
function test_experiment_C_domain_geometry()
% Fast algebra and geometry tests, no GA or trajectory integration.
cfg=experiment_C_rule_defaults('develop');
[p,f]=experiment_C_rule_physics('initial','bistable_duffing',0.7,cfg);
for E=[-.25 -.1 0 .25 1 3]
    b=experiment_C_domain_geometry('energy_bounds',E);
    V=@(x)-0.5*x.^2+0.25*x.^4;
    assert(abs(V(b(3))-E)<1e-10);
    assert(abs(b(4)^2/2-0.25-E)<1e-10);
    [g,q,a]=experiment_C_domain_geometry('pad',f,p,b,.05,100000);
    assert(q.k==p.k && q.Ts==p.Ts && q.tfinal==p.tfinal);
    assert(q.discr==p.discr+2*a.padding_cells_each_side);
    assert(a.max_target_belt_difference<1e-10 && a.max_step_difference<1e-12);
    assert(all(g.domain(1:2)<=f.domain(1:2)) && all(g.domain(3:4)>=f.domain(3:4)));
    assert(all(g.domain(1:2)<=b(1:2)) && all(g.domain(3:4)>=b(3:4)));
end
[g,q,a]=experiment_C_domain_geometry('pad',f,p,f.domain,0,cfg.maximumGrid);
assert(isequal(g.domain,f.domain) && q.discr==p.discr && a.padding_cells_each_side==0);
b=experiment_C_domain_geometry('energy_bounds',10);
[~,q,a]=experiment_C_domain_geometry('pad',f,p,b,.05,p.discr);
assert(~a.within_grid_limit && q.discr>p.discr);
fprintf('Duffing energy-envelope and exact lattice-padding tests passed.\n');
end
