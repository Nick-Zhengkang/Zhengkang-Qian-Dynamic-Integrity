function [result,history,queries]=angular_engine(method,m,c,oracle,timer)
improved=strcmp(method,'angular_improved');
if strcmp(method,'uniform_fixed'), n=c.uniformDirections; else, n=c.initialDirections; end
offset=2*pi*rand;
rays=repmat(new_ray(0,c),1,n);
for k=1:n, rays(k).theta=mod(offset+2*pi*(k-1)/n,2*pi); end
qlog=zeros(c.queryBudget,13); hlog=zeros(c.queryBudget,7);
ne=0; rhs=0; nOde=0; unknown=0; best=Inf;
added=0; rounds=0; stagnant=0; previous=Inf; reason='query_budget';
while ne<c.queryBudget
    if toc(timer)>=c.maxSeconds, reason='time_budget'; break; end
    active=[];
    for k=1:numel(rays)
        r=rays(k);
        if r.blocked || r.capped || r.pruned, continue; end
        if improved && isfinite(best) && r.lo>=best
            rays(k).pruned=true; continue
        end
        if isfinite(r.hi)
            if improved
                done=r.hi-r.lo<=c.radialTolerance;
            else
                done=r.depth>=c.fixedBisections || r.hi-r.lo<=c.radialTolerance;
            end
            if done, continue; end
        end
        active(end+1)=k; %#ok<AGROW>
    end
    if isempty(active)
        if strcmp(method,'uniform_fixed'), reason='fixed_search_complete'; break; end
        if improved
            rounds=rounds+1;
            tolerance=c.stopAbsoluteChange+c.stopRelativeChange*best;
            if isfinite(previous) && isfinite(best) && previous-best<=tolerance
                stagnant=stagnant+1;
            else, stagnant=0; end
            previous=best;
            [globalGap,localGap]=coverage(rays);
            if rounds>=c.minRounds && stagnant>=c.patience && ...
                    globalGap<=c.globalGapLimit*(1+1e-12) && ...
                    localGap<=c.localGapLimit*(1+1e-12) && ...
                    ~any([rays.blocked]) && isfinite(best)
                reason='heuristic_plateau_with_coverage'; break
            end
        end
        if numel(rays)>=c.maxDirections, reason='direction_limit'; break; end
        if improved, batch=min(c.batchSize,c.maxDirections-numel(rays)); else, batch=1; end
        for b=1:batch
            added=added+1;
            theta=next_angle(rays,added,c,improved,b);
            rays(end+1)=new_ray(theta,c); %#ok<AGROW>
        end
        continue
    end
    if strcmp(method,'angular_legacy')
        k=active(1);
    else
        % Round-robin per active batch avoids hiding untested initial angles.
        [~,i]=min([rays(active).calls]); k=active(i);
    end
    r=rays(k); hadBracket=isfinite(r.hi);
    if hadBracket, radius=(r.lo+r.hi)/2;
    else
        radius=r.probe;
        if improved && isfinite(best), radius=min(radius,best); end
    end
    x0=m.target+radius*[cos(r.theta) sin(r.theta)]./sqrt(m.weight);
    measured=sqrt(sum(m.weight.*(x0-m.target).^2));
    assert(abs(measured-radius)<1e-12*max(1,radius));
    [label,ncall,tend]=oracle(x0);
    ne=ne+1; rhs=rhs+ncall; nOde=nOde+(ncall>0); unknown=unknown+(label==0);
    r.calls=r.calls+1;
    if label==1
        r.lo=radius;
        if ~hadBracket
            if radius>=c.maxRadius-1e-12, r.capped=true;
            else, r.probe=min(c.maxRadius,radius+c.scanStep); end
        end
    elseif label==2
        r.hi=radius; best=min(best,radius);
    else, r.blocked=true;
    end
    if hadBracket && label>0, r.depth=r.depth+1; end
    rays(k)=r;
    estimate=best; if isinf(estimate), estimate=NaN; end
    elapsed=toc(timer);
    qlog(ne,:)=[ne k r.theta radius label ncall tend r.lo r.hi x0 measured elapsed];
    hlog(ne,:)=[ne estimate elapsed rhs unknown numel(rays) nOde];
end
elapsed=toc(timer); if isinf(best), best=NaN; end
[globalGap,localGap]=coverage(rays);
result=struct('R',best,'runtime',elapsed,'queries',ne,'odeCalls',nOde,'rhs',rhs, ...
    'unknown',unknown,'directions',numel(rays),'capped',sum([rays.capped]), ...
    'pruned',sum([rays.pruned]),'blocked',sum([rays.blocked]), ...
    'reason',reason,'globalGap',globalGap,'localGap',localGap);
% Record stop-decision overhead as a final observation as well.
hlog=hlog(1:ne,:);
hlog(end+1,:)=[ne best elapsed rhs unknown numel(rays) nOde];
history=array2table(hlog,'VariableNames',{'traj_evals','LIM','runtime_s','rhs_evals', ...
    'unknown_evals','n_directions','ode_trajectories'});
queries=array2table(qlog(1:ne,:),'VariableNames',{'query','ray_id','theta','radius', ...
    'label','rhs_evals','integration_end_time','r_safe','r_unsafe','x0','v0', ...
    'weighted_radius_check','elapsed_s'});
end

function r=new_ray(theta,c)
r=struct('theta',theta,'lo',0,'hi',Inf,'probe',min(c.scanStep,c.maxRadius), ...
    'calls',0,'depth',0,'blocked',false,'capped',false,'pruned',false);
end

function [globalGap,localGap]=coverage(rays)
[theta,order]=sort([rays.theta]); gaps=diff([theta theta(1)+2*pi]);
globalGap=max(gaps); hi=[rays(order).hi];
[value,k]=min(hi);
if isfinite(value), previous=mod(k-2,numel(theta))+1; localGap=max(gaps([previous k]));
else, localGap=Inf; end
end

function theta=next_angle(rays,added,c,improved,batchIndex)
[angles,order]=sort([rays.theta]); gaps=diff([angles angles(1)+2*pi]);
hi=[rays(order).hi]; [best,k]=min(hi);
if improved && isfinite(best) && batchIndex<=2
    previous=mod(k-2,numel(angles))+1;
    choices=[previous k]; [~,j]=max(gaps(choices)); i=choices(j);
elseif mod(added,c.globalEvery)==0 || (improved && batchIndex==3 && max(gaps)>c.globalGapLimit)
    [~,i]=max(gaps);
else
    next=hi([2:end 1]); local=min(hi,next);
    if ~isfinite(best), best=c.scanStep; end
    local(~isfinite(local))=c.maxRadius;
    [~,i]=max(gaps./(0.05+max(0,local-best)));
end
theta=mod(angles(i)+gaps(i)/2,2*pi);
end
