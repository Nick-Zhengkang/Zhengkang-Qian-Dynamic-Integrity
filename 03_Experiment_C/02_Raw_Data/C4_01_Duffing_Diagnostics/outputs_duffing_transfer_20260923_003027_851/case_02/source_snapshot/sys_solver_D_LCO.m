function sol_out=sys_solver_D_LCO(Ts,sol_prev,par,flag_init,tols,Poincare_sec,event_on)
% returns the solution of the delayed system in the next Ts interval, or
% until the next event
% flag init shows whether the initial condition is the output of the
% function handle for theta\in[-tau,0], or the initial condition is in the form of the
% output of the built in dde23 function 

% set the options for the dde23 solver. Poincare section is catched as an
% event
% if the system would be non-smooth, that could be also handled here.
option=ddeset('RelTol', tols(1), 'AbsTol', tols(2),'Jumps',0,'Events',@(t,y,YDEL) eventsFcn(t,y,YDEL,par,Poincare_sec,event_on));


tact = 0;
sol_out = [];
while tact<Ts % the solution is carried out until Ts is reached or until the next Poincare section (if event_on=1)
    if flag_init == 1 % the initial state is an output of a function handle sol_prev(t)
        sol=dde23 (@(t,xt,xtdel) sistema(t,xt,xtdel,par), par.tau,@(t) sol_prev(t) ,[tact Ts], option);
        flag_init = 0;
        sol_out = sol;
    else % the initial state in [-tau,0] is the combination of several short simulations obtained in this function -> combine_sol_prev
        sol=dde23 (@(t,xt,xtdel) sistema(t,xt,xtdel,par), par.tau,@(t) combine_sol_prev(sol_prev,t) ,[tact Ts], option);
        if isempty(sol_out)
            sol_out = sol;
        else % combine the solutions in one variable
            sol_out.x = [sol_out.x, sol.x(2:end)];
            sol_out.y = [sol_out.y, sol.y(:,2:end)];
            sol_out.yp = [sol_out.yp, sol.yp(:,2:end)];
        end
    end
    tact = sol.x(end);
    if ~isempty(sol.ie)
        if sol.ie(end) == 1 % Poincare section
            break;
        end
    end
end

% get the state at time t
function sol_prev = combine_sol_prev(sol,t)
    if t<sol.x(1)
        sol_prev = sol.history(t);
    else
        sol_prev = deval(sol,t);
    end
end

% Event function. Right now it is only checking the Poincare section,
% however, it could also be used for other types of events.
function [value,isterminal,direction] = eventsFcn(t,y,YDEL,par,Poincare_sec,event_on) % event occurs when value(i)=0, isterminal(i) -> halt integration, direction= -1 -> event function decreasing
    % Poincare section
    value(1) = y(Poincare_sec(1))-Poincare_sec(2);
    if t>par.tau && event_on == 1 % it stops only, if t>tau and event_on = 1
        isterminal(1) = 1;
    else
        isterminal(1) = 0;
    end
    direction(1) = 1;
end

end