function [R_final,OutL,OutH]=compute_LIM_HEPO(xe0,par,varargin)

%% LIM_type, plot_in_time, dimp, phase_IC, phase_out

%% Ts nem input többé, de t0 igen

% We are glad you are using our code. We will be happy to receive your
% feedback and help you if needed. If necessary, please contact us at
% habib@mm.bme.hu or dora.patko@mm.bme.hu.
% If you use this software for your research, please cite our paper:
% ????
%
% compute_LIM(xe,par,varargin)
%
% Compute the local integrity measure (LIM) of a fixed point or periodic orbit.
%
% Compulsory input:
% xe: coordinates of the equilibrium point OR coordinates of a point and
% time value close the the periodic solution at that phase
% par: parameters of the dynamical system
% LIM_type: the LIM is calculated for a 1: equilibrium point; 2: periodic orbit.
%
% OUTPUT:
% R_final: final estimated value of the LIM
% R: vector including the estimated LIM value after each iteration
% time_sim: time required for performing the simulations at each iteration
% time_x0: time required for finding each initial condition (null vector
%    for bisection method or random initial condition search)
% time_steps: time required for each step
% time_steps_sim: number of time steps of each simulation
% total_time: total time of the LIM estimation
% distance: apprximate distance between each new initial condition and the
%    closest point already investigated (null vector for bisection method or 
%    random initial condition search)
% vc: vector of all points of converging trajectories
% vd: vector of all points of diverging trajectories
% vdout: vector of all points of trajectories diverging from the phase space
% tipo: characterizaation of each trajectory (1: converging, 2: converged 
%    to a known solution, 3: diverged out of the spaceboundary, 4: converged
%    to a new steady state solution)
% other_solutions_p: new solution identified during the procedure
% num_points_inside: number of points inside the hypersphere of convergence
%    at each step
% x0: list of all the initial conditions utilized
% point_crit: coordinates of the point determining the value of the LIM
% xe: for periodic orbits the coordinates of the solution on the sampling 
% phases with the corresponding time values of the phases; for equilibrium
% points it is the same as xe0
% flag_NaN: 1: dimension, spaceboundary or xe0 is not inserted "legally";
% algorithm did not find periodic solution or some values of it exit the
% spaceboundary
%
% Optional input (for default values open directly the code and see below):
% To insert any of them, use the following syntax:
% Ex.: compute_LIM_FP(xe,par,'tfinal',1000)
% tfinal: maximal final time of each simulation
% weight: weight for computing the weighted distance in the phase space
% type_x0: method for choosing initial conditions. 1: looking for the
%    farthest point from all other points within the hypersphere of
%    convergence; 2: bisection method for finding trajectories starting from
%    the basin boundary (combined with a random scheme); 3: random selection
%    of initial conditions within the hypersphere of convergence.
% reltol: relative tolerance of the simulations (ode45)
% abstol: absolute tolerance (ode45)
% number_of_steps: number of simulation performed
% num_of_cell_around_equilibrium: cells around the equilibrium points 
%    automatically marked as converging. This is to have faster convergence 
%    and avoid false new fixed points around it in case of slow convergence
% num_fig: number of the figure where the trajectories are plotted
% plot_results:  1: plot results after each iteration, 0: do not plot them
% plot_results_final: 1: plot final results, 0: only provide numerical output
% spaceboundary: boundaries of the phase space, example: 
%    spaceboundary=[x1min, x2min, x3min, x1max, x2max, x3max];
% discr: discretization number of the phase space in each direction
% automatic: 0: in case of undefined time series it is asked to the user to
%    decide about the convergence, 1: the algorithm proceed completely
%    automatically imposing as diverging undefined time series
% var1: plotting variable 1 in the phase space
% var2: plotting variable 2 in the phase space
% rep_fix_point: number of repetition in a cell before a new fixed point is defined
% rep_periodic: number of repetition in a cell before a new periodic 
% solution is defined. It must be smaller than "rep_periodic"
% min_periodic_radius: minimal distance between points of a periodc 
% solution such that we can define it as periodic
% check_min_periodic: perform a check on the minimal distance between 
% points of a periodic solution. 0: no check, 1: check.
% plot_in_time: at the end, it plots the periodic solution in 3D (var1,
% var2 against time). Only for periodic orbits. It requires more memory.
% 0: no plot, 1: plot
% Nt: Define the number of phases to check for a periodic orbit
% check_per: if 0 the equilibrium point OR a point of the periodic solution
% is given by the user; 
% if 1 the equilibrium point OR a point of the periodic solution is
% calculated by the program from the user input xe0
% t0: initial time
%
% Optional input for the genetic algorithm for choosing initial conditions
% divR: the larger is this number, more points are kept inside the hypersphere
%    of convergence as individual points.
% num_gen: number of generations considered
% num_crossover: number of individual generated as crossover between the most 
%    fit individuals of the previous generation.
% selected_opt: number of selected best individuals
% newcomers: new individuals with random parameters
% num_almost_clones: number of almost clones of the best individual
%
% Optional input for the bisection method for choosing initial conditions
% bis_iter_max: maximal number of consecutive steps of the bifsection 
%    method for selecting initial conditions

