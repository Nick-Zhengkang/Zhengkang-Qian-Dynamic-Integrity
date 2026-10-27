function [r,h,q]=baseline_engine(method,m,c,oracle,timer)
% Common-classifier adapters. Not unmodified end-to-end DynIn reproductions.
ne=0; rhs=0; nOde=0; unknown=0; best=Inf; R=c.maxRadius;
qlog=zeros(c.queryBudget,9); hlog=zeros(c.queryBudget,7);
reason='query_budget'; bestPoint=[NaN NaN];
isGA=ismember(string(method),["coarse_GA","fine_GA"]);
isBis=strcmp(method,'dynin_original_bisection');
if isGA
    generations=c.gaCoarseGenerations;
    if strcmp(method,'fine_GA'), generations=c.gaFineGenerations; end
    cache=[m.target 0];
end
if isBis
    state=struct('count',0,'hasConv',false,'hasDiv',false, ...
        'conv',m.target,'div',[NaN NaN]);
end
if isGA || isBis
    x0=randomIC_radius(2,R,m.target,m.weight);
else
    es=energy_init(m,c);
end
while ne<c.queryBudget
    if toc(timer)>=c.maxSeconds, reason='time_budget'; break; end
    if ~(isGA || isBis)
        [x0,es,done]=energy_next(es,best,bestPoint,m,c);
        if done, reason=es.reason; break; end
    end
    % Candidate generation is inside timing; do not start an ODE after expiry.
    if toc(timer)>=c.maxSeconds, reason='time_budget'; break; end
    [label,ncall,tend,traj]=oracle(x0);
    ne=ne+1; rhs=rhs+ncall; nOde=nOde+(ncall>0); unknown=unknown+(label==0);
    distances=sqrt(sum((traj-m.target).^2.*m.weight,2));
    [dmin,indClosest]=min(distances);
    oldR=R;
    if label==2 && dmin<best
        best=dmin; bestPoint=traj(indClosest,:);
        R=min(c.maxRadius,best);
    end
    if isGA
        % Original GA uses trajectory points within 1.1R, thinned by divR.
        % No cell is assigned a safe label. Unknowns add only the queried point.
        cache=cache(cache(:,3)<=1.1*R,:);
        if label==0
            trace=[x0 sqrt(sum((x0-m.target).^2.*m.weight))];
        else
            inside=distances<1.1*R;
            trace=[traj(inside,:) distances(inside)];
        end
        if ~isempty(trace)
            trace=uniquetol(trace,max(eps,oldR/c.gaDivR),'ByRows',true);
            cache=[cache;trace]; %#ok<AGROW>
        end
        if isempty(cache), cache=[m.target 0]; end
    elseif ~isBis
        es=energy_observe(es,label);
    end
    estimate=best; if ~isfinite(estimate), estimate=NaN; end
    elapsed=toc(timer);
    qlog(ne,:)=[ne x0 label ncall tend dmin elapsed R];
    hlog(ne,:)=[ne estimate elapsed rhs unknown 0 nOde];
    if ne>=c.queryBudget, break; end
    if toc(timer)>=c.maxSeconds, reason='time_budget'; break; end
    if isGA
        % Verbatim DynIn maximin GA helper (including its return convention).
        x0=find_furthest_point_approximate(m.target,R,cache(:,1:2),2,m.weight, ...
            generations,c.gaCrossover,c.gaSelected,c.gaNewcomers,c.gaClones);
    elseif isBis
        [x0,state]=bisection_next(state,label,x0,traj,indClosest,R,m,c);
    end
end
if ~isfinite(best), best=NaN; end
elapsed=toc(timer);
r=struct('R',best,'runtime',elapsed,'queries',ne,'odeCalls',nOde,'rhs',rhs, ...
    'unknown',unknown,'directions',0,'capped',0,'pruned',0,'blocked',unknown, ...
    'reason',reason,'globalGap',NaN,'localGap',NaN);
hlog=hlog(1:ne,:); hlog(end+1,:)=[ne best elapsed rhs unknown 0 nOde];
h=array2table(hlog,'VariableNames',{'traj_evals','LIM','runtime_s','rhs_evals', ...
    'unknown_evals','n_directions','ode_trajectories'});
q=array2table(qlog(1:ne,:),'VariableNames',{'query','x0','v0','label','rhs_evals', ...
    'integration_end_time','trajectory_dmin','elapsed_s','search_radius'});
end

