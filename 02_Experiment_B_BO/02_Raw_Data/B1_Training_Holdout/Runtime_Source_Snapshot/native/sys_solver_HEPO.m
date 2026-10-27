function [tout,x]=sys_solver_HEPO(t0,tend,x0,par,tols)

options_F2S = odeset('Events', @(t,z) events_func_F2S(t,z,par),'RelTol', tols(1), 'AbsTol', tols(2));
options_S2F = odeset('Events', @(t,z) events_func_S2F(t,z,par),'RelTol', tols(1), 'AbsTol', tols(2));

re=ground_excitation(t0,par);
hF2S=x0(1)-re(1)-par.eps;
if hF2S >= 0
    phase='flight';
else
    phase='stance';
    x0=[re(1)+par.eps, x0(2), re(2), x0(4)];
end
q0=x0;
t=t0;

while t < tend
    switch phase
        case 'flight'
            [t_phase,Z] = ode45(@(t,z) EoM_F(t, z, par),...
                        [t tend],q0,options_F2S);

            % Was there a collision of the upper and lower masses?
            if min(Z(:,2) - Z(:,1)) <= 0
                Z(end,1)=2*par.upperbound;
                t=tend;
                break
            end

            % asign initial conditions
            t = t_phase(end);

            % the velocity and acceleration of the lower body is the same
            % as the velocity and acceleration of the ground
            re=ground_excitation(t,par);            
            q0 = [Z(end,1:2),re(2),Z(end,4)];

            phase = 'stance';
        case 'stance'
            [t_phase,Z] = ode45(@(t,z) EoM_S(t, z, par),...
                        [t tend],q0,options_S2F);

            % Was there a collision of the upper and lower masses?
            if min(Z(:,2) - Z(:,1)) <= 0
                Z(end,1)=2*par.upperbound;
                t=tend;
                break
            end

            q0 = Z(end,:);
            t = t_phase(end);

            phase = 'flight';
    end
%     plot(t_phase,Z(:,1))
%     plot(t_phase,Z(:,2))
end
x=Z(end,:);
tout=t(end);