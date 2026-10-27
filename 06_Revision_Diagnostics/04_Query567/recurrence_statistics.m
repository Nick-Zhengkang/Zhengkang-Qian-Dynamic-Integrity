function s=recurrence_statistics(previousCells,cellId,d)
% AI-assisted observer of the frozen recurrence expressions, not a classifier.
previousCells=previousCells(:); prior=find(cellId==previousCells); gaps=diff(prior);
s.previous_visit_count=numel(prior);
s.adjacent_gap_count=nnz(gaps==1);
s.nonadjacent_gap_count=nnz(gaps~=1);
s.first_previous_sample=NaN; s.last_previous_sample=NaN;
if ~isempty(prior)
    s.first_previous_sample=prior(1); s.last_previous_sample=prior(end);
end
s.last_previous_is_immediate=~isempty(prior) && prior(end)==numel(previousCells);
s.fixed_condition=s.adjacent_gap_count>d.repFixPoint;
s.periodic_count_gate=numel(prior)>d.repPeriodic+1;
s.periodic_not_immediate_gate=~isempty(prior) && prior(end)~=numel(previousCells);
s.periodic_gate=s.periodic_count_gate && s.periodic_not_immediate_gate;
s.periodic_gap_condition=s.nonadjacent_gap_count>d.repPeriodic;
s.periodic_condition=s.periodic_gate && s.periodic_gap_condition;
s.history_gate=numel(previousCells)+1>3 && ~isempty(prior);
s.counter_branch="none";
if s.history_gate
    if s.fixed_condition
        s.counter_branch="rep_fix_point";
    elseif s.periodic_condition
        s.counter_branch="rep_periodic";
    end
end
lastDifferent=find(previousCells~=cellId,1,'last');
if isempty(lastDifferent), lastDifferent=0; end
s.current_streak_including_current=numel(previousCells)-lastDifferent+1;
end