function s=energy_init(m,c)
% Migrated energy/IDW/shell policy; physical labels supplied by common oracle.
s.rSearch=.95*c.maxRadius;
Y=randn(c.energyPool,2);
Y=Y./sqrt(sum(Y.^2,2)).*(s.rSearch*sqrt(rand(c.energyPool,1)));
s.Y=Y; s.X=m.target+Y./sqrt(m.weight);
s.E=m.energy(s.X); s.labels=NaN(c.energyPool,1);
nStructured=floor(.60*c.energyInitial);
nRings=max(3,ceil(sqrt(nStructured))); nPerRing=max(4,ceil(nStructured/nRings));
shellX=[];
for radius=linspace(.15*s.rSearch,.95*s.rSearch,nRings)
    dirs=randn(nPerRing,2); dirs=dirs./sqrt(sum(dirs.^2,2));
    shellX=[shellX;m.target+radius*dirs./sqrt(m.weight)]; %#ok<AGROW>
end
[~,shellIdx]=min(pairdist(s.X,shellX),[],1);
[~,order]=sort(abs(s.E-m.saddleEnergy),'ascend');
nEnergy=min(numel(order),floor(.25*c.energyInitial));
energyIdx=order(1:nEnergy);
nRandom=max(0,c.energyInitial-numel(shellIdx)-nEnergy);
randomIdx=randperm(c.energyPool,min(nRandom,c.energyPool));
s.initial=unique([shellIdx(:);energyIdx(:);randomIdx(:)]);
s.initial=s.initial(1:min(c.energyInitial,numel(s.initial)));
s.initialCount=0; s.activeCount=0; s.refineCount=0;
s.phase='initial'; s.index=0; s.lo=0; s.hi=Inf;
s.direction=[NaN NaN]; s.probe=NaN; s.reason='energy_search_complete';
end

function [x,s,done]=energy_next(s,best,bestPoint,m,c)
done=false; x=[NaN NaN];
if s.initialCount<numel(s.initial)
    s.phase='initial'; s.initialCount=s.initialCount+1;
    s.index=s.initial(s.initialCount); x=s.X(s.index,:); return;
end
unq=find(isnan(s.labels));
if s.activeCount<c.energyActive && ~isempty(unq)
    s.phase='active'; s.activeCount=s.activeCount+1;
    known=s.labels==1 | s.labels==2;
    if ~any(s.labels==1) || ~any(s.labels==2)
        s.index=unq(1);
    else
        D=pairdist(s.Y(unq,:),s.Y(known,:));
        [Ds,ix]=sort(D,2,'ascend'); K=min(12,size(D,2));
        Ds=Ds(:,1:K); ix=ix(:,1:K);
        labels=double(s.labels(known)==1);
        local=reshape(labels(ix(:)),size(ix));
        W=1./(Ds+1e-9).^2;
        pSafe=sum(W.*local,2)./sum(W,2);
        uncertainty=1-abs(2*pSafe-1);
        energyScale=max(1e-6,.12*abs(m.saddleEnergy-m.energy(m.target)));
        energy=exp(-abs(s.E(unq)-m.saddleEnergy)/energyScale);
        width=max(.08*s.rSearch,.18*best);
        shell=exp(-abs(sqrt(sum(s.Y(unq,:).^2,2))-best)/width);
        [~,k]=max(.45*energy+.35*uncertainty+.20*shell);
        s.index=unq(k);
    end
    x=s.X(s.index,:); return;
end
if ~strcmp(s.phase,'refine')
    if ~isfinite(best) || best<=0
        done=true; s.reason='no_usable_unsafe_point'; return;
    end
    s.direction=(bestPoint-m.target).*sqrt(m.weight)/best;
    s.lo=0; s.hi=best; s.phase='refine';
end
if s.refineCount>=c.energyBisections
    done=true; return;
end
s.refineCount=s.refineCount+1;
s.probe=(s.lo+s.hi)/2;
x=m.target+s.probe*s.direction./sqrt(m.weight);
end

function s=energy_observe(s,label)
if strcmp(s.phase,'refine')
    if label==1, s.lo=s.probe;
    elseif label==2, s.hi=s.probe;
    else
        s.refineCount=Inf; s.reason='unknown_during_refinement';
    end
else
    s.labels(s.index)=label;
end
end

function D=pairdist(A,B)
D=sqrt(max(0,sum(A.^2,2)+sum(B.^2,2).'-2*A*B.'));
end