tic
p=inputParser;

dimp=size(xe0,2);
dim=dimp-1;

% parameters for the simulation
DEFtfinal=1000; % maximal final time of each simulation
DEFweight=ones(1,dim); % weight for computing the weighted distance in the phase space
DEFtype_x0=1; % method for choosing initial conditions. 1: farthest point, 2: bisection method, 3: random.
DEFreltol=1e-8; % relative tollerance
DEFabstol=1e-8; % absolute tollerance
DEFnumber_of_steps=50; % number of simulation performed (in the future, this might be changed with an automatic method for terminating the computation)
DEFnum_of_cell_around_equilibrium=3; % cells around the equilibrium to have faster convergence and avoid false new fixed points around it
DEFnum_fig=round(rand*10000); % number of the figure where the trajectories are plotted
DEFplot_results=1; % 1: plot results after each iteration, 0: do not plot them
DEFplot_results_final=1; % 1: plot final results, 0: only provide numerical output
DEFdiscr=1001; % discretization number in each direction
DEFautomatic=0; % 0: in case of undefined time series it is asked to the user to decide about the convergence, 1: the algorithm proceed completely automatically imposing as diverging undefined time series
DEFvar1=1; % plotting variable 1 in the phase space
DEFvar2=2; % plotting variable 2 in the phase space
DEFrep_fix_point=40; % number of repetition in a cell before a new fixed point is defined
DEFrep_periodic=10; % number of repetition in a cell before a new periodic solution is defined
DEFmin_periodic_radius=0.005; % minimal distance between points of a periodic solution such that we can define it as periodic
DEFcheck_min_periodic=0; % perform a check on the minimal distance between points of a periodic solution. 0: no check, 1: check.
DEFplot_in_time=0; %at the end, it plots the periodic solution in 3D (var1, var2 against time). Only for periodic orbits. It requires more memory. 0: no plot, 1: plot
DEFNt=20; % define the number of phases to check for a periodic orbit
DEFcheck_per=1; % define wether the program should check the user input xe0
DEFt0=0; % define the initial time

% coefficients for genetic algorithm for choosing new x0
DEFdivR=40; % the larger is this number, more points are kept inside the hypersphere of convergence as individual points
DEFnum_gen=10; % number of generations considered
DEFnum_crossover=9; % number of individual generated as crossover between to fit individuals
DEFselected_opt=3; % selected best individuals
DEFnewcomers=8; % new individuals with new random parameters
DEFnum_almost_clones=2; % number of almost clones of the best individual

% coefficient for initial condition choose through the bisection method
DEFbis_iter_max=5; % maximal number of steps of the bisection method for x0

% optional input organization
addOptional(p,'tfinal',DEFtfinal);
addOptional(p,'weight',DEFweight);
addOptional(p,'type_x0',DEFtype_x0);
addOptional(p,'reltol',DEFreltol);
addOptional(p,'abstol',DEFabstol);
addOptional(p,'number_of_steps',DEFnumber_of_steps);
addOptional(p,'num_of_cell_around_equilibrium',DEFnum_of_cell_around_equilibrium);
addOptional(p,'num_fig',DEFnum_fig);
addOptional(p,'plot_results',DEFplot_results);
addOptional(p,'plot_results_final',DEFplot_results_final);
addOptional(p,'discr',DEFdiscr);
addOptional(p,'automatic',DEFautomatic);
addOptional(p,'var1',DEFvar1);
addOptional(p,'var2',DEFvar2);
addOptional(p,'rep_fix_point',DEFrep_fix_point);
addOptional(p,'rep_periodic',DEFrep_periodic);
addOptional(p,'min_periodic_radius',DEFmin_periodic_radius);
addOptional(p,'check_min_periodic',DEFcheck_min_periodic);
addOptional(p,'divR',DEFdivR);
addOptional(p,'num_gen',DEFnum_gen);
addOptional(p,'num_crossover',DEFnum_crossover);
addOptional(p,'selected_opt',DEFselected_opt);
addOptional(p,'newcomers',DEFnewcomers);
addOptional(p,'num_almost_clones',DEFnum_almost_clones);
addOptional(p,'bis_iter_max',DEFbis_iter_max);
addOptional(p,'plot_in_time',DEFplot_in_time);
addOptional(p,'Nt',DEFNt);
addOptional(p,'check_per',DEFcheck_per);
addOptional(p,'spaceboundary',[]); % for periodic orbits, the xe is not known yet
addOptional(p,'t0',DEFt0);

