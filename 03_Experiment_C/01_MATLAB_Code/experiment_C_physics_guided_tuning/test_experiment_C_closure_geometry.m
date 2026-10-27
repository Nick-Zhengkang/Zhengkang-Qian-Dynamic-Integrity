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
function test_experiment_C_closure_geometry
% Independent energy maxima, geometry and applicability checks; no GA runs.
state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(92431,'twister');
f=struct('model',"bistable_duffing",'alpha',0.7,'target',[-1 0],'weight',[1 1], ...
    'domain',[-1.897056274847714 -0.989949493661167 1.48284271247462 0.989949493661167]);
p=struct('discr',677,'k',11);
old=experiment_C_search_domain_closure('audit',f,p);
assert(~old.exact_energy_envelope_covered);
[g,q,a]=experiment_C_search_domain_closure('build',f,p,2401);
assert(a.exact_energy_envelope_covered && a.within_grid_limit && a.radius_preserved);
assert(a.max_target_belt_difference<1e-10 && q.k==p.k);
assert(g.domain(1)==f.domain(1));
% Compare closed-form maxima against independent dense disk sampling.
for R=[0.01 0.2 0.897056274847714 1.84683339807098 3]
    theta=2*pi*rand(20000,1); rad=R*sqrt(rand(20000,1));
    x=-1+rad.*cos(theta); v=rad.*sin(theta);
    E=0.5*v.^2-0.5*x.^2+0.25*x.^4;
    cap=-0.25+R^2+R^3+R^4/4;
    atMaximum=-0.5*(-1-R)^2+0.25*(-1-R)^4;
    assert(max(E)<=cap+1e-10 && abs(atMaximum-cap)<1e-10);
end
% The current symmetric envelope is not closed with its own larger R0.
sym=f; sym.domain=[-3.35984859875531 -1.84683339807098 2.94563503638222 1.84683339807098];
pp=p; pp.discr=1263;
b=experiment_C_search_domain_closure('audit',sym,pp);
assert(~b.exact_energy_envelope_covered);
[~,~,limited]=experiment_C_search_domain_closure('build',f,p,700);
assert(~limited.within_grid_limit);
unsupported=f; unsupported.weight=[4 1]; rejected=false;
try
    experiment_C_search_domain_closure('audit',unsupported,p);
catch
    rejected=true;
end
assert(rejected,'Unsupported metric must not receive a coverage certificate.');
fprintf('Closure geometry tests passed. New N=%d; R0=%.12g; Ecap=%.12g.\n', ...
    q.discr,a.initial_search_radius,a.search_energy_cap);
end
