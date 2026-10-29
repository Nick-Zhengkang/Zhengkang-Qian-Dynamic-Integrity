function P=retest4d_chain_points(trace)
% AI-assisted audit includes the positive-cache ancestry of the lower point.
T=trace.queries;
ids=[trace.winning_chain,trace.first_under_chain];
q=trace.selection.lower_query;
while q>0
    ids(end+1)=q; %#ok<AGROW>
    parent=T.parent_query(q); assert(parent<q,'Invalid provenance order.'); q=parent;
end
ids=unique(ids,'stable'); points=cell(0,1);
for q=ids
    r=T(q,:);
    points{end+1}=point("chain_initial_state",q,r.initial_state,r.parent_query,r.label); %#ok<AGROW>
    if r.parent_query>0
        points{end+1}=point("cache_hit_state",q,r.hit_state,r.parent_query,r.label); %#ok<AGROW>
        points{end+1}=point("first_writer_state",q,r.donor_state,r.parent_query,r.label); %#ok<AGROW>
    end
end
P=struct2table(vertcat(points{:}));
end

function p=point(role,q,z,parent,label)
p=struct('role',role,'query',q,'state',reshape(z,1,[]), ...
    'parent_query',parent,'original_label',label);
end