parse(p,varargin{:});
% assign values
tfinal=p.Results.tfinal;
weight=p.Results.weight;
type_x0=p.Results.type_x0;
reltol=p.Results.reltol;
abstol=p.Results.abstol;
number_of_steps=p.Results.number_of_steps;
num_of_cell_around_equilibrium=p.Results.num_of_cell_around_equilibrium;
num_fig=p.Results.num_fig;
plot_results=p.Results.plot_results;
plot_results_final=p.Results.plot_results_final;
discr=p.Results.discr;
automatic=p.Results.automatic;
var1=p.Results.var1;
var2=p.Results.var2;
rep_fix_point=p.Results.rep_fix_point;
rep_periodic=p.Results.rep_periodic;
min_periodic_radius=p.Results.min_periodic_radius;
check_min_periodic=p.Results.check_min_periodic;
divR=p.Results.divR;
num_gen=p.Results.num_gen;
num_crossover=p.Results.num_crossover;
selected_opt=p.Results.selected_opt;
newcomers=p.Results.newcomers;
num_almost_clones=p.Results.num_almost_clones;
bis_iter_max=p.Results.bis_iter_max;
plot_in_time=p.Results.plot_in_time;
Nt=p.Results.Nt;
check_per=p.Results.check_per;
spaceboundary=p.Results.spaceboundary;
t0=p.Results.t0;

tols=[reltol,abstol];

% searching for the phases of the periodic orbit
OutL.flag_NaN=0;
Ts=par.T/Nt;
OutL.xe=zeros(Nt+1,dimp);
J=0;
x=xe0;
if check_per==1
    while max(abs(OutL.xe(end,1:dim)-OutL.xe(1,1:dim)))>abstol || J<1
        if max(abs(OutL.xe(end,1:dim)-OutL.xe(1,1:dim)))>1000*abstol && J==1
            warning('The solution is not a periodic orbit, the difference between x(0) and x(T) is more than 1000 times of the absolute tolerance!')
        end
        J=J+1;
        if J>100
            warning(['The solution did not converge to a periodic orbit with T periodtime in 100 iteration steps. The last IC was x(0)=',num2str(OutL.xe(1,1:dim)),' with error=',num2str(OutL.xe(end,1:dim)-OutL.xe(1,1:dim)),' difference between between x(0) and x(T).'])
            OutL.flag_NaN=1;
            R_final=NaN; OutL.R=NaN; OutL.time_sim=NaN; OutL.time_x0=NaN; OutL.time_steps=NaN; OutL.time_steps_sim=NaN; OutL.total_time=NaN;
            OutL.distance=NaN; OutH.vc=NaN; OutH.vd=NaN; OutH.vdout=NaN; OutL.tipo=NaN; OutL.other_solutions_p=NaN; OutL.num_points_inside=NaN;
            OutL.x0=NaN;
            return
        end
%         xe(1,:)=[x,t0];
        OutL.xe(1,:)=x;
        for i=2:Nt+1
            [~,x]=sys_solver_HEPO(t0+Ts*(i-2),t0+Ts*(i-1),OutL.xe(i-1,1:dim),par,tols); % single simulation of length Ts (one time step)
            x=[x(end,:),t0+Ts*(i-1)];
            OutL.xe(i,:)=x;
%             xe(i,:)=x(end,:);
        end
    end
else
    OutL.xe(1,:)=x;
    for i=2:Nt+1
        [~,x]=sys_solver_HEPO(t0+Ts*(i-2),t0+Ts*(i-1),OutL.xe(i-1,1:dim),par,tols); % single simulation of length Ts (one time step)
        x=[x(end,:),t0+Ts*(i-1)];
        OutL.xe(i,:)=x;
    end
end
OutL.xe=OutL.xe(1:Nt,:);

if isempty(spaceboundary)
    spaceboundary=[min(OutL.xe,1:dim)-10, max(OutL.xe,1:dim)+10]; % boundaries of the phase space, example: spaceboundary=[x1min, x2min, x3min, x1max, x2max, x3max];
end

OutL.other_solutions_p={};

OutL.num_fig2=num_fig*2; % figure containint the trend of R
OutL.time_steps=zeros(number_of_steps,1); % for measuring the time required for each step
OutL.time_sim=zeros(number_of_steps,1); % for measuring the time required for each simulation
OutL.time_x0=zeros(number_of_steps,1); % for measuring the time required for each search of initial consitions
OutL.distance=zeros(number_of_steps,1); % distance of each initial condition from other points
OutL.num_points_inside=zeros(number_of_steps,Nt); % number of points inside the hypersphere of convergence at each step
OutL.time_steps_sim=zeros(number_of_steps,1); % number of time steps of each simulation
OutL.total_points_est=round(Nt/3*tfinal/Ts*number_of_steps/4); % maximal total number of points (if it is too large and it generate memory issues, it can be reduced)
OutL.x0=zeros(number_of_steps,dimp); % vector containing all initial conditions utilized

