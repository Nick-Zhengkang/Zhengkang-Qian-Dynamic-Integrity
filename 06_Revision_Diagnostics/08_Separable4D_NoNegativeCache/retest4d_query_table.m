function T=retest4d_query_table(records)
% AI-assisted transparent query export; no classification is inferred here.
if isstruct(records), records=num2cell(records); end
rows=cell(numel(records),1);
for k=1:numel(records)
    q=records{k};
    rows{k}=struct('query',q.query_id,'initial_state',q.initial_state, ...
        'radius',q.initial_radius,'label',string(q.label),'reason',string(q.classification_reason), ...
        'cache_kind',q.grid_cache_kind,'native_tipo',q.native_tipo, ...
        'sample_count',q.sample_count,'end_time',q.end_time,'rhs_count',q.rhs_count, ...
        'forced_non_target',q.forced_non_target,'integration_count',q.integration_count);
end
assert(~isempty(rows),'Search produced no queries.');
T=struct2table(vertcat(rows{:}));
end

