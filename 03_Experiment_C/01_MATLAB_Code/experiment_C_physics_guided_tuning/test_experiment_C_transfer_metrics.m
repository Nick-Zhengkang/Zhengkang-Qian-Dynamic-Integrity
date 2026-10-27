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
function test_experiment_C_transfer_metrics()
% Unit tests: literal thresholds, inclusive boundaries, failures and gates.
e=[0;.005;.01;.015;.02;.025;.03;.04;.05;.06];
raw=table(repmat("time_first",10,1),repmat(100,10,1),(1:10)', ...
    "seed_"+string((1:10)'),repmat("ok",10,1),1+e,ones(10,1),e,e,zeros(10,1), ...
    'VariableNames',{'rule_id','number_of_steps','seed','run_key','status', ...
    'R_hat','reference_LIM','relative_error','signed_error','horizon_exhausted_proxy'});
base=table("time_first",100,10,true,true,true,false,false,0,0, ...
    'VariableNames',{'rule_id','number_of_steps','n_runs','calibration_pass','holdout_pass', ...
    'verification_pass','is_smoke','meets_screening_criteria', ...
    'within_1pct_rate','overestimate_gt1pct_rate'});
% Use stored decimal errors for precise threshold comparisons. Calculated
% errors still independently validate the raw values within roundoff.
[~,S]=experiment_C_transfer_metrics(raw,base,'bistable_duffing',.7,.02,.5);
assert(S.within_1pct_rate==.3 && S.within_2pct_rate==.5 && S.within_5pct_rate==.9);
assert(S.primary_screening_pass && S.primary_and_stability_pass);
bad=raw; bad.status(1)="failed";
[~,S]=experiment_C_transfer_metrics(bad,base,'bistable_duffing',.7,.02,.5);
assert(S.within_2pct_rate==.4 && ~S.primary_screening_pass);
bad=base; bad.holdout_pass=false;
[~,S]=experiment_C_transfer_metrics(raw,bad,'bistable_duffing',.7,.02,.5);
assert(~S.primary_screening_pass);
bad=base; bad.verification_pass=false;
[~,S]=experiment_C_transfer_metrics(raw,bad,'bistable_duffing',.7,.02,.5);
assert(S.primary_screening_pass && ~S.primary_and_stability_pass);
bad=base; bad.is_smoke=true;
[~,S]=experiment_C_transfer_metrics(raw,bad,'bistable_duffing',.7,.02,.5);
assert(~S.primary_screening_pass);
bad=raw; bad.horizon_exhausted_proxy(1)=1;
[~,S]=experiment_C_transfer_metrics(bad,base,'bistable_duffing',.7,.02,.5);
assert(~S.primary_screening_pass);

% Regression on the completed QC experiment, when available locally.
folder=fullfile(fileparts(mfilename('fullpath')), ...
    'outputs_followup_time_order_quadratic_cubic_20260922_180048_508');
if isfile(fullfile(folder,'raw_data_all_runs.csv'))
    R=readtable(fullfile(folder,'raw_data_all_runs.csv'),'TextType','string');
    A=readtable(fullfile(folder,'summary_by_profile_and_budget.csv'),'TextType','string');
    [~,S]=experiment_C_transfer_metrics(R,A,'quadratic_cubic',.4,.02,.9);
    t=S(string(S.rule_id)=="time_first",:);
    g=S(string(S.rule_id)=="grid_first",:);
    assert(t.within_1pct_rate==.8 && t.within_2pct_rate==.9 && t.within_5pct_rate==1);
    assert(t.primary_screening_pass && t.primary_and_stability_pass);
    assert(g.within_2pct_rate==1 && ~g.primary_and_stability_pass);
end
fprintf('Transfer threshold and screening-gate tests passed.\n');
end
