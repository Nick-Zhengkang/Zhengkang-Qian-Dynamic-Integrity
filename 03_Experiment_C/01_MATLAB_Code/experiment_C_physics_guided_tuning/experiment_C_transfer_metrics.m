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
function [R,S]=experiment_C_transfer_metrics(raw,legacySummary,model,alpha,primaryTolerance,requiredRate)
% Evaluate fixed runs at literal 1/2/5 percent thresholds; never retune them.
assert(isscalar(primaryTolerance) && primaryTolerance>0 && isfinite(primaryTolerance));
assert(isscalar(requiredRate) && requiredRate>0 && requiredRate<=1);
assert(height(raw)>0 && height(legacySummary)>0,'Results are empty.');
assert(numel(unique(string(raw.run_key)))==height(raw),'Duplicate run keys.');
R=raw;
R.model=repmat(string(model),height(R),1);
R.alpha=repmat(alpha,height(R),1);
R.primary_tolerance=repmat(primaryTolerance,height(R),1);
valid=string(R.status)=="ok" & isfinite(R.R_hat) & isfinite(R.reference_LIM) & R.reference_LIM>0;
computed=abs(R.R_hat-R.reference_LIM)./R.reference_LIM;
assert(all(abs(computed(valid)-R.relative_error(valid))<1e-10),'Raw error values are inconsistent.');
R.within_1pct=valid & R.relative_error<=0.01;
R.within_2pct=valid & R.relative_error<=0.02;
R.within_5pct=valid & R.relative_error<=0.05;
R.within_primary_tolerance=valid & R.relative_error<=primaryTolerance;
S=legacySummary;
S.model=repmat(string(model),height(S),1);
S.alpha=repmat(alpha,height(S),1);
% Remove legacy gate names so the new primary criterion is unambiguous.
if ismember('meets_screening_criteria',S.Properties.VariableNames)
    idx=strcmp(S.Properties.VariableNames,'meets_screening_criteria');
    S.Properties.VariableNames{idx}='legacy_1pct_screening_pass';
end
S.primary_tolerance=repmat(primaryTolerance,height(S),1);
S.required_success_rate=repmat(requiredRate,height(S),1);
S.within_2pct_rate=zeros(height(S),1);
S.within_5pct_rate=zeros(height(S),1);
S.within_primary_tolerance_rate=zeros(height(S),1);
S.overestimate_gt2pct_rate=zeros(height(S),1);
S.overestimate_gt5pct_rate=zeros(height(S),1);
S.primary_screening_pass=false(height(S),1);
S.primary_and_stability_pass=false(height(S),1);
for i=1:height(S)
    take=string(R.rule_id)==string(S.rule_id(i)) & R.number_of_steps==S.number_of_steps(i);
    g=R(take,:);
    assert(height(g)==S.n_runs(i) && height(g)>0,'Run count differs from summary.');
    assert(numel(unique(g.seed))==height(g),'Duplicate seeds within a configuration.');
    S.within_1pct_rate(i)=mean(g.within_1pct);
    S.within_2pct_rate(i)=mean(g.within_2pct);
    S.within_5pct_rate(i)=mean(g.within_5pct);
    S.within_primary_tolerance_rate(i)=mean(g.within_primary_tolerance);
    S.overestimate_gt1pct_rate(i)=mean(g.signed_error>0.01 & string(g.status)=="ok");
    S.overestimate_gt2pct_rate(i)=mean(g.signed_error>0.02 & string(g.status)=="ok");
    S.overestimate_gt5pct_rate(i)=mean(g.signed_error>0.05 & string(g.status)=="ok");
    % Failed runs count as failures, not missing observations in the rate.
    completed=all(string(g.status)=="ok" & isfinite(g.relative_error) & isfinite(g.R_hat));
    noHorizon=all(isfinite(g.horizon_exhausted_proxy) & g.horizon_exhausted_proxy==0);
    S.primary_screening_pass(i)=S.calibration_pass(i) && S.holdout_pass(i) && ...
        completed && noHorizon && ~S.is_smoke(i) && ...
        S.within_primary_tolerance_rate(i)>=requiredRate;
    S.primary_and_stability_pass(i)=S.primary_screening_pass(i) && S.verification_pass(i);
end
end