% this is for checking that dimension, spaceboundary and xe are inserted "legally"
out_bound=checkoninput(dim,spaceboundary(1,:),OutL.xe,weight,[var1, var2]);
if out_bound>0.5
    warning('At least one point of the periodic orbit is out of the examined phase space.')
    OutL.flag_NaN=1;
    R_final=NaN; OutL.R=NaN; OutL.time_sim=NaN; OutL.time_x0=NaN; OutL.time_steps=NaN; OutL.time_steps_sim=NaN; OutL.total_time=NaN;
    OutL.distance=NaN; OutH.vc=NaN; OutH.vd=NaN; OutH.vdout=NaN; OutL.tipo=NaN; OutL.other_solutions_p=NaN; OutL.num_points_inside=NaN;
    OutL.x0=NaN;
    return
end

if plot_in_time == 1
    dimv=dimp;
else
    dimv=dim;
end

if type_x0==2
    count_bis_phase=0; % inizialized counter for bisection method at same time section (for periodic orbits)
    count_bis=0; % inizialized counter for bisection method for x0
    there_was_conv=0; % ausiliary variable for bisection method (check if there was a converging trajectory)
    there_was_div=0; % ausiliary variable for bisection method (check if there was a diverging trajectory)
end

% inizialise converging and diverging points and cells
OutH.vc=zeros(OutL.total_points_est,dimv,Nt); % vector of converging points
OutH.vd=zeros(OutL.total_points_est,dimv,Nt); % vector of diverging points
OutH.vdout=zeros(OutL.total_points_est,dimv,Nt); % vector of diverging points out of space boundary
cell_c=zeros(OutL.total_points_est,Nt); % vector of converging cells
cell_d=zeros(OutL.total_points_est,Nt); % vector of diverging cells
cell_dout=zeros(OutL.total_points_est,Nt); % vector of diverging cells out of space boundary
ind_cp=zeros(Nt,1); % index of converging points
ind_dp=zeros(Nt,1); % index of diverging points
ind_doutp=zeros(Nt,1); % index of diverging points out of the phase space
if type_x0==1
%     ind_v_inside=0;
    v_inside=zeros(OutL.total_points_est,dim+1,Nt); % vector of points inside the radius of convergence
    for J=1:Nt
        v_inside(J,:)=[OutL.xe(J,1:dim),0]; % assign the equilibrium as point inside the radius of convergence
    end  
    ind_v_inside=ones(Nt,1); % index of points inside radius of convergence
end
ind_cc=zeros(Nt,1); % index of converging cells
ind_dc=zeros(Nt,1); % index of diverging cells
ind_doutc=zeros(Nt,1); % index of diverging cells
counter_new_sol=0; % counter for new solutions
OutL.tipo=zeros(number_of_steps,1); % type of convergence of each simulation
OutL.R=zeros(number_of_steps+1,1); % radius of convergence at each simulation step
minimum=1e9; % large value for finding the initial R
for i=1:dim % look for the minimal distance between xe and phase space boundary
    for j = 1:Nt
        [minimum,iminimum]=min([minimum,weight(i)^0.5*abs(OutL.xe(j,i)-spaceboundary(i)),weight(i)^0.5*abs(OutL.xe(j,i)-spaceboundary(dim+i))]);
        if iminimum ~= 1
            Jcrit=j;
            OutL.point_crit=OutL.xe(j,:);
%             OutL.point_crit(j,i)=OutL.xe(j,i)-spaceboundary(i);
        end
    end
end
OutL.R(1)=minimum; % initial value of R

dh=zeros(dim,1); % step sizes in each dimension
for i=1:dim
    dh(i)=(spaceboundary(dim+i)-spaceboundary(i))/discr;
end

cell_pos=zeros(discr,dim); % vector including all the used coordinates in each direction (required for finding correct cell)
for i1=1:dim
    cell_pos(:,i1)=[spaceboundary(i1)+dh(i1)/2:dh(i1):spaceboundary(dim+i1)];
end

% find cells of periodic orbit
cell_e=zeros(dim,Nt); % inizialize cell of values of the periodic orbit
for i=1:dim % for each coordinate, look for the corresponding cell index
    for j = 1:Nt
        [~,cell_e(i,j)]=min(abs(cell_pos(:,i)-OutL.xe(j,i)));
    end
end

cell_f_around_eq = zeros(num_of_cell_around_equilibrium^dim-1,Nt);
for i = 1:Nt
    cell_c(ind_cc(i)+1,i)=find_index(cell_e(:,i),dim,discr); % assign to the converging cells the cell containing xe (here ind_cc=0)
    ind_cc(i)=ind_cc(i)+1; % update counter of converging cells
    OutH.vc(ind_cp(i)+1,1:dimv,i)=OutL.xe(i,1:dimv); % assign xe to the converging points
    ind_cp(i)=ind_cp(i)+1; % update counter of converging points
    cell_f_around_eq(:,i)=find_cells_around_a_cell(dim,cell_e(:,i),discr,num_of_cell_around_equilibrium); % find cells around equilibrium cell which are then assigned as converging
    cell_c(ind_cc(i)+1:ind_cc(i)+size(cell_f_around_eq,1),i)=cell_f_around_eq(:,i);
    ind_cc(i)=ind_cc(i)+size(cell_f_around_eq,1); % update counter of converging cells
