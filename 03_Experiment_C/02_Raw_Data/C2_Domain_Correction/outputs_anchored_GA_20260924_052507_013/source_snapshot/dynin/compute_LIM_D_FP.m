function [R_final,OutL,OutH]=compute_LIM_D_FP(xe0,par,varargin)
% function [R_final,OutL,OutH]=compute_LIM_FP(xe0,par,varargin)
% I am glad you are using my code. I will be happy to receive your
% feedback and help you if needed. If necessary, please contact me at
% habib@mm.bme.hu.
% If you use this software for your research, please cite my paper:
% Habib, G. (2021). Dynamical integrity assessment of stable equilibria: a 
% new rapid iterative procedure. Nonlinear Dynamics, 106(3), 2073-2096
%
% compute_LIM_D_FP(xe,par,varargin)
%
% Compute the local integrity measure (LIM) of a fixed point.
%
% Compulsory input:
% xe0: coordinates of the equilibrium point or point surely within the basin
% of attraction of the desired equilibrium point
% par: parameters of the dynamical system
%
% OUTPUT:
% OutL: collect all output variables of small memory size
% OutL include:
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
% tipo: characterizaation of each trajectory (1: converging, 2: converged 
%    to a known solution, 3: diverged out of the spaceboundary, 4: converged
%    to a new steady state solution)
% other_solutions_p: new solution identified during the procedure
% num_points_inside: number of points inside the hypersphere of convergence
%    at each step
% x0: list of all the initial conditions utilized
% xe: equilibrium solution utilizied (either inserted by the user or
% computed by the algorithm)
%
% OutH: collect all output variables of large memory size
% OutH include:
% vc: vector of all points of converging trajectories
% vd: vector of all points of diverging trajectories
% vdout: vector of all points of trajectories diverging from the phase space
%
% Optional input (for default values open directly the code and see below):
% To insert any of them, use the following syntax:
% Ex.: compute_LIM_FP(xe0,par,'tfinal',1000)
% tfinal: maximal final time of each simulation
% Ts: sampling time for the simulation
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
% check_equilibrium: if 0 the equilibrium point is given by the user; if 1 the 
% equilibrium point is calculated by the program from the user input xe0
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

dim=length(xe0); % dimension of the system (autonomous system)

% parameters for the simulation
DEFtfinal=1000; % maximal final time of each simulation
DEFTs=0.05; % sampling time for the simulation
DEFweight=ones(1,dim); % weight for computing the weighted distance in the phase space
DEFtype_x0=2; % method for choosing initial conditions. 1: farthest point, 2: bisection method, 3: random.
DEFreltol=1e-8; % relative tollerance
DEFabstol=1e-8; % absolute tollerance
DEFnumber_of_steps=50; % number of simulation performed (in the future, this might be changed with an automatic method for terminating the computation)
DEFnum_of_cell_around_equilibrium=3; % cells around the equilibrium to have faster convergence and avoid false new fixed points around it
DEFnum_fig=round(rand*10000); % number of the figure where the trajectories are plotted
DEFplot_results=1; % 1: plot results after each iteration, 0: do not plot them
DEFplot_results_final=1; % 1: plot final results, 0: only provide numerical output
DEFspaceboundary=[xe0-10, xe0+10]; % boundaries of the phase space, example: spaceboundary=[x1min, x2min, x3min, x1max, x2max, x3max];
DEFdiscr=1001; % discretization number in each direction
DEFautomatic=0; % 0: in case of undefined time series it is asked to the user to decide about the convergence, 1: the algorithm proceed completely automatically imposing as diverging undefined time series
DEFvar1=1; % plotting variable 1 in the phase space
DEFvar2=2; % plotting variable 2 in the phase space
DEFrep_fix_point=40; % number of repetition in a cell before a new fixed point is defined
DEFrep_periodic=10; % number of repetition in a cell before a new periodic solution is defined
DEFmin_periodic_radius=0.005; % minimal distance between points of a periodic solution such that we can define it as periodic
DEFcheck_min_periodic=0; % perform a check on the minimal distance between points of a periodic solution. 0: no check, 1: check.
DEFcheck_equilibrium=1; % define wether the program should check the user input xe0

% coefficients for genetic algorithm for choosing new x0
DEFdivR=40; % the larger is this number, more points are kept inside the hypersphere of convergence as individual points
DEFnum_gen=5; % number of generations considered
DEFnum_crossover=9; % number of individual generated as crossover between to fit individuals
DEFselected_opt=3; % selected best individuals
DEFnewcomers=8; % new individuals with new random parameters
DEFnum_almost_clones=2; % number of almost clones of the best individual

