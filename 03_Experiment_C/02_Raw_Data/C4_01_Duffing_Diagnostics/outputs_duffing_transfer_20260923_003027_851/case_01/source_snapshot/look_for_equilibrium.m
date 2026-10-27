function xe=look_for_equilibrium(xe0,par,tols,Ts,max_check_step)
% look for an equilibrium point based on an initial condition provided



% checking wether the user input is an equilibrium point, if not it finds it
x_in=xe0;

x_end=zeros(1,length(xe0)); % initialize for checking the convergence
J=0; % initialize counter
while norm(x_in-x_end)>10*min(tols) || J<1
    J=J+1; % increase counter
    if J>max_check_step % if counter exceed maximum number of steps and still not converging, then gives warning and close computation
        warning(['The solution did not converge to the equilibrium point in ', num2str(max_check_step), ' iteration steps. The error ' ...
            'between the last point and the previous one was ',num2str(norm(x_in-x_end)),'. Consider changing the initial guess for the equilibrium provided ' ...
            'or increasing the value of max_check_step, which is an optional input parameter. ' ...
            'It is also possible that the system has no equilibrium solution for the given parameter set'])
        xe=nan;
        flag=0;
        return % quit the function
    end
    if J>1
        x_in=x_end;
    end
    x=sys_solver(Ts,x_in,par,tols); % single simulation of length Ts (one time step)
    x_end=x(end,:);
end
xe=x_end; % set equilibrium to the found value