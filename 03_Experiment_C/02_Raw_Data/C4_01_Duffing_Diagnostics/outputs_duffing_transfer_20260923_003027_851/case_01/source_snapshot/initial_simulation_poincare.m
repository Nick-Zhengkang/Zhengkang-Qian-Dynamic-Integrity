function xe=initial_simulation_poincare(dim,par,varargin)
% perform a simulation of the system, by default with zero vector initial
% conditions, looking for the periodic solution.
% it provides in output on point correspondign to the point on the 
% stroboscopic poincaré section of the system.
% dim: dimension of the system (excluding time and phase)
% par: parameter of the system. The last parameter should be the excitation
% frequency in rad/s
% Set "ask" to 1 to be asked if the solution obtained is the desired one
% Set "ask" to 0 to be have the solution obtained automatically accepted
% (TO BE CHECKED, NOT IMPLEMENTED SO FAR)
% x0: vector of initial conditions (default zero vector)
% toll_per: tollerance within which a solution is considered periodic
% (distance between two points at time distance 2*pi/omega
% reltol: relative tollerance of the simulation
% abstol: absolute tollerance of the simulation
% num_period: minimumal number of periods performed by the simulation
% var1: plotting variable 1 in the phase space (var1<=dim)
% var2: plotting variable 2 in the phase space (var2<=dim)
% count_max: maximal number of repetition until periodic solution is found
% plot_period: set to 1 if you want to plot the periodic solution found
% (poincaré map of the periodic solution), otherwise set it to 0

p=inputParser;

% parameters for the simulation
DEFask=0; % ask if the solution is the desred one or not
DEFx0=zeros(1,dim); % initial condition
DEFreltol=1e-8; % relative tollerance of the simulation
DEFabstol=1e-8; % absolute tollerance of the simulation
DEFtoll_per=1e-8; % tollerance within which a solution is considered periodic
DEFnum_period=50; % minimumal number of periods performed by the simulation
DEFvar1=1; % plotting variable 1 in the phase space
DEFvar2=2; % plotting variable 2 in the phase space
DEFcount_max=10; % maximal number of repetition until periodic solution is found
DEFplot_period=0; % if set to 1 the poincaré map of the found periodic solution is plotted

% optional input organization
addOptional(p,'ask',DEFask);
addOptional(p,'x0',DEFx0);
addOptional(p,'reltol',DEFreltol);
addOptional(p,'abstol',DEFabstol);
addOptional(p,'toll_per',DEFtoll_per);
addOptional(p,'num_period',DEFnum_period);
addOptional(p,'var1',DEFvar1);
addOptional(p,'var2',DEFvar2);
addOptional(p,'count_max',DEFcount_max);
addOptional(p,'plot_period',DEFplot_period);

parse(p,varargin{:});
ask=p.Results.ask;
x0=p.Results.x0;
reltol=p.Results.reltol;
abstol=p.Results.abstol;
toll_per=p.Results.toll_per;
num_period=p.Results.num_period;
var1=p.Results.var1;
var2=p.Results.var2;
count_max=p.Results.count_max;
plot_period=p.Results.plot_period;

Per=2*pi/par(end); % period as inverse of excitation frequency
option=odeset('RelTol', reltol, 'AbsTol', abstol); % tollerances for the simulations
[~,x]=ode45 (@(t,xt) sistema(t,xt,par), [0:Per:num_period*Per], x0, option); % single simulation of length num_period*Per
Errore=norm(x(end,:)-x(end-1,:)); % calculate error with respect to a periodic solution (distance between two points at one period time-distance)
count=0;
while Errore>toll_per 
    count=count+1;
    x0=x(end,:); % last point as initial point for new simulation
    [t,x]=ode45 (@(t,xt) sistema(t,xt,par), [0:Per:num_period*Per], x0, option); % single simulation of length num_period*Per
    Errore=norm(x(end,:)-x(end-1,:)); % calculate error with respect to a periodic solution (distance between two points at one period time-distance)
    if count>count_max % too many simulation were performed, stop the computation and explain the error
        [t,x]=ode45 (@(t,xt) sistema(t,xt,par), [0 Per], x0, option); % single simulation of one period length for visual inspection
        figure;plot(x(:,var1),x(:,var2));title('The algorithm could not calssify this trajectory as periodic')
        error(['Error: the maximal number of simulation was performed and the system did not reach any periodic solution. Also based on the ' ...
            'last figure displayed, make sure that the system reaches a periodic solution. If not, either change the initial condition x0, incraese count_max, increase num_period, ' ...
            'decrease toll_per (if visually you would define the solution as periodic)'])
    end
end
xe=x(end,:); % last point as initial point for new simulation
if plot_period==1
    figure;plot(x0(:,var1),x0(:,var2),'go','LineWidth',2);
end