end

% OutL.x0(1,:)=randomIC_fullspace(dim,spaceboundary); % first initial condition chosen with a random selection
phase_IC=round(1+(Nt-1)*rand());
OutL.x0(1,1:dim)=randomIC_fullspace(dim,spaceboundary); % first initial condition chosen with a random selection
OutL.x0(1,end) = OutL.xe(phase_IC,end);

for i1=1:number_of_steps % cycle over the pre-defined number of steps
    step_tic=tic; % initiate step timer
    sim_tic=tic; % initiate simulation timer
    % perform simulation, provides points, time interval of the point
    % series, cells touched, type of convergence, new solution in cells
    % (empty if the solution is not new), new solution in points (empty if
    % the solution is not new), number of points of the simulation
    %%
    [xt,t,cell_f,OutL.tipo(i1),new_solution_p,OutL.time_steps_sim(i1),phase_out]=simulation_DI_HEPO(dim,par,OutL.x0(i1,:),tfinal,Ts,tols,spaceboundary,discr,cell_c(1:max(ind_cc),:), ...
        cell_d(1:max(ind_dc),:),cell_dout(1:max(ind_doutc),:),cell_pos,dh,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight,Nt,phase_IC);
    puffer_length = 1;
    for j=1:Nt
        [cell_f_puffer,~]=unique(cell_f(:,j),'stable'); % eliminate repeated cells from the cells of the solution
        if length(cell_f_puffer) > puffer_length
            puffer_length = length(cell_f_puffer);
        end
        cell_f(1:length(cell_f_puffer),j) = cell_f_puffer;
    end
    cell_f = cell_f(1:puffer_length,:);
%     [cell_f,~]=unique(cell_f,'stable'); % eliminate repeated cells from the cells of the solution
    OutL.time_sim(i1)=toc(sim_tic); % record time of the simulation
    if OutL.tipo(i1)==0 % in the case of not converged time series, it is asked to the user to choose if he thinks that the time series converges to the desired solution or not, based on a displaced phase space figure
        if automatic==0 % if the computation is not automatic (automatic==0), the user can deside if an undefined time series is converging or not
%             x_plot=xt(:,[var1,var2]);
            x_plot=zeros(size(xt,1)*size(xt,3),2);
            for J = 1:size(xt,1)
                x_plot(size(xt,3)*(J-1)+1:J*size(xt,3),1)=xt(J,var1,:);
                x_plot(size(xt,3)*(J-1)+1:J*size(xt,3),2)=xt(J,var2,:);
            end
            x_plot=x_plot(phase_IC:phase_IC+length(t)-1,:);
            figure;subplot(211);plot(t,x_plot(:,1));subplot(212);plot(x_plot(:,1),x_plot(:,2),OutL.xe(:,var1),OutL.xe(:,var2),'.','MarkerSize',15);drawnow
            str=join(['the time series did not converge in the given time to any solution (known or unknown), this is the simulation number',string(i1)]);
            warning(str)
            while (OutL.tipo(i1)~=1 && OutL.tipo(i1)~=2)
                inputvalue=input('Based on the displayed figure, please, type 1 if you think that the solution is converging to the desired equilibrium, otherwise type 2 ');
                if ~isempty(inputvalue)
                    OutL.tipo(i1)=inputvalue;
                    if (OutL.tipo(i1)~=1 && OutL.tipo(i1)~=2)
                        disp('Not valid entry, only "1" and "2" are valid entries')
                    end
                end
            end
            close;
        else
            OutL.tipo(i1)=2; % if automatic, select as diverged
        end
    end
    if plot_results>0.5