% coefficient for initial condition choose through the bisection method
DEFbis_iter_max=5; % maximal number of steps of the bifsection method for x0

% optional input organization
addOptional(p,'tfinal',DEFtfinal);
addOptional(p,'Ts',DEFTs);
addOptional(p,'weight',DEFweight);
addOptional(p,'type_x0',DEFtype_x0);
addOptional(p,'reltol',DEFreltol);
addOptional(p,'abstol',DEFabstol);
addOptional(p,'number_of_steps',DEFnumber_of_steps);
addOptional(p,'num_of_cell_around_equilibrium',DEFnum_of_cell_around_equilibrium);
addOptional(p,'num_fig',DEFnum_fig);
addOptional(p,'plot_results',DEFplot_results);
addOptional(p,'plot_results_final',DEFplot_results_final);
addOptional(p,'spaceboundary',DEFspaceboundary);
addOptional(p,'discr',DEFdiscr);
addOptional(p,'automatic',DEFautomatic);
addOptional(p,'var1',DEFvar1);
addOptional(p,'var2',DEFvar2);
addOptional(p,'rep_fix_point',DEFrep_fix_point);
addOptional(p,'rep_periodic',DEFrep_periodic);
addOptional(p,'min_periodic_radius',DEFmin_periodic_radius);
addOptional(p,'check_min_periodic',DEFcheck_min_periodic);
addOptional(p,'check_equilibrium',DEFcheck_equilibrium);
addOptional(p,'divR',DEFdivR);
addOptional(p,'num_gen',DEFnum_gen);
addOptional(p,'num_crossover',DEFnum_crossover);
addOptional(p,'selected_opt',DEFselected_opt);
addOptional(p,'newcomers',DEFnewcomers);
addOptional(p,'num_almost_clones',DEFnum_almost_clones);
addOptional(p,'bis_iter_max',DEFbis_iter_max);

parse(p,varargin{:});
% assign values
tfinal=p.Results.tfinal;
Ts=p.Results.Ts;
weight=p.Results.weight;
type_x0=p.Results.type_x0;
reltol=p.Results.reltol;
abstol=p.Results.abstol;
number_of_steps=p.Results.number_of_steps;
num_of_cell_around_equilibrium=p.Results.num_of_cell_around_equilibrium;
num_fig=p.Results.num_fig;
plot_results=p.Results.plot_results;
plot_results_final=p.Results.plot_results_final;
spaceboundary=p.Results.spaceboundary;
discr=p.Results.discr;
automatic=p.Results.automatic;
var1=p.Results.var1;
var2=p.Results.var2;
rep_fix_point=p.Results.rep_fix_point;
rep_periodic=p.Results.rep_periodic;
min_periodic_radius=p.Results.min_periodic_radius;
check_min_periodic=p.Results.check_min_periodic;
check_equilibrium=p.Results.check_equilibrium;
divR=p.Results.divR;
num_gen=p.Results.num_gen;
num_crossover=p.Results.num_crossover;
selected_opt=p.Results.selected_opt;
newcomers=p.Results.newcomers;
num_almost_clones=p.Results.num_almost_clones;
bis_iter_max=p.Results.bis_iter_max;

tols=[reltol,abstol]; % set tollerances for simulation

dim_df = dim/par.N; % dimension of the delay-free system

% transpose array of initial conditions to raw if inserted as a column
if (length(xe0(:,1))>1 && length(xe0(1,:))==1)
    xe0=transpose(xe0);
elseif (length(xe0(:,1))>1 && length(xe0(1,:))>1)
    error('The initial condition vector must be either a row or a column vector, while it seems that a matrix was inserted')
end

