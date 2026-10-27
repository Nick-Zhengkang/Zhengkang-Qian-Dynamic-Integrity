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
function test_experiment_C_followup_helpers()
% No GA integrations: test profile isolation, admission gates and pairing.
cfg=experiment_C_rule_defaults('develop');
[p,f]=experiment_C_rule_physics('initial','quadratic_cubic',0.4,cfg);
P=experiment_C_followup_plan('profiles',p,f,cfg);
assert(numel(P)==5 && numel(unique([P.rule_id]))==5);
assert(all([P.discr]==p.discr) && all([P.k]==p.k) && all([P.Ts]==p.Ts));
assert(P(1).tfinal==f.timeFromPeriod && P(2).tfinal==2*f.timeFromPeriod);
assert(P(3).tfinal==f.timeFromDecay && P(4).tfinal==P(5).tfinal);
% The first three controls differ only in time and a descriptive ID.
for i=2:3
    assert(isequaln(rmfield(P(1),{'tfinal','rule_id'}),rmfield(P(i),{'tfinal','rule_id'})));
end
[pd,fd]=experiment_C_rule_physics('initial','bistable_duffing',0.7,cfg);
assert(isequal(fd.target,[-1 0]) && ~isequal(fd.domain,f.domain));
assert(pd.k>=3 && pd.target_energy_fraction<=cfg.beta && pd.geometry_ok);
assert(fd.omega~=f.omega && pd.Ts~=p.Ts);

cfg.budgets=[100 200];
S=experiment_C_followup_plan('schedule',struct2table(P(5)),cfg,'quadratic_cubic',0.4);
assert(height(S)==20 && numel(unique(S.run_key))==20);
assert(isequal(S,experiment_C_followup_plan('schedule',struct2table(P(5)),cfg,'quadratic_cubic',0.4)));
for seed=cfg.seeds
    g=S(S.seed==seed,:);
    assert(height(g)==2 && isscalar(unique(g.algorithm_seed)));
end
q=P(5); q.calibration_pass=true; q.verification_pass=true;
a=struct('diagnostic_pass',true);
assert(experiment_C_followup_plan('eligible',q,a));
q.verification_pass=false;
assert(~experiment_C_followup_plan('eligible',q,a));
q.verification_pass=true; a.diagnostic_pass=false;
assert(~experiment_C_followup_plan('eligible',q,a));
q.calibration_pass=false; a.diagnostic_pass=true;
assert(~experiment_C_followup_plan('eligible',q,a));
q.calibration_pass=true; q.geometry_ok=false;
assert(~experiment_C_followup_plan('eligible',q,a));

confirm=experiment_C_rule_defaults('confirm');
assert(isequaln(experiment_C_followup_plan('constants',cfg), ...
    experiment_C_followup_plan('constants',confirm)));
confirm.beta=2*confirm.beta;
assert(~isequaln(experiment_C_followup_plan('constants',cfg), ...
    experiment_C_followup_plan('constants',confirm)));
fprintf('Follow-up profile isolation, physical transfer, pairing and admission tests passed.\n');
end
