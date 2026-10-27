function xe=initial_simulation(dim,par,varargin)
% initial_simulation(dim,par,varargin)
%
% Perform a simulation of the system with the initial conditions x0 (by 
% default a zero vector, unless differently indicated), find the periodic
% solution by continuiying the simulation until a periodic solution is
% found.
% It require to insert in input an excitation frequency omega [rad/s],
% which should be included as the last parameter of par.
% it works only for forced systems and find solutions of period
% T=2*pi/omega.
% dim: dimension of the system (excluding time/phase)
% par: parameter of the system, the last parameter must be the forcing
% frequency in [rad/s].
% Set "ask" to 1 to be asked if the solution obtained is the desired one
% before accepting it.
% Set "ask" to 0 to be have the solution obtained automatically accepted
% x0: vector of initial conditions (default zero vector)
% points: number of points to discretize the periodic solution (default value
% 15)
% toll_per: tollerance within which a solution is considered periodic
% (distance between two points at time distance 2*pi/omega
% reltol: relative tollerance of the simulation
% abstol: absolute tollerance of the simulation
% num_period: minimumal number of periods performed by the simulation
% var1: plotting variable 1 in the phase space (var1<=dim)
% var2: plotting variable 2 in the phase space (var2<=dim)
% count_max: maximal number of repetition until periodic solution is found
% plot_please: 1 if you want the conde to plot the periodic colution,
% otherwise 0

p = inputParser;

% parameters for the simulation
DEFask = 0; % ask if the solution is the desred one or not
DEFx0 = zeros(1,dim); % initial condition
DEFpoints = 15; % number of points to discretize the periodic solution
DEFreltol = 1e-8; % relative tollerance of the simulation
DEFabstol = 1e-8; % absolute tollerance of the simulation
DEFtoll_per = 1e-8; % tollerance within which a solution is considered periodic
DEFnum_period = 50; % minimumal number of periods performed by the simulation
DEFvar1 = 1; % plotting variable 1 in the phase space
DEFvar2 = 2; % plotting variable 2 in the phase space
DEFcount_max = 10; % maximal number of repetition until periodic solution is found
DEFplot_please = 0;

% optional input organization
addOptional(p,'ask',DEFask);
addOptional(p,'x0',DEFx0);
addOptional(p,'points',DEFpoints);
addOptional(p,'reltol',DEFreltol);
addOptional(p,'abstol',DEFabstol);
addOptional(p,'toll_per',DEFtoll_per);
addOptional(p,'num_period',DEFnum_period);
addOptional(p,'var1',DEFvar1);
addOptional(p,'var2',DEFvar2);
addOptional(p,'count_max',DEFcount_max);
addOptional(p,'plot_please',DEFplot_please);

parse(p,varargin{:});
ask = p.Results.ask;
x0 = p.Results.x0;
points = p.Results.points;
reltol = p.Results.reltol;
abstol = p.Results.abstol;
toll_per = p.Results.toll_per;
num_period = p.Results.num_period;
var1 = p.Results.var1;
var2 = p.Results.var2;
count_max = p.Results.count_max;
plot_please = p.Results.plot_please;

% parse(p,varargin{:});

Per = 2*pi/par(end); % period as inverse of excitation frequency
option = odeset('RelTol', reltol, 'AbsTol', abstol); % tollerances for the simulations
[t,x] = ode45 (@(t,xt) sistema(t,xt,par), [0:Per:num_period*Per], x0, option); % single simulation of length num_period*Per
Errore = norm(x(end,:)-x(end-1,:)); % calculate error with respect to a periodic solution (distance between two points at one period time-distance)
count = 0;
while Errore>toll_per 
    count = count+1;
    x0 = x(end,:); % last point as initial point for new simulation
    [t,x] = ode45 (@(t,xt) sistema(t,xt,par), [0:Per:num_period*Per], x0, option); % single simulation of length num_period*Per
    Errore = norm(x(end,:)-x(end-1,:)); % calculate error with respect to a periodic solution (distance between two points at one period time-distance)
    if count>count_max % too many simulation were performed, stop the computation and explain the error
        [t,x] = ode45 (@(t,xt) sistema(t,xt,par), [0 Per], x0, option); % single simulation of one period length for visual inspection
        figure;plot(x(:,var1),x(:,var2));title('The algorithm could not calssify this trajectory as periodic')
        error(['Error: the maximal number of simulation was performed and the system did not reach any periodic solution. Also based on the ' ...
            'last figure displayed, make sure that the system reaches a periodic solution. If not, either change the initial condition x0, incraese count_max, increase num_period, ' ...
            'decrease toll_per (if visually you would define the solution as periodic)'])
    end
end
x0 = x(end,:); % last point as initial point for new simulation
[~,xe] = ode45 (@(t,xt) sistema(t,xt,par), [0:Per/points:Per], x0, option); % single simulation of one period length for obatining he periodic solution
[~,x] = ode45 (@(t,xt) sistema(t,xt,par), [0 Per], x0, option); % single simulation of one period length for obatining the periodic solution
if ask==1 % is ask==1, it ask to the user to confirm that this is the desired solution
    figure;plot(x(:,var1),x(:,var2));drawnow
    str = join(['Please confirm if this is the desired periodic solution']);
    warning(str)
    confirm = 0;
    while (confirm~=1 && confirm~=2)
        confirm = input('Based on the displayed figure, please, type 1 if this is the desired periodic solution, otherwise type 2 ');
        if (confirm~=1 && confirm~=2)
            disp('Not valid entry, only "1" and "2" are valid entries')
        end
    end
    close;
    if confirm==2
        error('The system did not converged to the desired periodic solution, try changing the initial conditions x0');
    end
end
if plot_plese==1
    figure;plot(x(:,var1),x(:,var2),xe(:,var1),xe(:,var2),'o');
end




