function [label,nRhs,tEnd,traj]=classify_bistable_duffing(x0,m,c)
nRhs=0; tEnd=0; label=0; traj=x0(:).';
if c.synthetic
    radius=norm((x0-m.target).*sqrt(m.weight));
    label=1+(radius>=0.78 && radius<=0.90); return
end
% E<0 and well sign certify trapping for positive quadratic drag.
E=@(z) z(2)^2/2-z(1)^2/2+z(1)^4/4;
if E(x0)<-c.energyMargin, label=1+(x0(1)>0); return; end
opts=odeset('RelTol',c.RelTol,'AbsTol',c.AbsTol,'MaxStep',c.MaxStep,'Events',@trapped);
state=x0(:); start=0;
for finish=c.timeStages
    [t,y,te,ye]=ode45(@rhs,[start finish],state,opts);
    traj=[traj;y(2:end,:)]; %#ok<AGROW>
    tEnd=t(end); state=y(end,:)';
    if ~isempty(te), label=1+(ye(end,1)>0); return; end
    if E(state)<-c.energyMargin, label=1+(state(1)>0); return; end
    if tEnd<finish-1e-8 || any(~isfinite(state)), return; end
    start=finish;
end
    function dz=rhs(~,z)
        nRhs=nRhs+1;
        dz=[z(2);-m.alpha*abs(z(2))*z(2)+z(1)-z(1)^3];
    end
    function [value,terminal,direction]=trapped(~,z)
        value=E(z)+c.energyMargin; terminal=1; direction=-1;
    end
end