%         x_plot=xt(:,[var1,var2]);
        x_plot=zeros(size(xt,1)*size(xt,3),2);
        for J = 1:size(xt,1)
            x_plot(size(xt,3)*(J-1)+1:J*size(xt,3),1)=xt(J,var1,:);
            x_plot(size(xt,3)*(J-1)+1:J*size(xt,3),2)=xt(J,var2,:);         
        end
        x_plot=x_plot(phase_IC:phase_IC+length(t)-1,:);
    end 
    d_ind = size(xt,1)*size(xt,3)-length(t)-phase_IC+1; % for substracting the indeces of empty values later (number of empty points)   
    switch OutL.tipo(i1) % depending on the type of convergence, different action are performed
        case 1 % converging to equilibrium
            % save points in vc (vector of converging points) and update index of converging points
            [OutH.vc,ind_cp]=assaign_points_HEPO(OutL.tipo(i1),phase_IC,phase_out,Nt,xt,OutH.vc,ind_cp,dimv,d_ind);
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(x_plot(:,1),x_plot(:,2),'b.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end            
            if type_x0==1
                [v_inside,ind_v_inside]=points_inside_HEPO(v_inside,ind_v_inside,xt,OutL.xe,weight,Nt,phase_IC,phase_out,OutL.R(i1),divR,dim,OutL.tipo(i1)); %update th points inside the hypersphare
            end
            % add cells to the list of converging cells and update index of converging cells
            [cell_c,ind_cc]=assaign_cells_HEPO(cell_c,ind_cc,cell_f,phase_IC,phase_out,Nt,OutL.tipo(i1));       
            OutL.R(i1+1)=OutL.R(i1); % value of radius of convergence does not change
        case 2 % converging to an already known solution
            % save points in vd (vector of diverging points) and update index of diverging points
            [OutH.vd,ind_dp]=assaign_points_HEPO(OutL.tipo(i1),phase_IC,phase_out,Nt,xt,OutH.vd,ind_dp,dimv,d_ind);
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(x_plot(:,1),x_plot(:,2),'r.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end 
            % add cells to the list of diverging cells and update index of diverging cells
            [cell_d,ind_dc]=assaign_cells_HEPO(cell_d,ind_dc,cell_f,phase_IC,phase_out,Nt,OutL.tipo(i1));
            % calculate new radius of convergence, comparing the old one with the one for the new points      
            [OutL.R(i1+1),OutL.point_crit,ind_closest]=cal_R_HEPO(xt,OutL.xe,OutL.point_crit,dim,type_x0,OutL.R(i1),phase_IC,phase_out,weight,Nt);
            if type_x0==1
                % update the points inside of the hypersphere of convergence in
                % case of type_x0==1
                [v_inside,ind_v_inside]=points_inside_HEPO(v_inside,ind_v_inside,xt,OutL.xe,weight,Nt,phase_IC,phase_out,OutL.R(i1+1),divR,dim,OutL.tipo(i1));
            end
        case 3 % diverging out of the phase space 
            % save points in vd (vector of diverging points) and update index of diverging points
            [OutH.vdout,ind_doutp]=assaign_points_HEPO(OutL.tipo(i1),phase_IC,phase_out,Nt,xt,OutH.vdout,ind_doutp,dimv,d_ind);
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(x_plot(1:end-1,1),x_plot(1:end-1,2),'k.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end 
            % add cells to the list of diverging cells and update index of diverging cells
            [cell_dout,ind_doutc]=assaign_cells_HEPO(cell_dout,ind_doutc,cell_f,phase_IC,phase_out,Nt,OutL.tipo(i1)); 
            % calculate new radius of convergence, comparing the old one with the one for the new points      
            [OutL.R(i1+1),OutL.point_crit,ind_closest]=cal_R_HEPO(xt,OutL.xe,OutL.point_crit,dim,type_x0,OutL.R(i1),phase_IC,phase_out,weight,Nt);
            if type_x0==1
                % update the points inside of the hypersphere of convergence in
                % case of type_x0==1
                [v_inside,ind_v_inside]=points_inside_HEPO(v_inside,ind_v_inside,xt,OutL.xe,weight,Nt,phase_IC,phase_out,OutL.R(i1+1),divR,dim,OutL.tipo(i1));
            end
        case 4 % converging to a new unknown solution
            % save points in vd (vector of diverging points) and update index of diverging points
            [OutH.vd,ind_dp]=assaign_points_HEPO(OutL.tipo(i1),phase_IC,phase_out,Nt,xt,OutH.vd,ind_dp,dimv,d_ind);
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(x_plot(:,1),x_plot(:,2),'r.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end   
            % add cells to the list of diverging cells and update index of diverging cells
            [cell_d,ind_dc]=assaign_cells_HEPO(cell_d,ind_dc,cell_f,phase_IC,phase_out,Nt,OutL.tipo(i1)); 
            % calculate new radius of convergence, comparing the old one with the one for the new points      
            [OutL.R(i1+1),OutL.point_crit,ind_closest]=cal_R_HEPO(xt,OutL.xe,OutL.point_crit,dim,type_x0,OutL.R(i1),phase_IC,phase_out,weight,Nt);
            if type_x0==1
                % update the points inside of the hypersphere of convergence in
                % case of type_x0==1
                [v_inside,ind_v_inside]=points_inside_HEPO(v_inside,ind_v_inside,xt,OutL.xe,weight,Nt,phase_IC,phase_out,OutL.R(i1+1),divR,dim,OutL.tipo(i1));
            end
            counter_new_sol=counter_new_sol+1; % update counter of new solution
            OutL.other_solutions_p(counter_new_sol,:)={new_solution_p}; % add points of the solution to the collector of the solution
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutL.other_solutions_p{counter_new_sol}(:,var1),OutL.other_solutions_p{counter_new_sol}(:,var2),'g.','MarkerSize',30);hold on;drawnow % plot the new obtained solution
            end
    end
    
    if i1<number_of_steps % skip this passage for the last computation        
        if type_x0~=2
            [~,phase_IC]=min(ind_dp+ind_doutp+ind_cp);
            OutL.x0(i1+1,end) = OutL.xe(phase_IC,end);
        else
            if count_bis_phase>2*bis_iter_max % if the limit is reached for starting the solution at the same time section
                count_bis_phase=0; % set to zero the counter of bisection method at same time section
                there_was_div=0; % set to zero the marker of diverging trajectory
                there_was_conv=0; % set to zero the marker of converging trajectory
                count_bis=0; % set to zero the counter of bisection method
                ind_closest=0; % set zero the index of the closeset point for the time section (since new bisection method will start on an other time section)
                [~,phase_IC]=min(ind_dp+ind_doutp+ind_cp);
            else
                count_bis_phase=count_bis_phase+1;                   
            end
            OutL.x0(i1+1,end) = OutL.xe(phase_IC,end); 
        end
        if type_x0==1
            x0_tic=tic; % initialize counter of search for initial condition
            % look for the next initial condition as the most remote point
            % (approximate) within the convergence circle. It also provide the
            % distance from the new staring point and the closest point inside
            % the convergence circle
            [OutL.x0(i1+1,1:dim),OutL.distance(i1+1)]=find_furthest_point_approximate(OutL.xe(phase_IC,1:dim),OutL.R(i1+1),v_inside(1:ind_v_inside(phase_IC),1:dim,phase_IC),dim,weight,num_gen,num_crossover,selected_opt,newcomers,num_almost_clones);           
            OutL.time_x0(i1)=toc(x0_tic); % measure time for choosing new initial condition
            OutL.num_points_inside(i1,:)=ind_v_inside; % save the number of point inside the hypersphere of convergence at this step
        elseif type_x0==2
            % look for the following initial condition based on a bisection
            % scheme
            if OutL.tipo(i1)<2 % if the last trajectory was converging
                ind_closest=0; % no new closest point to xe
                if (count_bis<=bis_iter_max && there_was_div>0.5) % if the maximal number of bisection step is not reached AND there was already a diverging trajectory in the bisection procedure we continue the bisection
                    lastX0conv=OutL.x0(i1,1:dim); % set the initial condition as the closest converging point of the bisection
                    there_was_conv=1; % mark that there was a converging trajectory
                    OutL.x0(i1+1,1:dim)=(lastX0conv+lastX0div)/2; % define next initial point
                    count_bis=count_bis+1; % update counter of bisection
                else % if converging trajectory, but either maximal bisection steps number is passed OR there was no diverging trajectory we select a random initial condition and then restart the bisection
                    there_was_div=0; % set to zero the marker of diverging trajectory
                    there_was_conv=0; % set to zero the marker of converging trajectory
                    count_bis=0; % set to zero the counter of bisection method
                    if count_bis>bis_iter_max
                        count_bis_phase=0; % set to zero the counter of bisection method at same time section
                        [~,phase_IC]=min(ind_dp+ind_doutp+ind_cp);
                        OutL.x0(i1+1,end) = OutL.xe(phase_IC,end); 
                    end
                    OutL.x0(i1+1,1:dim)=randomIC_border(dim,OutL.R(i1+1)*1.1,OutL.xe(phase_IC,1:dim),weight); % find new initial condition randomly on the boundary of the hypersphere of convergence with a slightly larger radius                    
                end
            else % if the last trajectory is diverging
                if (ind_closest>1 || count_bis>bis_iter_max) % if the closest point to xe is not the first one OR we already had too many bisection steps we start a new bisection from the closest point
                    there_was_div=1; % mark that there was a diverging trajectory
                    there_was_conv=0; % mark that there wasn't a converging trajectory
                    count_bis=1; % restart counter for bisection method
                    lastX0div=xt(ind_closest,1:dim,phase_IC); % set the closest point as the closest diverging point of the bisection
                    OutL.x0(i1+1,1:dim)=(OutL.xe(phase_IC,1:dim)+lastX0div)/2; % find next initial condition
                elseif there_was_conv>0.5 % if we can continue a bisection already started (no larger than maximal step AND closest point is the first one) AND if there was already a converging trajectory
                    lastX0div=xt(ind_closest,1:dim,phase_IC); % set the initial condition as closest diverging point of the bisection
                    OutL.x0(i1+1,1:dim)=(lastX0conv+lastX0div)/2; % find next initial condition
                    there_was_div=1; % mark that there was a diverging trajectory
                    count_bis=count_bis+1; % update counter of bisection
                else % if there was no converging point in the bisection series, use equilibrium as closest converging point
                    if ind_closest==0
                            OutL.x0(i1+1,1:dim)=randomIC_border(dim,OutL.R(i1+1)*1.1,OutL.xe(phase_IC,1:dim),weight); % find new initial condition randomly on the boundary of the hypersphere of convergence with a slightly larger radius
                    else
                            lastX0div=xt(ind_closest,1:dim,phase_IC); % set the initial condition as closest diverging point of the bisection
                            OutL.x0(i1+1,1:dim)=(OutL.xe(phase_IC,1:dim)+lastX0div)/2; % find next initial condition
                            there_was_div=1; % mark that there was a diverging trajectory
                            count_bis=count_bis+1; % update counter of bisection
                    end                                 
                end
            end
            % check if the initial condition is inside the phase space
            out_bound=0;
            for i=1:dim
                if (OutL.x0(i1+1,i)<spaceboundary(i) || OutL.x0(i1+1,i)>spaceboundary(dim+i)) % check if the potential next initial point is withing the phase space
                    out_bound=1;
                end
            end
            if out_bound>0.5
                OutL.x0(i1+1,1:dim)=randomIC_border(dim,OutL.R(i1+1),OutL.xe(phase_IC,1:dim),weight); % if this is the case, select a new initial point, this time exactly on the hypersphere of convergence, to be sure it is not outside
            end
%             vcount_bis(i1)=count_bis; % save the counter of the bisection method for this step
        elseif type_x0==3
            % look for the next initial condition fully randomly within the
            % hypersphere of convergence
            OutL.x0(i1+1,1:dim)=randomIC_radius(dim,OutL.R(i1+1)*1.1,OutL.xe(phase_IC,1:dim),weight); % select the next initial condition within the hypersphere of convergence (with enlarged radius)
            % check if the initial condition is inside the phase space
            out_bound=0;
            for i=1:dim
                if (OutL.x0(i1+1,i)<spaceboundary(i) || OutL.x0(i1+1,i)>spaceboundary(dim+i)) % check if the potential next initial point is withing the phase space
                    out_bound=1;
                end
            end
            if out_bound>0.5
                OutL.x0(i1+1,1:dim)=randomIC_border(dim,OutL.R(i1+1),OutL.xe(phase_IC,1:dim),weight); % if this is the case, select a new initial point, this time exactly on the hypersphere of convergence, to be sure it is not outside
            end
        end
        if plot_results>0.5 % if chosen to plot at every step
            figure(num_fig);hold on;plot(OutL.x0(i1+1,var1),OutL.x0(i1+1,var2),'xk','LineWidth',2,'MarkerSize',10);drawnow % mark the new initial condition on the figure
        end
    end
    if plot_results>0.5 % if chosen to plot at every step
        figure(OutL.num_fig2);plot(OutL.R(1:i1),'-');xlabel('iteration');ylabel('LIM');xlim([1 number_of_steps]);ylim([0 inf]);drawnow; % plot the radius of convergence trend
    end
    OutL.time_steps(i1)=toc(step_tic); % measure the time for the step just concluded
end

vdout_out=zeros(sum(ind_doutp),dimv); % eliminate zeros from the vector of diverging outside points
vd_out=zeros(sum(ind_dp),dimv); % eliminate zeros from the vector of diverging points
vc_out=zeros(sum(ind_cp),dimv); % eliminate zeros from the vector of converging points
vdout_out(1:ind_doutp(1),:)=OutH.vdout(1:ind_doutp(1),:,1);
vd_out(1:ind_dp(1),:)=OutH.vd(1:ind_dp(1),:,1);
vc_out(1:ind_cp(1),:)=OutH.vc(1:ind_cp(1),:,1);
for J = 2:Nt
    vdout_out(sum(ind_doutp(1:J-1))+1:sum(ind_doutp(1:J)),:)=OutH.vdout(1:ind_doutp(J),:,J);
    vd_out(sum(ind_dp(1:J-1))+1:sum(ind_dp(1:J)),:)=OutH.vd(1:ind_dp(J),:,J);
    vc_out(sum(ind_cp(1:J-1))+1:sum(ind_cp(1:J)),:)=OutH.vc(1:ind_cp(J),:,J);
end
OutH.vdout=vdout_out;
OutH.vd=vd_out;
OutH.vc=vc_out;

if plot_results_final>0.5 % check if it is required to plot final figures or not
    figure;plot(OutL.R);hold on;xlabel('iteration');ylabel('LIM'); % plot the radius of convergence trend
%     figure;plot(time_steps);hold on;plot(time_sim);plot(time_x0);xlabel('iterations');ylabel('time utilized'); % plot the times taken for the iterations
end
R_final=OutL.R(end);
OutL.total_time=toc; % save total time

if OutL.flag_NaN~=1
    % plot the phase planes in var1-var2 and hypersphere of convergence
    final_plots_HEPO(xe0,OutL.xe,OutL.x0,OutH.vc,OutH.vd,OutH.vdout,OutL.other_solutions_p,OutL.point_crit,par,R_final,var1,var2,weight,plot_in_time,plot_results_final,tols)

    switch type_x0
        case 1
            disp(['Estimated LIM; initial condition selection as the farthest point in hypersphere of convergence'])
        case 2
            disp(['Estimated LIM; initial condition selection by bisection method'])
        case 3
            disp(['Estimated LIM; initial condition selection by random'])
    end
    R_final
end