% checking whether the user input is an equilibrium point, if not it finds it
x_in=xe0; 
max_check_step=1e5; % maximal number of time step to look for a solution
if check_equilibrium==1 % if the option to check if the selected point is an equilibrium is set to ON
    x_end=zeros(1,length(xe0)); % initialize for checking the convergence
    J=0; % initialize counter
    while max(abs(x_in-x_end))>abstol || J<1
        J=J+1; % increase counter
        if J>max_check_step % if counter exceed maximum number of steps and still not converging, then gives warning and close computation
            warning(['The solution did not converge to the equilibrium point in ', num2str(max_check_step), ' iteration steps. The error ' ...
                'between the last point and the previous one was ',num2str(norm(x_in-x_end)),'. Consider changing the initial guess for the equilibrium provided. ' ...
                'It is also possible that the system has no equilibrium solution for the given parameter set'])
            % set all output to NaN to avoid errors
            R_final=NaN; OutL.R=NaN; OutL.time_sim=NaN; OutL.time_x0=NaN; OutL.time_steps=NaN; OutL.time_steps_sim=NaN; OutL.total_time=NaN;
            OutL.distance=NaN; OutH.vc=NaN; OutH.vd=NaN; OutH.vdout=NaN; OutL.tipo=NaN; OutL.other_solutions_p=NaN; OutL.num_points_inside=NaN;
            OutL.x0=NaN; OutL.xe=NaN;
            return % quit the function
        end
        if J>1
            x_in=x_end;
        end
        %x=sys_solver(Ts,x_in,par,tols); % single simulation of length Ts (one time step)
        if J == 1
            init = 1;
            [x,zsemidisc] = ddemap(x_in.',par,dim,init);
            init = 0;
        else
            [x,zsemidisc] = ddemap(zsemidisc,par,dim,init);
        end
        x_end=x(end,:);
    end
    OutL.xe=x_end; % set equilibrium to the found value
else
    OutL.xe=xe0; % set equilibrium to the inserted value
end

if isnan(OutL.xe)
    warning(['The solution did not converge to the equilibrium point in ', num2str(max_check_step), ' iteration steps. The error ' ...
        'between the last point and the previous one was',num2str(norm(x_in-x_end)),'Consider changing the initial guess for the equilibrium provided.' ...
        'It is also possible that the system has no equilibrium solution for the given parameter set'])
    % set all output to NaN to avoid errors
    R_final=NaN; OutL.R=NaN; OutL.time_sim=NaN; OutL.time_x0=NaN; OutL.time_steps=NaN; OutL.time_steps_sim=NaN; OutL.total_time=NaN;
    OutL.distance=NaN; OutH.vc=NaN; OutH.vd=NaN; OutH.vdout=NaN; OutL.tipo=NaN; OutL.other_solutions_p=NaN; OutL.num_points_inside=NaN;
    OutL.x0=NaN; OutL.xe=NaN;
    return % quit the function
end


OutL.other_solutions_p={};

num_fig2=num_fig*2; % figure containing the trend of R
OutL.time_steps=zeros(number_of_steps,1); % for measuring the time required for each step
OutL.time_sim=zeros(number_of_steps,1); % for measuring the time required for each simulation
if type_x0==1
    OutL.time_x0=zeros(number_of_steps,1); % for measuring the time required for each search of initial consitions
else
    OutL.time_x0=NaN;
end
if type_x0==1
    OutL.distance=zeros(number_of_steps,1); % distance of each initial condition from other points
else
    OutL.distance=NaN;
end
OutL.num_points_inside=zeros(number_of_steps,1); % number of points inside the hypersphere of convergence at each step
OutL.time_steps_sim=zeros(number_of_steps,1); % number of time steps of each simulation
total_points_est=round(tfinal/Ts*number_of_steps/4); % maximal total number of points (if it is too large and it generate memory issues, it can be reduced)
OutL.x0=zeros(number_of_steps,dim); % vector containing all initial conditions utilized

% this is for checking that dimension, spaceboundary and xe are inserted "legally"
out_bound=checkoninput(dim,spaceboundary(1,:),OutL.xe,weight,[var1, var2]);
if out_bound>0.5
    warning('The equilibrium point is out of the examined phase space.')
    flag_NaN=1;
    % set all output to NaN to avoid errors
    R_final=NaN; OutL.R=NaN; OutL.time_sim=NaN; OutL.time_x0=NaN; OutL.time_steps=NaN; OutL.time_steps_sim=NaN; OutL.total_time=NaN;
    OutL.distance=NaN; OutH.vc=NaN; OutH.vd=NaN; OutH.vdout=NaN; OutL.tipo=NaN; OutL.other_solutions_p=NaN; OutL.num_points_inside=NaN;
    OutL.x0=NaN;
    return
end

if type_x0==2
    count_bis=0; % inizialized counter for bisection method for x0
    there_was_conv=0; % ausiliary variable for bisection method (check if there was a converging trajectory)
    there_was_div=0; % ausiliary variable for bisection method (check if there was a diverging trajectory)
end

% inizialise converging and diverging points and cells
OutH.vc=zeros(total_points_est,dim); % vector of converging points
OutH.vd=zeros(total_points_est,dim); % vector of diverging points
OutH.vdout=zeros(total_points_est,dim); % vector of diverging points out of space boundary
cell_c=zeros(total_points_est,1); % vector of converging cells
cell_d=zeros(total_points_est,1); % vector of diverging cells
cell_dout=zeros(total_points_est,1); % vector of diverging cells out of space boundary
ind_cp=0; % index of converging points
ind_dp=0; % index of diverging points
ind_doutp=0; % index of diverging points out of the phase space
if type_x0==1
    v_inside=zeros(total_points_est,dim+1); % vector of points inside the radius of convergence
    v_inside(1,:)=[OutL.xe,0]; % assign the equilibrium as point inside the radius of convergence
    ind_v_inside=1; % index of points inside radius of convergence
end
ind_cc=0; % index of converging cells
ind_dc=0; % index of diverging cells
ind_doutc=0; % index of diverging cells
counter_new_sol=0; % counter for new solutions
OutL.tipo=zeros(number_of_steps,1); % type of convergence of each simulation
OutL.R=zeros(number_of_steps+1,1)*NaN; % radius of convergence at each simulation step
minimum=1e9; % large value for finding the initial R
for i=1:dim % look for the minimal distance between xe and phase space boundary
    minimum=min([minimum,weight(i)^0.5*abs(OutL.xe(i)-spaceboundary(i)),weight(i)^0.5*abs(OutL.xe(i)-spaceboundary(dim+i))]);
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

% find cell of equilibrium
cell_e=zeros(dim,1); % inizialize cell of equilibrium
for i=1:dim % for each coordinate, look for the corresponding cell index
%     cell_e(i)=find(cell_pos(:,i)>OutL.xe(i)-dh(i)/2 & cell_pos(:,i)<OutL.xe(i)+dh(i)/2);
    [~,cell_e(i)]=min(abs(cell_pos(:,i)-OutL.xe(i)));
end

cell_c(ind_cc+1,1)=find_index(cell_e,dim,discr); % assign to the converging cells the cell containing xe (here ind_cc=0)
ind_cc=ind_cc+1; % update counter of converging cells
OutH.vc(ind_cp+1,:)=OutL.xe; % assign xe to the converging points
ind_cp=ind_cp+1; % update counter of converging points
cell_f_around_eq=find_cells_around_a_cell(dim,cell_e,discr,num_of_cell_around_equilibrium); % find cells around equilibrium cell which are then assigned as converging
cell_c(ind_cc+1:ind_cc+length(cell_f_around_eq),1)=cell_f_around_eq;
ind_cc=ind_cc+length(cell_f_around_eq); % update counter of converging cells

option=odeset('RelTol', reltol, 'AbsTol', abstol); % tollerances for the simulations

OutL.x0=randomIC_fullspace(dim,spaceboundary); % first initial condition chosen with a random selection
OutL.x0(1,dim_df+1:end) = OutL.xe(1,dim_df+1:end);

if plot_results>0.5 % if chosen to plot at every step
    figure(num_fig2);h2=plot(OutL.R,'-');xlabel('iteration');ylabel('LIM');xlim([1 number_of_steps]);ylim([0 inf]);drawnow; % prepare the plot of the radius of convergence trend
    set(h2,'YDataSource','OutL.R');
end

for i1=1:number_of_steps % cycle over the pre-defined number of steps
    step_tic=tic; % initiate step timer
    sim_tic=tic; % initiate simulation timer
    % perform simulation, provides points, time interval of the point
    % series, cells touched, type of convergence, new solution in cells
    % (empty if the solution is not new), new solution in points (empty if
    % the solution is not new), number of points of the simulatio
    [xt,t,cell_f,OutL.tipo(i1),new_solution_p,OutL.time_steps_sim(i1)]=simulation_DI_D_FP(dim,par,OutL.x0(i1,:),tfinal,Ts,tols,spaceboundary,discr,cell_c(1:ind_cc,1), ...
        cell_d(1:ind_dc,1),cell_dout(1:ind_doutc,1),cell_pos,dh,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight);
    [cell_f,~]=unique(cell_f,'stable'); % eliminate repeated cells from the cells of the solution
    OutL.time_sim(i1)=toc(sim_tic); % record time of the simulation
    if OutL.tipo(i1)==0 % in the case of not converged time series, it is asked to the user to choose if he thinks that the time series converges to the desired solution or not, based on a displaced phase space figure
        if automatic==0 % if the computation is not automatic (automatic==0), the user can deside if an undefined time series is converging or not
            figure;subplot(211);plot(t,xt(:,var1));subplot(212);plot(xt(:,var1),xt(:,var2),OutL.xe(var1),OutL.xe(var2),'.','MarkerSize',15);drawnow
            str=join(['the time series did not converge in the given time to any solution (known or unknown), this is the simulation number',string(i1),'. To avoid this message in the future, you can select the optional' ...
                'input variable <automatic> to 1. This would force the algorithm to consider similar trajectories as diverging by default.' ...
                'Othewise try to increase the optional input variable <tfinal> to a higher value. The current value is ',num2str(tfinal)]);
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
    
    switch OutL.tipo(i1) % depending on the type of convergence, different action are performed
        case 1 % converging to equilibrium
            OutH.vc(ind_cp+1:ind_cp+length(t),:)=xt; % save points in vc (vector of converging points)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vc(ind_cp+1:ind_cp+length(t),var1),OutH.vc(ind_cp+1:ind_cp+length(t),var2),'b.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end
            ind_cp=ind_cp+length(t); % update index of converging points
            if type_x0==1
                xt_dist=distance_from_xe(xt,OutL.xe,weight); % find weighted distance of each point of the time series from the equilibrium
                ind_xt_inside=find(xt_dist<OutL.R(i1)*1.1); % pick indeces of all the points within a weighted distance of R*1.1 form the equilibrium, needed later for find new initial condition (not exactly R, in order to keep points close to the coverging circle and improve choice of initial condition
                temp_conv=uniquetol([xt(ind_xt_inside,:),xt_dist(ind_xt_inside)],OutL.R(i1)/divR,'ByRows',true); % picking from points within the radius of convergence, eliminate points very close, within a tollerance of 1/divR of the actual radius of convergence
                v_inside(ind_v_inside+1:ind_v_inside+length(temp_conv(:,1)),:)=temp_conv; % add points to the vector of points within the radius of convergence
                ind_v_inside=ind_v_inside+length(temp_conv(:,1)); % update the index of the points inside the radius of convergence
            end
            cell_c(ind_cc+1:ind_cc+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of converging cells
            ind_cc=ind_cc+length(cell_f)-1; % update index of converging cells
            OutL.R(i1+1)=OutL.R(i1); % value of radius of convergence does not change
        case 2 % converging to an already known solution
            OutH.vd(ind_dp+1:ind_dp+length(t),:)=xt; % save points in vd (vector of diverging points)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vd(ind_dp+1:ind_dp+length(t),var1),OutH.vd(ind_dp+1:ind_dp+length(t),var2),'r.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end
            ind_dp=ind_dp+length(t);  % update index of diverging points
            cell_d(ind_dc+1:ind_dc+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of diverging cells
            ind_dc=ind_dc+length(cell_f)-1; % update index of diverging cells
            if type_x0==1
                OutL.R(i1+1)=min(OutL.R(i1),findradius(xt,OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
                % next two lines find and eliminate points from the list of
                % inside points, if they are out of the radius of convergence
                % (plus 10%)
                temp_outside=find(v_inside(1:ind_v_inside,dim+1)>OutL.R(i1+1)*1.1);
                v_inside(temp_outside,:)=[];
                ind_v_inside=ind_v_inside-length(temp_outside); % update the index of inside points accounting for the eliminated points
                xt_dist=distance_from_xe(xt,OutL.xe,weight); % find weighted distance of each point of the time series from the equilibrium
                ind_xt_inside=find(xt_dist<OutL.R(i1+1)*1.1); % pick points of the time series which are closer than R*1.1 from the equilibrium
                temp_conv=uniquetol([xt(ind_xt_inside,:),xt_dist(ind_xt_inside)],OutL.R(i1)/divR,'ByRows',true); % picking from points within the radius of convergence, eliminate points very close, within a tollerance of 1/divR of the actual radius of convergence
                v_inside(ind_v_inside+1:ind_v_inside+length(temp_conv(:,1)),:)=temp_conv; % add points to the vector of points within the radius of convergence
                ind_v_inside=ind_v_inside+length(temp_conv(:,1)); % update the index of the points inside the radius of convergence
            elseif type_x0==2
                [OutL.R(i1+1),ind_closest]=findradius_bis(xt,OutL.xe,weight); % calculate new radius of convergence and find the index corresponding to the closest point
                if OutL.R(i1+1)>OutL.R(i1) % check if the new radius of convergence is not larger than the previously estimated one
                    OutL.R(i1+1)=OutL.R(i1);
                end
            elseif type_x0==3
                OutL.R(i1+1)=min(OutL.R(i1),findradius(xt,OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
                if OutL.R(i1+1)>OutL.R(i1) % check if the new radius of convergence is not larger than the previously estimated one
                    OutL.R(i1+1)=OutL.R(i1);
                end
            end
        case 3 % diverging out of the phase space
            OutH.vdout(ind_doutp+1:ind_doutp+length(t)-1,:)=xt(1:end-1,:); % save points in vdout (vector of diverging points out of the phase space)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vdout(ind_doutp+1:ind_doutp+length(t)-1,var1),OutH.vdout(ind_doutp+1:ind_doutp+length(t)-1,var2),'k.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end
            ind_doutp=ind_doutp+length(t)-1;  % update index of diverging outside points
            cell_dout(ind_doutc+1:ind_doutc+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of diverging outside cells
            ind_doutc=ind_doutc+length(cell_f)-1; % update index of diverging outside cells
            if type_x0==1
                OutL.R(i1+1)=min(OutL.R(i1),findradius(xt,OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
                % next two lines find and eliminate points from the list of
                % inside points, if they are out of the radius of convergence
                % (plus 10%)
                temp_outside=find(v_inside(1:ind_v_inside,dim+1)>OutL.R(i1+1)*1.1);
                v_inside(temp_outside,:)=[];
                ind_v_inside=ind_v_inside-length(temp_outside); % update the index of inside points accounting for the eliminated points
                xt_dist=distance_from_xe(xt,OutL.xe,weight); % find weighted distance of each point of the time series from the equilibrium
                ind_xt_inside=find(xt_dist<OutL.R(i1+1)*1.1); % pick points of the time series which are closer than R*1.1 from the equilibrium
                temp_conv=uniquetol([xt(ind_xt_inside,:),xt_dist(ind_xt_inside)],OutL.R(i1)/divR,'ByRows',true); % picking from points within the radius of convergence, eliminate points very close, within a tollerance of 1/divR of the actual radius of convergence
                v_inside(ind_v_inside+1:ind_v_inside+length(temp_conv(:,1)),:)=temp_conv; % add points to the vector of points within the radius of convergence
                ind_v_inside=ind_v_inside+length(temp_conv(:,1)); % update the index of the points inside the radius of convergence
            elseif type_x0==2
                [OutL.R(i1+1),ind_closest]=findradius_bis(xt,OutL.xe,weight); % calculate new radius of convergence and find the index corresponding to the closest point
                if OutL.R(i1+1)>OutL.R(i1) % check if the new radius of convergence is not larger than the previously estimated one
                    OutL.R(i1+1)=OutL.R(i1);
                end
            elseif type_x0==3
                OutL.R(i1+1)=min(OutL.R(i1),findradius(xt,OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
                if OutL.R(i1+1)>OutL.R(i1) % check if the new radius of convergence is not larger than the previously estimated one
                    OutL.R(i1+1)=OutL.R(i1);
                end
            end
        case 4 % converging to a new unknown solution
            OutH.vd(ind_dp+1:ind_dp+length(t),:)=xt; % save points in vd (vector of diverging points)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vd(ind_dp+1:ind_dp+length(t),var1),OutH.vd(ind_dp+1:ind_dp+length(t),var2),'r.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end
            ind_dp=ind_dp+length(t);  % update index of diverging points
            cell_d(ind_dc+1:ind_dc+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of diverging cells
            ind_dc=ind_dc+length(cell_f)-1; % update index of diverging cells
            if type_x0==1
                OutL.R(i1+1)=min(OutL.R(i1),findradius(xt,OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
                % next two lines find and eliminate points from the list of
                % inside points, if they are out of the radius of convergence
                % (plus 10%)
                temp_outside=find(v_inside(1:ind_v_inside,dim+1)>OutL.R(i1+1)*1.1);
                v_inside(temp_outside,:)=[];
                ind_v_inside=ind_v_inside-length(temp_outside); % update the index of inside points accounting for the eliminated points
                xt_dist=distance_from_xe(xt,OutL.xe,weight); % find weighted distance of each point of the time series from the equilibrium
                ind_xt_inside=find(xt_dist<OutL.R(i1+1)*1.1); % pick points of the time series which are closer than R*1.1 from the equilibrium
                temp_conv=uniquetol([xt(ind_xt_inside,:),xt_dist(ind_xt_inside)],OutL.R(i1)/divR,'ByRows',true); % picking from points within the radius of convergence, eliminate points very close, within a tollerance of 1/divR of the actual radius of convergence
                v_inside(ind_v_inside+1:ind_v_inside+length(temp_conv(:,1)),:)=temp_conv; % add points to the vector of points within the radius of convergence
                ind_v_inside=ind_v_inside+length(temp_conv(:,1)); % update the index of the points inside the radius of convergence
            elseif type_x0==2
                [OutL.R(i1+1),ind_closest]=findradius_bis(xt,OutL.xe,weight); % calculate new radius of convergence and find the index corresponding to the closest point
                if OutL.R(i1+1)>OutL.R(i1) % check if the new radius of convergence is not larger than the previously estimated one
                    OutL.R(i1+1)=OutL.R(i1);
                end
            elseif type_x0==3
                OutL.R(i1+1)=min(OutL.R(i1),findradius(xt,OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
                if OutL.R(i1+1)>OutL.R(i1) % check if the new radius of convergence is not larger than the previously estimated one
                    OutL.R(i1+1)=OutL.R(i1);
                end
            end
            counter_new_sol=counter_new_sol+1; % update counter of new solution
%             other_solutions_c(counter_new_sol,:)={new_solution_c}; % add cells of the solution to the collector
            OutL.other_solutions_p(counter_new_sol,:)={new_solution_p}; % add points of the solution to the collector of the solution
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutL.other_solutions_p{counter_new_sol}(:,var1),OutL.other_solutions_p{counter_new_sol}(:,var2),'g.','MarkerSize',30);hold on;drawnow % plot the new obtained solution
            end
    end
    
    if i1<number_of_steps % skip this passage for the last computation
        if type_x0==1
            x0_tic=tic; % initialize counter of serach for initial condition
            % look for the next initial condition as the most remote point
            % (approximate) within the convergence circle. It also provide the
            % distance from the new staring point and the closest point inside
            % the convergence circle
            [OutL.x0(i1+1,:),OutL.distance(i1+1)]=find_furthest_point_approximate(OutL.xe,OutL.R(i1+1),v_inside(1:ind_v_inside,1:dim),dim,weight,num_gen,num_crossover,selected_opt,newcomers,num_almost_clones);
            OutL.time_x0(i1)=toc(x0_tic); % measure time for choosing new initial condition
            OutL.num_points_inside(i1)=ind_v_inside; % save the number of point inside the hypersphere of convergence at this step
        elseif type_x0==2
            % look for the following initial condition based on a bisection
            % scheme
            if OutL.tipo(i1)<2 % if the last trajectory was converging
                ind_closest=0; % no new closest point to xe
                if (count_bis<=bis_iter_max && there_was_div>0.5) % if the maximal number of bisection step is not reached AND there was already a diverging trajectory in the bisection procedure we continue the bisection
                    lastX0conv=OutL.x0(i1,:); % set the initial condition as the closest converging point of the bisection
                    there_was_conv=1; % mark that there was a converging trajectory
                    OutL.x0(i1+1,:)=(lastX0conv+lastX0div)/2; % define next initial point
                    count_bis=count_bis+1; % update counter of bisection
                else % if converging trajectory, but either maximal bisection steps number is passed OR there was no diverging trajectory we select a random initial condition and then restart the bisection
                    there_was_div=0; % set to zero the marker of diverging trajectory
                    there_was_conv=0; % set to zero the marker of converging trajectory
                    count_bis=0; % set to zero the counter of bisection method
                    OutL.x0(i1+1,:)=randomIC_border(dim,OutL.R(i1+1)*1.1,OutL.xe,weight); % find new initial condition randomly on the boundary of the hypersphere of convergence with a slightly larger radius
                    % check if the initial condition is inside the phase space
                end
            else % if the last trajectory is diverging
                if (ind_closest>1 || count_bis>bis_iter_max) % if the closest point to xe is not the first one OR we already had too many bisection steps we start a new bisection from the closest point with history at the origin (this might not be a diverging point because of the changed history)
                    there_was_div=0; % mark that there wasn't a diverging trajectory (it is not sure because of history)
                    there_was_conv=0; % mark that there wasn't a converging trajectory
                    count_bis=0; % restart counter for bisection method
                    OutL.x0(i1+1,:)=xt(ind_closest,:); % find next initial condition
                elseif there_was_conv>0.5 % if we can continue a bisection already started (no larger than maximal step AND closest point is not the first one) AND if there was already a converging trajectory
                    lastX0div=OutL.x0(i1,:); % set the initial condition as closest diverging point of the bisection
                    OutL.x0(i1+1,:)=(lastX0conv+lastX0div)/2; % find next initial condition
                    there_was_div=1; % mark that there was a diverging trajectory
                    count_bis=count_bis+1; % update counter of bisection
                else % if there was no converging point in the bisection series, use equilibrium as closest converging point
                    lastX0div=OutL.x0(i1,:); % set the initial condition as closest diverging point of the bisection
                    OutL.x0(i1+1,:)=(OutL.xe+lastX0div)/2; % find next initial condition
                    there_was_div=1; % mark that there was a diverging trajectory
                    count_bis=count_bis+1; % update counter of bisection
                end
            end
            out_bound=0;
            for i=1:dim
                if (OutL.x0(i1+1,i)<spaceboundary(i) || OutL.x0(i1+1,i)>spaceboundary(dim+i)) % check if the potential next initial point is withing the phase space
                    out_bound=1;
                end
            end
            if out_bound>0.5
                OutL.x0(i1+1,:)=randomIC_border(dim,OutL.R(i1+1),OutL.xe,weight); % if this is the case, select a new initial point, this time exactly on the hypersphere of convergence, to be sure it is not outside
            end
%             vcount_bis(i1)=count_bis; % save the counter of the bisection method for this step
        elseif type_x0==3
            % look for the next initial condition fully randomly within the
            % hypersphere of convergence
            OutL.x0(i1+1,:)=randomIC_radius(dim,OutL.R(i1+1)*1.1,OutL.xe,weight); % select the next initial condition within the hypersphere of convergence (with enlarged radius)
            % check if the initial condition is inside the phase space
            out_bound=0;
            for i=1:dim
                if (OutL.x0(i1+1,i)<spaceboundary(i) || OutL.x0(i1+1,i)>spaceboundary(dim+i)) % check if the potential next initial point is withing the phase space
                    out_bound=1;
                end
            end
            if out_bound>0.5
                OutL.x0(i1+1,:)=randomIC_border(dim,OutL.R(i1+1),OutL.xe,weight); % if this is the case, select a new initial point, this time exactly on the hypersphere of convergence, to be sure it is not outside
            end
        end
        if plot_results>0.5 % if chosen to plot at every step
            figure(num_fig);hold on;plot(OutL.x0(i1+1,var1),OutL.x0(i1+1,var2),'xk','LineWidth',2,'MarkerSize',10);drawnow % mark the new initial condition on the figure
        end
    end
    OutL.x0(i1+1,dim_df+1:end) = OutL.xe(1,dim_df+1:end);
    if plot_results>0.5 % if chosen to plot at every step
%         figure(num_fig2);plot(OutL.R(1:i1),'-');xlabel('iteration');ylabel('LIM');xlim([1 number_of_steps]);ylim([0 inf]);drawnow; % plot the radius of convergence trend
        refreshdata(h2,'caller'); % plot the radius of convergence trend
    end
    OutL.time_steps(i1)=toc(step_tic); % measure the time for the step just concluded
end
OutH.vdout=OutH.vdout(1:ind_doutp,:); % eliminate zeros from the vector of diverging outside points
OutH.vd=OutH.vd(1:ind_dp,:); % eliminate zeros from the vector of diverging points
OutH.vc=OutH.vc(1:ind_cp,:); % eliminate zeros from the vector of converging points
% v_inside=v_inside(1:ind_v_inside,:);  % eliminate zeros from the vector of inside circle of convergence points
if plot_results_final>0.5 % check if it is required to plot final figures or not
    figure;plot(OutL.R);hold on;xlabel('iteration');ylabel('LIM'); % plot the radius of convergence trend
%     figure;plot(OutL.time_steps);hold on;plot(OutL.time_sim);plot(OutL.time_x0);xlabel('iterations');ylabel('time utilized'); % plot the times taken for the iterations
end
R_final=OutL.R(end);
OutL.total_time=toc; % save total time



