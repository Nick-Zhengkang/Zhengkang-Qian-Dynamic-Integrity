function [label,nRhs,tEnd,traj]=classify_extension(x0,m,c)
% No reference values. Energy trapping + forward dynamics of the new models.
label=0; nRhs=0; tEnd=0; traj=x0(:).'; state=x0(:); start=0;
isPaper=strcmp(m.name,'paper_unforced_duffing');
if isPaper
    if m.energy(traj)<-c.energyMargin, label=1+(state(1)>0); return; end
else
    if abs(state(1))>=pi, label=2; return; end
    if m.energy(traj)<1-c.energyMargin, label=1; return; end
end
opts=odeset('RelTol',c.RelTol,'AbsTol',c.AbsTol,'MaxStep',c.MaxStep,'Events',@events);
for finish=c.timeStages
    [t,y,te,ye,ie]=ode45(@rhs,[start finish],state,opts);
    traj=[traj;y(2:end,:)]; %#ok<AGROW>
    tEnd=t(end); state=y(end,:)';
    if ~isempty(te)
        if isPaper, label=1+(ye(end,1)>0);
        elseif ie(end)==1, label=1;
        else, label=2;
        end
        return
    end
    if any(~isfinite(state)) || tEnd<finish-1e-8, return; end
    if isPaper && m.energy(state')<-c.energyMargin
        label=1+(state(1)>0); return
    elseif ~isPaper
        if abs(state(1))>=pi, label=2; return; end
        if m.energy(state')<1-c.energyMargin, label=1; return; end
    end
    start=finish;
end
% An unresolved trajectory stays unknown, rather than being called unsafe.
    function dz=rhs(~,z)
        nRhs=nRhs+1;
        if isPaper, acc=-2*m.alpha*z(2)+z(1)-z(1)^3;
        else, acc=-m.alpha*abs(z(2))*z(2)-sin(z(1));
        end
        dz=[z(2);acc];
    end
    function [v,terminal,direction]=events(~,z)
        if isPaper
            v=m.energy(z')+c.energyMargin; terminal=1; direction=-1;
        else
            v=[m.energy(z')-1+c.energyMargin;pi-abs(z(1))];
            terminal=[1;1]; direction=[-1;-1];
        end
    end
end
