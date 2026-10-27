function trace=diagnostic_replay(d,saved,row,out,o)
% AI-assisted instrumentation of the frozen classifier's learning rules.
% Replays saved queries in their original order, not a new adaptive search.
% Calls the original snapshot integrator and step function without editing them.
g=sampled_forward_geometry(d); initialTarget=g.cell_c;
owners={containers.Map('KeyType','double','ValueType','any'), ...
    containers.Map('KeyType','double','ValueType','any'), ...
    containers.Map('KeyType','double','ValueType','any')};
for cellId=reshape(initialTarget,1,[]), owners{1}(cellId)=[0,0,NaN,NaN]; end
rows=cell(numel(saved),1); keptTrajectories=cell(numel(saved),1);
parents=zeros(numel(saved),1); reproduced=true;
for k=1:numel(saved)
    expected=saved{k}; z=reshape(expected.initial_state,1,[]);
    assert(expected.integration_count==1,'Unsupported non-integrated query %d.',k);
    [xt,cells,tipo,count,rhsCalls]=sampled_forward_integrate(d,g,z);
    xt=xt(1:count,:); cells=cells(1:count); rawTipo=tipo;
    cacheKind=0; parent=[0,0,NaN,NaN];
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
        outside=any(xt(end,:)<=d.domain(1:2) | xt(end,:)>=d.domain(3:4));
        if outside, reason="left_computational_domain";
        else, reason="known_domain_exit_grid_cell"; cacheKind=3; end
    elseif tipo==4
        reason="native_non_target_recurrence";
    else
        error('Unexpected classifier kind %g.',tipo);
    end
    if cacheKind>0
        assert(isKey(owners{cacheKind},cells(end)),'Missing grid provenance.');
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
    bounds=cell_bounds(cells(end),d);
    ordered=unique(cells,'stable'); learned=ordered(1:end-1);
    rows{k}=struct('query',k,'x0',z(1),'v0',z(2), ...
        'radius',double(expected.initial_radius),'label',label,'reason',reason, ...
        'time',(count-1)*d.Ts,'sample_count',count,'cell_id',cells(end), ...
        'hit_x',xt(end,1),'hit_v',xt(end,2),'parent_query',parent(1), ...
        'parent_sample',parent(2),'donor_x',parent(3),'donor_v',parent(4), ...
        'cell_x_min',bounds(1),'cell_x_max',bounds(2), ...
        'cell_v_min',bounds(3),'cell_v_max',bounds(4), ...
        'min_radius',minRadius,'min_point_difference',minPointDifference, ...
        'rhs_count',rhsCalls,'rhs_count_matches',rhsCalls==expected.rhs_count, ...
        'native_tipo',rawTipo,'cache_kind',cacheKind,'saved_reason',string(expected.classification_reason), ...
        'matches_saved',match,'terminal_cell_propagated',ismember(cells(end),learned));
    if cacheKind==0 || k==row.winning_query || k==row.first_under_query
        keptTrajectories{k}=struct('query',k,'t',(0:count-1)'*d.Ts,'states',xt,'cells',cells);
    end
    if ~match
        reproduced=false;
        fprintf(2,'STOP: saved classification not reproduced at query %d.\n',k);
        break
    end
    % Preserve exactly: stable-unique first, then discard the last unique cell.
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
    if mod(k,o.verboseEvery)==0 || k==numel(saved)
        writetable(struct2table(vertcat(rows{1:k})),fullfile(out,'query_provenance_partial.csv'));
        fprintf('  replay %d/%d, saved labels and sample counts match\n',k,numel(saved));
    end
end
T=struct2table(vertcat(rows{1:k}));
writetable(T,fullfile(out,'query_provenance.csv'));
trace=struct('reproduced',reproduced,'queries',T,'selected',row, ...
    'trajectories',{keptTrajectories(1:k)},'winning_chain',[],'first_under_chain',[]);
if reproduced
    trace.winning_chain=ancestry(row.winning_query,parents);
    if isfinite(row.first_under_query), trace.first_under_chain=ancestry(row.first_under_query,parents); end
    unsafe=T.label=="non_target";
    assert(abs(min(T.radius(unsafe))-row.R_hat)<1e-10);
    W=T(trace.winning_chain,:); W.chain_depth=(0:height(W)-1)';
    writetable(W,fullfile(out,'winning_label_chain.csv'));
    if ~isempty(trace.first_under_chain)
        W=T(trace.first_under_chain,:); W.chain_depth=(0:height(W)-1)';
        writetable(W,fullfile(out,'first_under_label_chain.csv'));
    end
    groups=groupsummary(T,'reason');
    writetable(groups,fullfile(out,'replayed_reason_counts.csv'));
end
save(fullfile(out,'replay_details.mat'),'trace','d','-v7.3');
end

function ids=ancestry(q,parents)
ids=q;
while parents(q)>0
    next=parents(q); assert(next<q,'Invalid/cyclic label provenance.');
    ids(end+1)=next; q=next; %#ok<AGROW>
end
end
function bounds=cell_bounds(id,d)
if id<1 || id>d.discr^2, bounds=nan(1,4); return; end
ix=floor((id-1)/d.discr)+1; iv=mod(id-1,d.discr)+1;
h=(d.domain(3:4)-d.domain(1:2))/d.discr;
bounds=[d.domain(1)+(ix-1)*h(1),d.domain(1)+ix*h(1), ...
    d.domain(2)+(iv-1)*h(2),d.domain(2)+iv*h(2)];
end
