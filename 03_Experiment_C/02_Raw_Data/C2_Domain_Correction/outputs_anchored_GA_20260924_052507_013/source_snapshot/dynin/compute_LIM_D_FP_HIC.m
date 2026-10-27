function [R_final,OutL,OutH]=compute_LIM_D_FP_HIC(xe0,par,varargin)
% function [R_final,OutL,OutH]=compute_LIM_D_FP_HIC(xe0,par,mapcell,varargin)
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
% mapcell: cell structure that contains the matrices for the
% semi-discretization method
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
% Optional input for the bisection method for choosing initial conditions
% bis_iter_max: maximal number of consecutive steps of the bifsection 
%    method for selecting initial conditions


tic
p=inputParser;

dim=length(xe0); % dimension of the system (autonomous system)

% parameters for the simulation
DEFtfinal=100; % maximal final time of each simulation
DEFweight=ones(1,dim);
DEFreltol=1e-8; % relative tollerance
DEFabstol=1e-8; % absolute tollerance
DEFnumber_of_steps=20; % number of simulation performed (this must be changed to an automatic method for finishing)
DEFnum_of_cell_around_equilibrium=3; % cells around the equilibrium to have faster convergence and avoid faulse new fixed points around it
DEFnum_fig=round(rand*10000); % number of the figure containint points
DEFplot_results=1; % 1: plot results after each iteration, 0: plot only at the end for faster computation
DEFplot_results_final=1; % 1: plot final results, 0: only provide numerical output
DEFspaceboundary=[xe0-10, xe0+10]; % boundaries of the phase space, example: spaceboundary=[x1min, x2min, x3min, x1max, x2max, x3max];
DEFdiscr=1001; % discretization number in each direction
DEFautomatic=0; % 0: in case of undefined time series it is asked to the user to decide about the convergence, 1: the algorithm proceed completely automatically imposing as diverging undefined time series
DEFvar1=1; % plotting variable 1 in the phase space
DEFvar2=2; % plotting variable 2 in the phase space
DEFrep_fix_point=100; % number of repetition in a cell before a new fixed point is defined
DEFrep_periodic=30; % number of repetition in a cell before a new periodic solution is defined
DEFinit_type = 3; % type of initial condition. 0: constant;  1: linear; 2: jump ; 3: free vibration;
DEFNtau = 10; % number of time intervalls within a time delay loop
DEFind_check = [1,3,6,9];     % indeces which are checked in the comparision of the previous diverging/converging trajectories
DEFind_check_conv = [1,2,3,4,5,6,7,8,9];   %ind check close to the equilibrium
DEFbis_iter_max = 5; % number of steps with bisection method (for the initial cond)
DEFbisec_count_max = 3;    % the max number of bisec iterations after each other (to get random initial conditions as well)
DEFNrandom = 40;    % the maximum number of random initial conditions after each other. If it is reached a bisection method starts from the last initial condition
DEFcheck_equilibrium=1; % define wether the program should check the user input xe0

% optional input organization
addOptional(p,'tfinal',DEFtfinal);
addOptional(p,'weight',DEFweight);
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
addOptional(p,'init_type',DEFinit_type);
addOptional(p,'Ntau',DEFNtau);
addOptional(p,'check_equilibrium',DEFcheck_equilibrium);
addOptional(p,'ind_check',DEFind_check);
addOptional(p,'ind_check_conv',DEFind_check_conv);
addOptional(p,'bis_iter_max',DEFbis_iter_max);
addOptional(p,'bisec_count_max',DEFbisec_count_max);
addOptional(p,'Nrandom',DEFNrandom);

parse(p,varargin{:});
%% assign values
tfinal=p.Results.tfinal;
weight=p.Results.weight;
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
init_type=p.Results.init_type;
Ntau=p.Results.Ntau;
check_equilibrium=p.Results.check_equilibrium;
ind_check=p.Results.ind_check;
ind_check_conv=p.Results.ind_check_conv;
bis_iter_max=p.Results.bis_iter_max;
bisec_count_max=p.Results.bisec_count_max;
Nrandom = p.Results.Nrandom;

Ts=par.tau; % length of one short simulation equals to the time delay
num_of_timesteps = round(tfinal/Ts*Ntau*(number_of_steps+1));

