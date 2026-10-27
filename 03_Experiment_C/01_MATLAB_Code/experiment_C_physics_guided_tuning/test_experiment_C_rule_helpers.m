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
function test_experiment_C_rule_helpers()
% Fast checks of physical scaling and decision semantics, without GA runs.
cfg=experiment_C_rule_defaults('develop');
models={'quadratic_cubic','bistable_duffing','cosine_quadratic_drag'};
for i=1:numel(models)
    [p,f]=experiment_C_rule_physics('initial',models{i},0.4,cfg);
    assert(p.k>=3 && mod(p.k,2)==1 && mod(p.discr,2)==1);
    assert(p.target_energy_fraction<=cfg.beta && p.geometry_ok);
    [q,ok]=experiment_C_rule_physics('regrid',p,2*p.discr,f,cfg);
    assert(ok && q.achieved_eta<p.achieved_eta);
    assert(q.target_energy_fraction<=cfg.beta && q.k>=p.k);
    [label,~]=experiment_C_rule_physics('trap',f.model,f.target,f,0.01);
    assert(label==1);
    % Verify dE/dt=-alpha*abs(v)^3 for the actual model RHS.
    z=f.target+[0.1 0.3]; step=1e-6;
    Vplus=experiment_C_rule_physics('potential',f.model,z(1)+step);
    Vminus=experiment_C_rule_physics('potential',f.model,z(1)-step);
    rhs=experiment_C_rule_physics('rhs',f.model,f.alpha,z);
    edot=(Vplus-Vminus)/(2*step)*rhs(1)+z(2)*rhs(2);
    assert(abs(edot+f.alpha*abs(z(2))^3)<1e-8);
end
[~,f1]=experiment_C_rule_physics('initial','quadratic_cubic',0.2,cfg);
[~,f2]=experiment_C_rule_physics('initial','quadratic_cubic',0.4,cfg);
assert(abs(f1.decayEstimate/f2.decayEstimate-2)<1e-12);

% Regression: held-out point 48 starts beyond x=1.01, turns at x>1.08,
% then escapes without ever crossing the former event plane.
theta=(11+0.673)*2*pi/12;
z48=1.15*[cos(theta),sin(theta)/sqrt(3)];
[label,reason,escapeTime,errorText]=experiment_C_rule_diagnostics('oracle',z48,f2,cfg);
assert(label==2 && reason=="right_escape" && escapeTime<2 && strlength(errorText)==0, ...
    'Escape detection failed for a trajectory turning to the right of the saddle.');

cfg.minClassCount=1;
cfg.minBoundaryPoints=1;
Q=table((1:4)',logical([1;1;0;1]),[1;2;2;0],[1;2;0;0], ...
    [1;3;0;0],["target";"domain_exit";"domain_excluded";"horizon_unresolved"], ...
    zeros(4,1),[NaN;0.7;NaN;NaN], ...
    'VariableNames',{'point_id','inside_domain','truth_label','predicted_label', ...
    'raw_tipo','classifier_status','classifier_wall_s','sampled_non_target_distance'});
Q.kind=repmat("near_boundary",height(Q),1);
S=experiment_C_rule_diagnostics('summarize',Q,cfg);
assert(S.n_domain_excluded==1 && S.n_unresolved==0 && S.n_truth_unresolved==1);
assert(S.unresolved_rate==0 && ~S.diagnostic_pass);
Q=Q(1:2,:);
S=experiment_C_rule_diagnostics('summarize',Q,cfg);
[action,verified]=experiment_C_rule_decision(S,S,Q,Q,cfg);
assert(verified && action=="retain_verified");

bad=Q; bad.predicted_label(:)=0; bad.raw_tipo(:)=0;
bad.classifier_status(:)="horizon_unresolved";
B=experiment_C_rule_diagnostics('summarize',bad,cfg);
[action,verified]=experiment_C_rule_decision(B,B,bad,bad,cfg);
assert(~verified && action=="retain_no_response");
[action,verified]=experiment_C_rule_decision(B,B,bad,bad,cfg,'time');
assert(~verified && action=="adopt_and_recheck");
[action,verified]=experiment_C_rule_decision(B,S,bad,Q,cfg);
assert(~verified && action=="adopt_and_recheck");
wrong=Q; wrong.predicted_label(2)=1;
W=experiment_C_rule_diagnostics('summarize',wrong,cfg);
[action,verified]=experiment_C_rule_decision(S,W,Q,wrong,cfg);
assert(~verified && action=="retain_candidate_worse");

fine=Q; fine.sampled_non_target_distance(2)=0.68;
[action,verified,~,change]=experiment_C_rule_decision(S,S,Q,fine,cfg,'sampling');
assert(~verified && action=="adopt_and_recheck" && change>0.005);
fprintf('Physics, exclusions, unresolved handling and adjustment-decision checks passed.\n');
end
