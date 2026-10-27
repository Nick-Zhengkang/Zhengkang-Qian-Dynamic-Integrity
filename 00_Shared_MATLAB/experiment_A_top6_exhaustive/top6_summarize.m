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
function [S,best,decision]=top6_summarize(raw,C,baselineId,o)
S=optimization_statistics('summary',raw,baselineId,o,numel(o.seeds));
assert(height(S)==numel(C),'Not all planned configurations were recorded.');
S.max_error=zeros(height(S),1);
S.timing_review_required=false(height(S),1);
for i=1:height(S)
    g=raw(raw.config_id==S.config_id(i),:);
    S.max_error(i)=max(g.relative_error);
    S.timing_review_required(i)=any(g.timing_review_required);
end
b=S(S.is_baseline,:);
% Flag suspicious timing, but retain every observation and its accuracy data.
S.speed_ranking_eligible=S.feasible & ~S.timing_review_required & ...
    ~b.timing_review_required;
S.observed_faster_without_accuracy_loss=S.speed_ranking_eligible & S.runtime_ratio<1;
S=sortrows(S,{'speed_ranking_eligible','feasible','median_wall_runtime_s','median_error'}, ...
    {'descend','descend','ascend','ascend'});
S.screening_rank=(1:height(S)).';
best=struct2table(C(1)); best=best([],:);
if ~b.all_complete
    status='baseline_incomplete_no_ranking';
elseif b.timing_review_required
    status='baseline_timing_requires_review';
elseif ~any(S.speed_ranking_eligible)
    status='no_accuracy_feasible_timing_clean_configuration';
else
    faster=find(S.observed_faster_without_accuracy_loss,1);
    if isempty(faster)
        winner=S(S.is_baseline,:);
    else
        winner=S(faster,:);
    end
    ix=find(string({C.config_id})==winner.config_id,1);
    best=struct2table(C(ix));
    if winner.is_baseline
        status='baseline_retained_no_observed_speedup';
    else
        status='exploratory_candidate_requires_independent_confirmation';
    end
end
metrics={'median_error','p95_error','pass_rate','median_wall_runtime_s','runtime_ratio'};
for j=1:numel(metrics)
    if isempty(best)
        best.(metrics{j})=zeros(0,1);
    else
        best.(metrics{j})=winner.(metrics{j});
    end
end
best.recommended=false(height(best),1);
best.confirmed=false(height(best),1);
best.decision_status=repmat(string(status),height(best),1);
decision=struct('status',status,'recommended',false,'confirmed',false, ...
    'mode',o.mode,'n_configs',height(S),'n_seeds',numel(o.seeds), ...
    'n_runs',height(raw),'successful_runs',nnz(raw.success & raw.diagnostic_success), ...
    'observed_faster_feasible_candidates',nnz(S.observed_faster_without_accuracy_loss), ...
    'timing_flagged_runs',nnz(raw.timing_review_required), ...
    'scope','Exhaustive within six discrete grids; other settings fixed. Screening only.', ...
    'reference','Habib numerical reference 0.7683, not analytical truth.', ...
    'diagnostics','Fixed reference-assisted points: learned-grid labels plus follow-on integration.', ...
    'timing','Main-run wall time; diagnostic/setup/export costs excluded. Long timings retained and flagged.', ...
    'uncertainty','Three seeds cannot establish a reliable optimum. Nearest-rank P95 equals maximum with three seeds.');
if strcmp(o.mode,'smoke')
    decision.status=['smoke_only_' status];
    best.decision_status=repmat(string(decision.status),height(best),1);
end
end