% matrices and functions for the semi-discretization map
mapcell = par.mapcell;
Phi = mapcell{1};
Ad = mapcell{2};
intexpA = mapcell{3};
fNLfunc = mapcell{4};
 
OutL.time_steps=zeros(number_of_steps,1); % for measuring the time required for each step
OutL.time_sim=zeros(number_of_steps,1); % for measuring the time required for each simulation
OutL.time_x0=zeros(number_of_steps,1); % for measuring the time required for each search of initial consitions
OutL.distance=zeros(number_of_steps,1); % distance of each initial condition from other points
OutL.time_steps_sim=zeros(number_of_steps,1); % number of time steps of each simulation

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
            z = repmat(x_in',par.r+1,1);
            for i_inter = 1 : round(par.r/Ntau)
                z = Phi*z+[Ad*intexpA*fNLfunc(z(1:dim,1).',z(end-dim+1:end,1).');zeros(dim*par.r,1)];
            end       
            x(J,:) = z(1:length(xe0),1).';
        else
            for i_inter = 1 : round(par.r/Ntau)
                z = Phi*z+[Ad*intexpA*fNLfunc(z(1:dim,1).',z(end-dim+1:end,1).');zeros(dim*par.r,1)];
            end       
            x(J,:) = z(1:length(xe0),1).';
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
% if type_x0==1
%     OutL.time_x0=zeros(number_of_steps,1); % for measuring the time required for each search of initial consitions
% else
%     OutL.time_x0=NaN;
% end
% if type_x0==1
%     OutL.distance=zeros(number_of_steps,1); % distance of each initial condition from other points
% else
%     OutL.distance=NaN;
% end
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

%% inizialise converging and diverging points and cells
OutH.vc=zeros(total_points_est,dim); % vector of converging points
OutH.vd=zeros(total_points_est,dim); % vector of diverging points
OutH.vdout=zeros(total_points_est,dim); % vector of diverging points out of space boundary
cell_c=zeros(total_points_est,1); % vector of converging cells
cell_d=zeros(total_points_est,1); % vector of diverging cells
cell_dout=zeros(total_points_est,1); % vector of diverging cells out of space boundary
ind_cp=0; % index of converging points
ind_dp=0; % index of diverging points
ind_doutp=0; % index of diverging points out of the phase space
ind_dc=0; % index of diverging cells
ind_doutc=0; % index of diverging cells
counter_new_sol=0; % counter for new solutions
ibisec = 0;     % counter of bisection methon (initial cond)
irandom = 0;    % counter of random initial conditions 
bisec_count = 0; % counting the number of whole bisection iterations
randinit = 1;   % type of initial condition 1: random 0: bisection method, and based on the closest point. (it is continuously modified later during the bisec method)
found_div = 0;  % bisection method: whether a diverging trajectory is already found
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
    [~,cell_e(i)]=min(abs(cell_pos(:,i)-OutL.xe(i)));
end
%% updates initializing

cell_c(1:Ntau,1)=repmat(find_index(cell_e,dim,discr),Ntau,1); % assign to the converging cells the cell containing xe (here ind_cc=0)
ind_cc = Ntau;  % Ntau number of converging cells are already stored
OutH.vc(ind_cp+1,:)=OutL.xe; % assign xe to the converging points
ind_cp=ind_cp+1; % update counter of converging points
cell_f_around_eq=find_cells_around_a_cell(dim,cell_e,discr,num_of_cell_around_equilibrium); % find cells around equilibrium cell which are then assigned as converging
for i_eq = 1 : length(cell_f_around_eq) % asign to the converging cells the cells close to the equilibrium as well
    cell_c(ind_cc+1:ind_cc+Ntau+1,1) = [0;repmat(cell_f_around_eq(i_eq),Ntau,1)];
    ind_cc = ind_cc+Ntau+1;
end

OutL.x0(1,:)=randomIC_radius_unbalanced(dim,OutL.R(1),OutL.xe,weight);% first initial condition chosen with a random selection

% if plot_results>0.5 % if chosen to plot at every step
%     figure(num_fig2);h2=plot(OutL.R,'-');xlabel('iteration');ylabel('LIM');xlim([1 number_of_steps]);ylim([0 inf]);drawnow; % prepare the plot of the radius of convergence trend
%     set(h2,'YDataSource','OutL.R');
% end

%% cycle
for i1=1:number_of_steps % cycle over the pre-defined number of steps
    
    step_tic=tic; % initiate step timer
    sim_tic=tic; % initiate simulation timer
    % perform simulation, provides points, time interval of the point
    % series, cells touched, type of convergence, new solution in cells
    % (empty if the solution is not new), new solution in points (empty if
    % the solution is not new), number of points of the simulation
    [xt,t,cell_f_matr,OutL.tipo(i1),new_solution_c,new_solution_p,OutL.time_steps_sim(i1)]=simulation_DI_D_FP_HIC(dim,OutL.x0(i1,:),tfinal,Ts,Ntau,par.r,mapcell,spaceboundary,discr,cell_c(1:ind_cc,1),cell_d(1:ind_dc,1),cell_dout(1:ind_doutc,1),cell_pos,dh,weight,rep_fix_point,rep_periodic,ind_check,ind_check_conv,init_type);

    OutL.time_sim(i1)=toc(sim_tic); % record time of the simulation
    if OutL.tipo(i1)==0 % in the case of not converged time series, it is asked to the user to choose if he thinks that the time series converges to the desired solution or not, based on a displaced phase space figure
        if automatic == 0 % if the computation is not automatic (automatic==0), the user can deside if an undefined time series is converging or not
            figure;
            subplot(211);plot(t,xt(:,var1), t, xt(:,var2)); legend('q1','q2');
            subplot(212);plot(xt(:,var1),xt(:,var2),OutL.xe(var1),OutL.xe(var2),'.','MarkerSize',15);drawnow
            str=join(['The time series did not converge in the given time to any solution (known or unknown), this is the simulation number',string(i1)]);
            warning(str)
            while (OutL.tipo(i1)~=1 && OutL.tipo(i1)~=2)
                inputvalue = input('Based on the displayed figure, please, type 1 if you think that the solution is converging to the desired equilibrium, otherwise type 2 ');
                if ~isempty(inputvalue)
                    OutL.tipo(i1)= inputvalue;
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
            OutH.vc(ind_cp+1:ind_cp+length(t),:)=xt; % save points in vc (vector of points of converging trajectories)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vc(ind_cp+1:ind_cp+length(t),var1),OutH.vc(ind_cp+1:ind_cp+length(t),var2),'b.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end
            ind_cp=ind_cp+length(t); % update index of converging points

            cell_f_matr_reshape = reshape(cell_f_matr(2:end-1,1:end-1).',[],1);
            cell_c(ind_cc+1:ind_cc+length(cell_f_matr_reshape)+1,1) = [0;cell_f_matr_reshape]; % update the vector of converging cells - the zero element separates the different trajectories
            ind_cc=ind_cc+length(cell_f_matr_reshape)+1; % update index of converging cells
            
            OutL.R(i1+1)=OutL.R(i1); % value of radius of convergence does not change
        case 2 % converging to an already known undesired solution
            OutH.vd(ind_dp+1:ind_dp+length(t),:)=xt; % save points in vd (vector of points of diverging trajectories)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vd(ind_dp+1:ind_dp+length(t),var1),OutH.vd(ind_dp+1:ind_dp+length(t),var2),'r.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end
            ind_dp=ind_dp+length(t);  % update index of diverging points
            
            cell_f_matr_reshape = reshape(cell_f_matr(2:end-1,1:end-1).',[],1);
            cell_d(ind_dc+1:ind_dc+length(cell_f_matr_reshape)+1,1)=[0;cell_f_matr_reshape]; % update the vector of diverging cells - the zero element separates the different trajectories
            ind_dc=ind_dc+length(cell_f_matr_reshape)+1; % update index of diverging cells
            
            OutL.R(i1+1)=min(OutL.R(i1),findradius(OutL.x0(i1,:),OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
        case 3 % diverging out of the phase space
            OutH.vdout(ind_doutp+1:ind_doutp+length(t),:)=xt; % save points in vdout (vector of diverging points out of the phase space)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vdout(ind_doutp+1:ind_doutp+length(t)-1,var1),OutH.vdout(ind_doutp+1:ind_doutp+length(t)-1,var2),'k.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end
            ind_doutp=ind_doutp+length(t);  % update index of diverging outside points
            
            cell_f_matr_reshape = reshape(cell_f_matr(2:end-1,1:end-1).',[],1);
            cell_dout(ind_doutc+1:ind_doutc+length(cell_f_matr_reshape)+1,1) = [0;cell_f_matr_reshape]; % update the vector of diverging outside cells - the zero element separates the different trajectories
            ind_doutc=ind_doutc+length(cell_f_matr_reshape)+1;
            
            OutL.R(i1+1)=min(OutL.R(i1),findradius(OutL.x0(i1,:),OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
        case 4 % converging to a new unknown solution
            OutH.vd(ind_dp+1:ind_dp+length(t),:)=xt; % save points in vd (vector of diverging points)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vd(ind_dp+1:ind_dp+length(t),var1),OutH.vd(ind_dp+1:ind_dp+length(t),var2),'r.');hold on;drawnow % add the time series in the modal phase space (in 2D, by default q1 and q2)
            end
            ind_dp=ind_dp+length(t);  % update index of diverging points
            
            cell_f_matr_reshape = reshape(cell_f_matr(2:end-1,1:end-1).',[],1);
            cell_d(ind_dc+1:ind_dc+length(cell_f_matr_reshape)+1,1) = [0;cell_f_matr_reshape]; % update the vector of diverging cells - the zero element separates the different trajectories
            ind_dc=ind_dc+length(cell_f_matr_reshape)+1;
            
            OutL.R(i1+1)=min(OutL.R(i1),findradius(OutL.x0(i1,:),OutL.xe,weight)); % calculate new radius of convergence, comparing the old one with the one for the new points
            
            counter_new_sol=counter_new_sol+1; % update counter of new solution
            OutL.other_solutions_c(counter_new_sol,:)={new_solution_c}; % add cells of the solution to the collector
            OutL.other_solutions_p(counter_new_sol,:)={new_solution_p}; % add points of the solution to the collector of the solution
            if plot_results>0.5 % if chosen to plot at every step
                if size(new_solution_p,1)==1
                    figure(num_fig);plot(OutL.other_solutions_p{counter_new_sol}(:,var1),OutL.other_solutions_p{counter_new_sol}(:,var2),'g.','MarkerSize',30);hold on;drawnow % plot the new obtained solution
                else
                    figure(num_fig);plot(OutL.other_solutions_p{counter_new_sol}(:,var1),OutL.other_solutions_p{counter_new_sol}(:,var2),'k--','LineWidth',2);hold on;drawnow % plot the new obtained solution
                end
            end
    end
    
    if i1<number_of_steps % skip this passage for the last computation
        x0_tic=tic; % initialize counter of search for initial condition
        % look for the next initial condition as the most remote point
        % (approximate) within the convergence circle. It also provide the
        % distance from the new staring point and the closest point inside
        % the convergence circle
        if i1 == 1
            r_bisec = OutL.R(i1+1); % initializing of the closest distance
        end
        
        if OutL.tipo(i1) == 1 && randinit == 1 && irandom < Nrandom % random initial condition untill a diverging trajectory is found or until the maximum number of random initial conditions
            OutL.x0(i1+1,:)=randomIC_radius_unbalanced(dim,OutL.R(i1+1),OutL.xe,weight);
            irandom = irandom +1; % increase the counter of subsequent random initial conditions
        else  %bisection method
            randinit = 0;
            ibisec = ibisec+1;      % update the counter of iterations during the bisection method
            if OutL.tipo(i1)~=1  % divergind trajectory
                if findradius(xt,OutL.xe,weight) < r_bisec % store the closest point of the previous diverging trajectories
                    [r_bisec,id_bisec] = findradius_id(xt,OutL.xe,weight);
                    xclosest = xt(id_bisec,:);
                end
                found_div = 1;  % at least one diverging trajectory is found during the bisection method                   
            end
            
            if ibisec < bis_iter_max
                if found_div == 0   % until now in this round only stable trajectories were found -> the next initial condition should be farther away from the equilibrium
                    if findradius(OutL.x0,OutL.xe,weight) < OutL.R(i1+1)*0.8   % if the actual distance from the equilibrium is smaller than 80% of the current LIM the next init. cond. will be twice as far from the origin
                        bisecmin = OutL.x0(i1,:);
                        bisecmax = OutL.x0(i1,:)+OutL.x0(i1,:)-OutL.xe;
                    else % if the actual distance from the equilibrium is larger than 80% of the current LIM the next init. cond. will be 1.25 times farther 
                        bisecmin = OutL.x0(i1,:);
                        bisecmax = OutL.x0(i1,:)+(OutL.x0(i1,:)-OutL.xe)*0.25;
                    end
                        
                    for i=1:dim % if the maximum distance is outside the space boundary then it projected to the space boundary
                       if bisecmax(i)>spaceboundary(dim+i)
                           bisecmax = OutL.xe+(bisecmax-OutL.xe)*(spaceboundary(dim+i)-OutL.xe(i))/(bisecmax(i)-OutL.xe(i));
                       end
                       if bisecmax(i)<spaceboundary(i)
                           bisecmax = OutL.xe+(bisecmax-OutL.xe)*(spaceboundary(dim+i)-OutL.xe(i))/(bisecmax(i)-OutL.xe(i));
                       end                   
                    end
                    if max(max(OutL.x0==bisecmax)) %the chosen point was already checked -> the next initial condition is chosen randomly
                        randinit = 1;   % random initial condition will be used
                        OutL.x0(i1+1,:)=randomIC_radius_unbalanced(dim,OutL.R(i1+1),OutL.xe,weight);   % random initial condition
                        bisec_count = 0; % initialize for the next bisection iteration
                        ibisec = 0; % initialize for the next bisection iteration
                        irandom = 0; % initialize for the next bisection iteration                
                    else
                        OutL.x0(i1+1,:) =  bisecmax;     % new initial condition
                    end
                else            % if in this round at least 1 div is found
                    if ibisec == 1  % if the first one is a diverging trajectory
                        bisecmin = OutL.xe;  
                        bisecmax = OutL.x0(i1,:);
                    elseif OutL.tipo(i1) == 1    % in case of a converging trajectory the min limit is updated (increased)
                        bisecmin = OutL.x0(i1,:);
                    else
                        bisecmax = OutL.x0(i1,:); % in case of a diverging trajectory the max limit is updated (decreased)
                    end
                    OutL.x0(i1+1,:) =  (bisecmin+bisecmax)/2;    % new initial condition
                end
            elseif ibisec == bis_iter_max    % last step within the current bisection method
                if r_bisec<OutL.R(i1+1) && bisec_count < bisec_count_max  && ~max(max(OutL.x0==xclosest))   % if the number of whole bisection iterations is still smaller than the allowed number and a divering trajectory intersected the current hypersphere of convergence
                    OutL.x0(i1+1,:) = xclosest;      % the next initial point is that point of the diverging trajectories which was closest to the desired equilibrium
                    found_div = 0;  % initialize for the next bisection iteration
                    ibisec = 0;  % initialize for the next bisection iteration
                    bisec_count = bisec_count+1;    % update the counter of the whole bisection iterations
                else
                    randinit = 1;   % random initial condition will be used
                    OutL.x0(i1+1,:)=randomIC_radius_unbalanced(dim,OutL.R(i1+1),OutL.xe,weight);   % random initial condition
                    bisec_count = 0; % initialize for the next bisection iteration
                    ibisec = 0; % initialize for the next bisection iteration
                    found_div = 0; % initialize for the next bisection iteration
                    irandom = 0; % initialize for the next bisection iteration
                end
            end
        end
        OutL.time_x0(i1)=toc(x0_tic); % measure time for choosing new initial condition
        if plot_results>0.5 % if chosen to plot at every step
            figure(num_fig);hold on;plot(OutL.x0(i1+1,var1),OutL.x0(i1+1,var2),'xk','LineWidth',2,'MarkerSize',10);drawnow % mark the new initial condition on the figure
        end
    end
    OutL.time_steps(i1)=toc(step_tic); % measure the time for the step just concluded
end
OutH.vdout=OutH.vdout(1:ind_doutp,:); % eliminate zeros from the vector of diverging outside points
OutH.vd=OutH.vd(1:ind_dp,:); % eliminate zeros from the vector of diverging points
OutH.vc=OutH.vc(1:ind_cp,:); % eliminate zeros from the vector of converging points
if plot_results_final>0.5 % check if it is required to plot final figures or not
    figure;plot(OutL.R);xlabel('iteration');ylabel('LIM'); % plot the radius of convergence trend
%    figure;plot(time_steps);hold on;plot(time_sim);plot(time_x0);xlabel('iterations');ylabel('time utilized'); % plot the times taken for the iterations
end
R_final=OutL.R(end);
OutL.total_time=toc; % save total time
