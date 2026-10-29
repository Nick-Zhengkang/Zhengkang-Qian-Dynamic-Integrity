function T=retest4d_compare(result,details,saved)
% AI-assisted comparison of complete query sequences, excluding wall time.
a=details.query_records; b=saved.details.query_records;
if isstruct(a), a=num2cell(a); end
if isstruct(b), b=num2cell(b); end
n=max(numel(a),numel(b)); rows=cell(n,1);
summaryMatch=numel(a)==numel(b) && abs(result.R_hat-saved.row.R_hat)<1e-10 && ...
    result.query_count==saved.row.query_count && result.direction_count==saved.row.direction_count && ...
    string(result.stop_status)==string(saved.row.stop_status);
for k=1:n
    q=struct('query',k,'summary_matches',summaryMatch,'state_difference',Inf, ...
        'min_point_difference',Inf,'decision_matches',false,'rhs_count_matches',false,'matches',false);
    if k<=numel(a) && k<=numel(b)
        x=a{k}; y=b{k};
        q.state_difference=norm(x.initial_state-y.initial_state,Inf);
        q.min_point_difference=norm(x.min_point-y.min_point,Inf);
        q.decision_matches=string(x.label)==string(y.label) && ...
            string(x.classification_reason)==string(y.classification_reason) && ...
            x.native_tipo==y.native_tipo && x.sample_count==y.sample_count && ...
            x.grid_cache_kind==y.grid_cache_kind && x.forced_non_target==y.forced_non_target && ...
            x.integration_count==y.integration_count && abs(x.end_time-y.end_time)<1e-10 && ...
            abs(x.min_radius-y.min_radius)<1e-8;
        q.rhs_count_matches=x.rhs_count==y.rhs_count;
        q.matches=summaryMatch && q.decision_matches && q.state_difference<1e-10 && ...
            q.min_point_difference<1e-8;
    end
    rows{k}=q;
end
assert(n>0,'No control queries were recorded.');
T=struct2table(vertcat(rows{:}));
end

