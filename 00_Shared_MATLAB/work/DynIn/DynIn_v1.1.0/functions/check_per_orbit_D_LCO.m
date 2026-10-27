function sol=check_per_orbit_D_LCO(tend,Ts,sol_init,par,tols,Poincare_sec,number_of_steps,dim,flag_init,event_on)
    
if flag_init == 1
    init = reshape(sol_init,dim/par.N,par.N);
    tvec_disc = flip(linspace(-par.tau,0,par.N));
    sol_init = @(t) interp1(tvec_disc,init.',t);
    sol=sys_solver_D_LCO(Ts,sol_init,par,flag_init,tols,Poincare_sec,event_on);
else
    sol=sys_solver_D_LCO(Ts,sol_init,par,flag_init,tols,Poincare_sec,event_on);
end
    



