function trace=replay_separable4d(d,saved,selection,out,o)
% AI-assisted provenance observer, not a changed classifier or a new search.
% Calls the frozen integrator/step routines; preserves cache priority and the
% exact stable-unique list update, including discarding the last UNIQUE cell.
if isstruct(saved), saved=num2cell(saved); end
dim=numel(d.target); assert(dim==4);
g=sampled_forward_geometry(d); initialTarget=g.cell_c;
owners={containers.Map('KeyType','double','ValueType','any'), ...
    containers.Map('KeyType','double','ValueType','any'), ...
    containers.Map('KeyType','double','ValueType','any')};
for cid=reshape(initialTarget,1,[]), owners{1}(cid)=[0,0,nan(1,dim)]; end
last=max([selection.upper_query,selection.lower_query,selection.first_non_target_below_query]);
rows=cell(last,1); kept=cell(last,1); parents=zeros(last,1); reproduced=true;
special=[selection.upper_query,selection.lower_query,selection.first_non_target_below_query];
for k=1:last
    expected=saved{k}; z=reshape(double(expected.initial_state),1,[]);
    assert(expected.integration_count==1,'Non-integrated query %d requires a separate replay path.',k);
    [xt,cells,tipo,count,rhsCalls]=sampled_forward_integrate(d,g,z);
    xt=xt(1:count,:); cells=cells(1:count); rawTipo=tipo;
    cacheKind=0; parent=[0,0,nan(1,dim)];
    if tipo==0
        tipo=2; reason="horizon_forced_non_target";
    elseif tipo==1
        reason="native_target_neighbourhood";
        if ~ismember(cells(end),initialTarget)
            reason="known_target_grid_cell"; cacheKind=1;
        end
    elseif tipo==2
        reason="known_non_target_grid_cell"; cacheKind=2;
    elseif tipo==3
        outside=any(xt(end,:)<=d.domain(1:dim) | xt(end,:)>=d.domain(dim+1:end));
        if outside, reason="left_computational_domain";
        else, reason="known_domain_exit_grid_cell"; cacheKind=3; end
    elseif tipo==4
        reason="native_non_target_recurrence";
    else
        error('Unexpected native kind %g.',tipo);
    end
    if cacheKind>0
        assert(isKey(owners{cacheKind},cells(end)),'No recorded owner for cached terminal cell.');
        parent=owners{cacheKind}(cells(end));
    end
    parents(k)=parent(1);
    label="non_target"; if tipo==1, label="target"; end
    distances=sqrt(sum((xt-d.target).^2.*d.weight,2));
    [minRadius,imin]=min(distances);
    minPointDifference=norm(xt(imin,:)-reshape(expected.min_point,1,[]),Inf);
    match=rawTipo==expected.native_tipo && count==expected.sample_count && ...
        label==string(expected.label) && reason==string(expected.classification_reason) && ...
        abs(minRadius-expected.min_radius)<=1e-8 && minPointDifference<=1e-8 && ...
        abs((count-1)*d.Ts-expected.end_time)<=1e-8 && cacheKind==expected.grid_cache_kind;
    ordered=unique(cells,'stable'); learned=ordered(1:end-1);
    recurrence="not_triggered"; immediateGaps=0; nonImmediateGaps=0;
    if rawTipo==4
        prior=find(cells(1:end-1)==cells(end)); gaps=diff(prior);
        immediateGaps=nnz(gaps==1); nonImmediateGaps=nnz(gaps~=1);
        if immediateGaps>d.repFixPoint
            recurrence="rep_fix_point";
        elseif numel(prior)>d.repPeriodic+1 && prior(end)~=count-1 && nonImmediateGaps>d.repPeriodic
            recurrence="rep_periodic";
        else
            error('Recurrence trigger cannot be explained by the frozen rules.');
        end
    end
    bounds=cell_bounds(cells(end),d);
    rows{k}=struct('query',k,'initial_state',z,'radius',double(expected.initial_radius), ...
        'label',label,'reason',reason,'time',(count-1)*d.Ts,'sample_count',count, ...
        'cell_id',cells(end),'hit_state',xt(end,:),'parent_query',parent(1), ...
        'parent_sample',parent(2),'parent_time',(parent(2)-1)*d.Ts,'donor_state',parent(3:end), ...
        'cell_lower',bounds(1,:),'cell_upper',bounds(2,:), ...
        'native_tipo',rawTipo,'cache_kind',cacheKind,'recurrence_rule',recurrence, ...
        'immediate_gaps',immediateGaps,'non_immediate_gaps',nonImmediateGaps, ...
        'rhs_count',rhsCalls,'rhs_count_matches',rhsCalls==expected.rhs_count, ...
        'min_radius',minRadius,'min_point_difference',minPointDifference,'matches_saved',match, ...
        'terminal_cell_propagated',ismember(cells(end),learned));
    if cacheKind==0 || ismember(k,special) || ~match
        kept{k}=struct('query',k,'t',(0:count-1)'*d.Ts,'states',xt,'cells',cells);
    end
    if ~match
        reproduced=false;
        fprintf(2,'STOP seed %d at query %d: archived decisions not reproduced.\n',selection.seed,k);
        break
    end
    if tipo==1
        destination=1; g.cell_c=[g.cell_c;learned];
    elseif tipo==3
        destination=3; g.cell_dout=[g.cell_dout;learned];
    else
        destination=2; g.cell_d=[g.cell_d;learned];
    end
    for j=1:numel(learned)
        cid=learned(j);
        if ~isKey(owners{destination},cid)
            sample=find(cells==cid,1,'first');
            owners{destination}(cid)=[k,sample,xt(sample,:)];
        end
    end
    if mod(k,o.verboseEvery)==0 || k==last
        fprintf('Seed %d: replay %d/%d matched.\n',selection.seed,k,last);
    end
end
T=struct2table(vertcat(rows{1:k}));
writetable(T,fullfile(out,'query_provenance.csv'));
trace=struct('reproduced',reproduced,'queries',T,'selection',selection, ...
    'trajectories',{kept(1:k)},'winning_chain',[],'first_under_chain',[], ...
    'replayed_through_query',k,'original_query_count',numel(saved));
if reproduced
    trace.winning_chain=ancestry(selection.upper_query,parents);
    if selection.first_non_target_below_query>0
        trace.first_under_chain=ancestry(selection.first_non_target_below_query,parents);
    end
    W=T(trace.winning_chain,:); W.chain_depth=(0:height(W)-1)';
    writetable(W,fullfile(out,'winning_upper_label_chain.csv'));
    if ~isempty(trace.first_under_chain)
        W=T(trace.first_under_chain,:); W.chain_depth=(0:height(W)-1)';
        writetable(W,fullfile(out,'first_below_reference_label_chain.csv'));
    end
    groups=groupsummary(T,'reason');
    writetable(groups,fullfile(out,'replayed_prefix_reason_counts.csv'));
end
save(fullfile(out,'replay_details.mat'),'trace','d','-v7.3');
end

function ids=ancestry(q,parents)
ids=q;
while parents(q)>0
    next=parents(q); assert(next<q,'Invalid/cyclic provenance.');
    ids(end+1)=next; q=next; %#ok<AGROW>
end
end

function bounds=cell_bounds(id,d)
dim=numel(d.target); bounds=nan(2,dim);
if id<1 || id>d.discr^dim, return; end
remainder=id-1; coord=zeros(1,dim);
for j=1:dim
    stride=d.discr^(dim-j); coord(j)=floor(remainder/stride)+1;
    remainder=mod(remainder,stride);
end
h=(d.domain(dim+1:end)-d.domain(1:dim))/d.discr;
bounds(1,:)=d.domain(1:dim)+(coord-1).*h;
bounds(2,:)=bounds(1,:)+h;
end
