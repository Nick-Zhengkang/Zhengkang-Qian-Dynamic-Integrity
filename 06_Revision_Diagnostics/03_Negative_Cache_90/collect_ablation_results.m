function collect_ablation_results(out)
% AI-assisted serial aggregation. Run only after workers finish or are stopped.
cases=readtable(fullfile(out,'selected_cases.csv'),'TextType','string');
rows=cell(0,1); comparisons=cell(0,1); states=cell(height(cases),1);
for k=1:height(cases)
    id=cases.model(k); seed=cases.seed(k);
    file=fullfile(out,sprintf('%s_seed_%d',id,seed),'case_result.mat');
    if ~isfile(file)
        states{k}=struct('model',id,'seed',seed,'status',"not_finished", ...
            'phase',"no_complete_case_report",'message',"Case result not available; inspect its run.log.");
        continue
    end
    try
        f=load(file,'result'); r=f.result;
        assert(r.status.model==id && r.status.seed==seed);
        rows=[rows;r.rows]; %#ok<AGROW>
        if ~isempty(r.comparison), comparisons{end+1,1}=r.comparison; end %#ok<AGROW>
        states{k}=r.status;
    catch ME
        states{k}=struct('model',id,'seed',seed,'status',"unreadable_case_report", ...
            'phase',"collect",'message',string(ME.message));
    end
end
S=struct2table(vertcat(states{:}));
writetable(S,fullfile(out,'case_status.csv'));
if ~isempty(rows)
    T=sortrows(struct2table(vertcat(rows{:})),{'model','seed','condition'});
    writetable(T,fullfile(out,'all_results.csv'));
end
C=table();
if ~isempty(comparisons)
    C=sortrows(struct2table(vertcat(comparisons{:})),{'model','seed'});
    writetable(C,fullfile(out,'comparison.csv'));
end
summaries=cell(0,1);
for id=reshape(unique(cases.model,'stable'),1,[])
    A=S(S.model==id,:); n=0;
    if ~isempty(C), G=C(C.model==id,:); n=height(G); end
    h=struct('model',id,'expected_runs',sum(cases.model==id), ...
        'complete_cases',sum(A.status=="complete"),'incomplete_or_failed_cases',sum(A.status~="complete"), ...
        'comparisons_available',n,'finite_new_estimates',NaN,'baselines_reproduced',NaN, ...
        'original_under_reference',NaN,'new_under_reference',NaN, ...
        'new_within_one_percent',NaN,'new_independently_non_target',NaN, ...
        'new_independently_target',NaN,'postcheck_not_verified',NaN, ...
        'runs_with_unresolved_queries',NaN,'runs_with_forced_non_target',NaN, ...
        'runs_with_recurrence',NaN,'time_guard_hits',NaN, ...
        'non_target_cache_hits',NaN);
    if n>0
        h.finite_new_estimates=sum(isfinite(G.no_negative_reuse_R));
        h.baselines_reproduced=sum(G.baseline_reproduced==1);
        h.original_under_reference=sum(G.recorded_R<G.R_reference-1e-10);
        h.new_under_reference=sum(G.no_negative_reuse_R<G.R_reference-1e-10);
        h.new_within_one_percent=sum(abs(G.new_signed_error_percent)<=1);
        h.new_independently_non_target=sum(G.postcheck=="both_solvers_support_non_target");
        h.new_independently_target=sum(G.postcheck=="both_solvers_support_target");
        h.postcheck_not_verified=sum(G.postcheck~="both_solvers_support_non_target");
        h.runs_with_unresolved_queries=sum(G.new_unresolved_count>0);
        h.runs_with_forced_non_target=sum(G.new_forced_non_target_count>0);
        h.runs_with_recurrence=sum(G.new_recurrence_count>0);
        h.time_guard_hits=sum(G.time_guard_hit==1);
        h.non_target_cache_hits=sum(G.new_non_target_cache_hits);
    end
    summaries{end+1,1}=h; %#ok<AGROW>
end
writetable(struct2table(vertcat(summaries{:})),fullfile(out,'causal_summary.csv'));
fprintf('Collected %d/%d complete cases; %d paired comparisons.\n', ...
    sum(S.status=="complete"),height(cases),height(C));
end
