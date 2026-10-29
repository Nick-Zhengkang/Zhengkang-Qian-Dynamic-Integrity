function r=allcache4d_regression(d,P,out)
% AI-assisted check of the exact previous lower endpoint, with a fresh oracle.
% This diagnostic never changes the cache or query sequence of either search.
assert(height(P)==1 && P.role=="winning_lower");
oracle=allcache4d_classifier(d);
[q,n]=oracle.classify(P.state);
assert(n==1 && ~q.grid_cache_hit,'Regression must not use any learned grid label.');
g=sampled_forward_geometry(d);
[states,cells,kind,count,rhs]=sampled_forward_integrate(d,g,P.state);
assert(kind==q.native_tipo && count==q.sample_count && rhs==q.rhs_count, ...
    'Fresh-oracle trajectory replay differs from classification.');
rule="not_triggered";
if kind==4
    prior=find(cells(1:end-1)==cells(end)); gaps=diff(prior);
    if nnz(gaps==1)>d.repFixPoint
        rule="rep_fix_point";
    elseif numel(prior)>d.repPeriodic+1 && prior(end)~=count-1 && nnz(gaps~=1)>d.repPeriodic
        rule="rep_periodic";
    else
        error('Unexplained recurrence classification.');
    end
end
r=struct('previous_query',P.query,'state',P.state,'label',string(q.label), ...
    'reason',string(q.classification_reason),'recurrence_rule',rule, ...
    'end_time',q.end_time,'sample_count',count,'forced_non_target',q.forced_non_target);
t=(0:count-1)'*d.Ts;
writetable(struct2table(r),fullfile(out,'classification.csv'));
save(fullfile(out,'trajectory.mat'),'P','r','q','t','states','cells','d','-v7.3');
end
