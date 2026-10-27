function t=accuracy_times(h,ref,c)
% Right-continuous output held after early termination. Ignore results first
% available after the common wall-clock horizon (a query may overshoot it).
h=h(h.runtime_s<=c.maxSeconds,:); t=table();
for epsilon=c.relativeThresholds
    good=isfinite(h.LIM) & abs(h.LIM-ref.R)/ref.R<=epsilon;
    first=find(good,1); sustained=[];
    if ~isempty(good) && good(end)
        lastBad=find(~good,1,'last');
        if isempty(lastBad), sustained=1; else, sustained=lastBad+1; end
    end
    firstTime=NaN; seconds=NaN; queries=NaN; rhs=NaN;
    if ~isempty(first), firstTime=h.runtime_s(first); end
    hit=~isempty(sustained);
    if hit
        seconds=h.runtime_s(sustained); queries=h.traj_evals(sustained); rhs=h.rhs_evals(sustained);
    end
    score=0; cappedTime=c.maxSeconds;
    if hit, score=100*(1-seconds/c.maxSeconds); cappedTime=seconds; end
    t=[t;table(epsilon,firstTime,hit,seconds,queries,rhs,cappedTime,score, ...
        'VariableNames',{'relative_tolerance','first_hit_s','sustained_hit', ...
        'sustained_time_s','queries_to_accuracy','rhs_to_accuracy','capped_time_s','score_0_100'})]; %#ok<AGROW>
end
end
