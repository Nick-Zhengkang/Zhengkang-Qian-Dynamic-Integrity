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
function check_experiment_C_cosine_transfer
% Lightweight formula/configuration checks, with no full GA experiment.
here=fileparts(mfilename('fullpath')); old=path; guard=onCleanup(@()path(old));
addpath(here,fullfile(fileparts(here),'four_model_five_method_suite','functions'));
[f,p,h,cfg,A]=experiment_C_cosine_settings(0.05);
assert(p.discr==635 && p.k==19 && p.tfinal==680);
assert(abs(p.Ts-2*pi/125)<1e-14 && p.target_energy_fraction<=cfg.beta);
assert(min([f.target-f.domain(1:2),f.domain(3:4)-f.target])==pi);
assert(min([f.target-h.domain(1:2),h.domain(3:4)-f.target])==pi);
assert(f.domain(4)>A.velocity_bound && -f.domain(2)>A.velocity_bound);
theta=(0:720)'*2*pi/721;
for r=[0 pi/2 pi*(1-1e-10) pi]
    z=r*[cos(theta),sin(theta)]; E=.5*z(:,2).^2+1-cos(z(:,1));
    assert(max(E)<=A.search_energy_cap+1e-12);
end
[fine,ok]=experiment_C_rule_physics('regrid',p,2*p.discr-1,f,cfg);
assert(ok && fine.k>=3 && fine.target_energy_fraction<=cfg.beta);
% Verify dissipative energy and the oracle well convention.
for z={[.2 .1],[4 .1]}
    Z=z{1}; rhs=experiment_C_rule_physics('rhs',f.model,f.alpha,Z);
    dE=sin(Z(1))*rhs(1)+Z(2)*rhs(2);
    assert(abs(dE+f.alpha*abs(Z(2))^3)<1e-12);
end
[target,~]=experiment_C_rule_physics('trap',f.model,[.1 .1],f,.01);
[other,~]=experiment_C_rule_physics('trap',f.model,[2*pi .1],f,.01);
assert(target==1 && other==2);
[ref,audit]=fourbench.reference('genda_cosine_quadratic_drag',.05);
assert(strcmp(ref.kind,'analytical_branch_evaluated_numerically'));
assert(abs(ref.R-2.087159265254399)<1e-10 && audit.stationarity_residual<1e-8);
fprintf('Cosine formula checks passed. Reference=%.12f (scoring only).\n',ref.R);
end
