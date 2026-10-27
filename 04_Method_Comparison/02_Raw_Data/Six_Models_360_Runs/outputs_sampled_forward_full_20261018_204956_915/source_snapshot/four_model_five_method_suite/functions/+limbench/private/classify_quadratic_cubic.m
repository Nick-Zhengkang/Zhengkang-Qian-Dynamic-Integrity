function [label,nRhs,tEnd,traj]=classify_quadratic_cubic(x0,m,c)
nRhs=0; tEnd=0; label=0; traj=x0(:).';
if c.synthetic
    radius=norm((x0-m.target).*sqrt(m.weight));
    label=1+(radius>=0.78 && radius<=0.90); return
end
% E<1/6 in the well component x<1 implies trapping; E'=-alpha*|v|^3.
% The exterior component can also have E<1/6 and must NOT be called safe.
E=@(z) z(2)^2/2+z(1)^2/2-z(1)^3/3;
barrier=1/6;
if x0(1)<1 && E(x0)<barrier-c.energyMargin, label=1; return; end
% x>=1, v>=0 is forward invariant and cannot return to the target.
if x0(1)>=1 && x0(2)>=0, label=2; return; end
opts=odeset('RelTol',c.RelTol,'AbsTol',c.AbsTol,'MaxStep',c.MaxStep,'Events',@trapped);
state=x0(:); start=0;
for finish=c.timeStages
    [t,y,te,ye,ie]=ode45(@rhs,[start finish],state,opts);
    traj=[traj;y(2:end,:)]; %#ok<AGROW>
    tEnd=t(end); state=y(end,:)';
    if ~isempty(te)
        if ie(end)==1 && ye(end,1)<1
            label=1;
        elseif ie(end)==2 && ye(end,1)>=1-1e-10 && ye(end,2)>=-1e-10
            label=2;
        end
        return
    end
    if state(1)<1 && E(state)<barrier-c.energyMargin, label=1; return; end
    if state(1)>=1 && state(2)>=0, label=2; return; end
    if tEnd<finish-1e-8 || any(~isfinite(state)), return; end
    start=finish;
end
    function dz=rhs(~,z)
        nRhs=nRhs+1;
        dz=[z(2);-m.alpha*abs(z(2))*z(2)-z(1)+z(1)^2];
    end
    function [value,terminal,direction]=trapped(~,z)
        % max gates the energy event to the well, without a discontinuity.
        % The second event also catches exterior inward motion turning outward.
        value=[max(E(z)-barrier+c.energyMargin,z(1)-1); min(z(1)-1,z(2))];
        terminal=[1;1]; direction=[-1;1];
    end
end
