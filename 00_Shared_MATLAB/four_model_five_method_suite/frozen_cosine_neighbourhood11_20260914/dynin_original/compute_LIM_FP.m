function [R_final,OutL,OutH]=compute_LIM_FP(xe0,par,varargin)
% function [R_final,R,time_sim,time_x0,time_steps,time_steps_sim,total_time,distance,vc,vd,vdout,tipo,other_solutions_p,num_points_inside,x0,xe]=compute_LIM_FP(xe0,par,varargin)
% I am glad you are using my code. I will be happy to receive your
% feedback and help you if needed. If necessary, please contact me at
% habib@mm.bme.hu.
% If you use this software for your research, please cite my paper:
% Habib, G. (2021). Dynamical integrity assessment of stable equilibria: a 
% new rapid iterative procedure. Nonlinear Dynamics, 106(3), 2073-2096
%
% compute_LIM_FP(xe,par,varargin)
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
% max_check_step: maximal number of iterations for identifying the equilibrium solution
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
%
% Optional input for the two-level basin-boundary adaptive grid
% use_adaptive_grid: 1 enables the adaptive classification grid, 0 keeps
%    the original uniform-grid classification.
% dx_coarse, dv_coarse: coarse grid spacing in the displayed phase plane.
% refine_factor: fine-grid spacing is coarse spacing divided by this value.
% eta, target_type, target_point, orbit_points are retained only for
% backward compatibility with earlier adaptive-grid experiments. The
% current refinement trigger is coarse-neighbor label conflict, not LIM
% shell distance.
% use_adaptive_refinement: 1 enables boundary-conflict fine-grid creation.
% refine_every: perform boundary conflict detection every N iterations.
% max_refinement_level: currently supports 1 for two-level grids.
% inherit_parent_label_to_children: initialize new fine cells from parent
%    label when 1; default 0 creates unknown fine cells.


tic
p=inputParser;

dim=length(xe0); % dimension of the system (autonomous system)

% transpose array of initial conditions to raw if inserted as a column
if (length(xe0(:,1))>1 && length(xe0(1,:))==1)
    xe0=transpose(xe0);
elseif (length(xe0(:,1))>1 && length(xe0(1,:))>1)
    error('The initial condition vector must be either a row or a column vector, while it seems that a matrix was inserted')
end

% parameters for the simulation
DEFtfinal=1000; % maximal final time of each simulation
DEFTs=0.05; % sampling time for the simulation
DEFweight=ones(1,dim); % weight for computing the weighted distance in the phase space
DEFtype_x0=2; % method for choosing initial conditions. 1: farthest point, 2: bisection method, 3: random.
DEFreltol=1e-6; % relative tollerance
DEFabstol=1e-6; % absolute tollerance
DEFnumber_of_steps=50; % number of simulation performed (in the future, this might be changed with an automatic method for terminating the computation)
DEFnum_of_cell_around_equilibrium=3; % cells around the equilibrium to have faster convergence and avoid false new fixed points around it
DEFnum_fig=round(rand*10000); % number of the figure where the trajectories are plotted
DEFplot_results=1; % 1: plot results after each iteration, 0: do not plot them
DEFplot_results_final=0; % 1: plot final results, 0: only provide numerical output
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
DEFmax_check_step=10000; % maximal number of iterations for identifying the equilibrium solution

% coefficients for genetic algorithm for choosing new x0
DEFdivR=40; % the larger is this number, more points are kept inside the hypersphere of convergence as individual points
DEFnum_gen=5; % number of generations considered
DEFnum_crossover=9; % number of individual generated as crossover between to fit individuals
DEFselected_opt=3; % selected best individuals
DEFnewcomers=8; % new individuals with new random parameters
DEFnum_almost_clones=2; % number of almost clones of the best individual

% coefficient for initial condition choose through the bisection method
DEFbis_iter_max=5; % maximal number of steps of the bifsection method for x0
DEFuse_adaptive_grid=1; % 1: two-level basin-boundary adaptive grid, 0: original uniform grid
DEFdx_coarse=[];
DEFdv_coarse=[];
DEFrefine_factor=4;
DEFeta=max([DEFdx_coarse,DEFdv_coarse]); % retained for backward compatibility; not used for boundary refinement
DEFtarget_type='equilibrium'; % retained for backward compatibility
DEFtarget_point=[]; % retained for backward compatibility
DEForbit_points=[]; % retained for backward compatibility
DEFuse_adaptive_refinement=1;
DEFrefine_every=1;
DEFmax_refinement_level=1;
DEFinherit_parent_label_to_children=0;
DEFuse_LIM_oriented_refinement=1;
DEFeta_LIM=0.05;
DEFeta_bisect=0.05;
DEFmax_refine_cells_per_iter=5;
DEFuse_boundary_bisection=1;
DEFboundary_bisection_every=1;
DEFboundary_bisection_iter=6;
DEFboundary_bisection_max_pairs=3;
DEFadaptive_undefined_updates_LIM=0;
DEFsample_new_fine_cells_after_refinement=true;
DEFsample_only_fine_cells_near_LIM=true;
DEFeta_fine_sample=0.05;

% optional input organization
addParameter(p,'tfinal',DEFtfinal);
addParameter(p,'Ts',DEFTs);
addParameter(p,'weight',DEFweight);
addParameter(p,'type_x0',DEFtype_x0);
addParameter(p,'reltol',DEFreltol);
addParameter(p,'abstol',DEFabstol);
addParameter(p,'number_of_steps',DEFnumber_of_steps);
addParameter(p,'num_of_cell_around_equilibrium',DEFnum_of_cell_around_equilibrium);
addParameter(p,'num_fig',DEFnum_fig);
addParameter(p,'plot_results',DEFplot_results);
addParameter(p,'plot_results_final',DEFplot_results_final);
addParameter(p,'spaceboundary',DEFspaceboundary);
addParameter(p,'discr',DEFdiscr);
addParameter(p,'automatic',DEFautomatic);
addParameter(p,'var1',DEFvar1);
addParameter(p,'var2',DEFvar2);
addParameter(p,'rep_fix_point',DEFrep_fix_point);
addParameter(p,'rep_periodic',DEFrep_periodic);
addParameter(p,'min_periodic_radius',DEFmin_periodic_radius);
addParameter(p,'check_min_periodic',DEFcheck_min_periodic);
addParameter(p,'check_equilibrium',DEFcheck_equilibrium);
addParameter(p,'max_check_step',DEFmax_check_step);
addParameter(p,'divR',DEFdivR);
addParameter(p,'num_gen',DEFnum_gen);
addParameter(p,'num_crossover',DEFnum_crossover);
addParameter(p,'selected_opt',DEFselected_opt);
addParameter(p,'newcomers',DEFnewcomers);
addParameter(p,'num_almost_clones',DEFnum_almost_clones);
addParameter(p,'bis_iter_max',DEFbis_iter_max);
addParameter(p,'use_adaptive_grid',DEFuse_adaptive_grid);
addParameter(p,'dx_coarse',DEFdx_coarse);
addParameter(p,'dv_coarse',DEFdv_coarse);
addParameter(p,'refine_factor',DEFrefine_factor);
addParameter(p,'eta',DEFeta);
addParameter(p,'target_type',DEFtarget_type);
addParameter(p,'target_point',DEFtarget_point);
addParameter(p,'orbit_points',DEForbit_points);
addParameter(p,'use_adaptive_refinement',DEFuse_adaptive_refinement);
addParameter(p,'refine_every',DEFrefine_every);
addParameter(p,'max_refinement_level',DEFmax_refinement_level);
addParameter(p,'inherit_parent_label_to_children',DEFinherit_parent_label_to_children);
addParameter(p,'use_LIM_oriented_refinement',DEFuse_LIM_oriented_refinement);
addParameter(p,'eta_LIM',DEFeta_LIM);
addParameter(p,'eta_bisect',DEFeta_bisect);
addParameter(p,'max_refine_cells_per_iter',DEFmax_refine_cells_per_iter);
addParameter(p,'use_boundary_bisection',DEFuse_boundary_bisection);
addParameter(p,'boundary_bisection_every',DEFboundary_bisection_every);
addParameter(p,'boundary_bisection_iter',DEFboundary_bisection_iter);
addParameter(p,'boundary_bisection_max_pairs',DEFboundary_bisection_max_pairs);
addParameter(p,'adaptive_undefined_updates_LIM',DEFadaptive_undefined_updates_LIM);
addParameter(p,'sample_new_fine_cells_after_refinement',DEFsample_new_fine_cells_after_refinement);
addParameter(p,'sample_only_fine_cells_near_LIM',DEFsample_only_fine_cells_near_LIM);
addParameter(p,'eta_fine_sample',DEFeta_fine_sample);

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
max_check_step=p.Results.max_check_step;
divR=p.Results.divR;
num_gen=p.Results.num_gen;
num_crossover=p.Results.num_crossover;
selected_opt=p.Results.selected_opt;
newcomers=p.Results.newcomers;
num_almost_clones=p.Results.num_almost_clones;
bis_iter_max=p.Results.bis_iter_max;
use_adaptive_grid=p.Results.use_adaptive_grid;
dx_coarse=p.Results.dx_coarse;
dv_coarse=p.Results.dv_coarse;
refine_factor=p.Results.refine_factor;
eta=p.Results.eta;
target_type=p.Results.target_type;
target_point=p.Results.target_point;
orbit_points=p.Results.orbit_points;
use_adaptive_refinement=p.Results.use_adaptive_refinement;
refine_every=p.Results.refine_every;
max_refinement_level=p.Results.max_refinement_level;
inherit_parent_label_to_children=p.Results.inherit_parent_label_to_children;
use_LIM_oriented_refinement=p.Results.use_LIM_oriented_refinement;
eta_LIM=p.Results.eta_LIM;
eta_bisect=p.Results.eta_bisect;
max_refine_cells_per_iter=p.Results.max_refine_cells_per_iter;
use_boundary_bisection=p.Results.use_boundary_bisection;
boundary_bisection_every=p.Results.boundary_bisection_every;
boundary_bisection_iter=p.Results.boundary_bisection_iter;
boundary_bisection_max_pairs=p.Results.boundary_bisection_max_pairs;
adaptive_undefined_updates_LIM=p.Results.adaptive_undefined_updates_LIM;
do_sample_new_fine_cells_after_refinement=p.Results.sample_new_fine_cells_after_refinement;
sample_only_fine_cells_near_LIM=p.Results.sample_only_fine_cells_near_LIM;
eta_fine_sample=p.Results.eta_fine_sample;

if isempty(dx_coarse)
    dx_coarse=(spaceboundary(dim+var1)-spaceboundary(var1))/discr;
end
if isempty(dv_coarse)
    dv_coarse=(spaceboundary(dim+var2)-spaceboundary(var2))/discr;
end

tols=[reltol,abstol]; % set tollerances for simulation

% checking wether the user input is an equilibrium point, if not it finds it
if check_equilibrium==1 % if the option to check if the selected point is an equilibrium is set to ON
    OutL.xe=look_for_equilibrium(xe0,par,tols,Ts,max_check_step);
    if isnan(OutL.xe)
        % set all output to NaN to avoid errors
        R_final=NaN; OutL.R=NaN; OutL.time_sim=NaN; OutL.time_x0=NaN; OutL.time_steps=NaN; OutL.time_steps_sim=NaN; OutL.total_time=NaN;
        OutL.distance=NaN; OutH.vc=NaN; OutH.vd=NaN; OutH.vdout=NaN; OutL.tipo=NaN; OutL.other_solutions_p=NaN; OutL.num_points_inside=NaN;
        OutL.x0=NaN; OutL.xe=NaN;
        return % quit the function
    end
else
    OutL.xe=xe0; % set equilibrium to the inserted value
end


OutL.other_solutions_p={};

num_fig2=num_fig*2; % figure containint the trend of R
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

adaptive_grid=[];
adaptive_grid_debug_template = struct( ...
    'num_coarse_converging_cells',0, ...
    'num_coarse_nonconverging_cells',0, ...
    'num_coarse_unknown_cells',0, ...
    'num_coarse_known_unknown_cells',0, ...
    'num_coarse_boundary_candidates_before_LIM_filter',0, ...
    'num_coarse_boundary_candidates_after_LIM_filter',0, ...
    'num_refined_cells_this_iteration',0, ...
    'num_fine_cells_created_this_iteration',0, ...
    'number_of_new_fine_cells_sampled',0, ...
    'number_of_new_fine_cells_labelled_converging',0, ...
    'number_of_new_fine_cells_labelled_nonconverging',0, ...
    'number_of_new_fine_cells_labelled_unknown',0, ...
    'number_of_fine_cell_LIM_updates_from_sampling',0);
OutL.adaptive_grid_debug=repmat(adaptive_grid_debug_template,number_of_steps,1);
lim_update_debug_template = struct( ...
    'iteration',NaN, ...
    'source','', ...
    'old_R',NaN, ...
    'new_R',NaN, ...
    'initial_condition',NaN(1,dim), ...
    'closest_point',NaN(1,dim), ...
    'closest_distance',NaN, ...
    'classification',NaN, ...
    'stopped_by_cell',false, ...
    'inherited_label','', ...
    'early_stop_level','', ...
    'visited_first_cell','', ...
    'visited_last_cell','');
OutL.LIM_update_debug=repmat(lim_update_debug_template,number_of_steps,1);
OutL.last_LIM_update=lim_update_debug_template;
if use_adaptive_grid>0.5
    if dim<2
        error('The two-level adaptive grid requires at least two state variables for the phase plane.')
    end
    adaptive_grid=BoundaryAdaptiveGrid(spaceboundary(var1),spaceboundary(dim+var1),spaceboundary(var2),spaceboundary(dim+var2), ...
        dx_coarse,dv_coarse,refine_factor,refine_every,max_refinement_level,inherit_parent_label_to_children);
    adaptive_grid.initialize_equilibrium_cell(OutL.xe);
    adaptive_grid.set_coarse_cells_by_index(cell_c(1:ind_cc,1),'converging',discr);
end

option=odeset('RelTol', reltol, 'AbsTol', abstol); % tollerances for the simulations

% OutL.x0(1,:)=randomIC_fullspace(dim,spaceboundary); % first initial condition chosen with a random selection
OutL.x0(1,:)=randomIC_radius(dim,OutL.R(1),OutL.xe,weight); % first initial condition chosen with a random selection within the hypersphere of convergence

if plot_results>0.5 % if chosen to plot at every step
    figure(num_fig2);h2=plot(OutL.R,'-');xlabel('iteration');ylabel('LIM');xlim([1 number_of_steps]);ylim([0 inf]);drawnow; % prepare the plot of the radius of convergence trend
    set(h2,'YDataSource','OutL.R');
end

for i1=1:number_of_steps % cycle over the pre-defined number of steps
    step_tic=tic; % initiate step timer
    sim_tic=tic; % initiate simulation timer
    adaptive_unresolved = 0;
    R_before_main_trajectory = OutL.R(i1);
    % perform simulation, provides points, time interval of the point
    % series, cells touched, type of convergence, new solution in cells
    % (empty if the solution is not new), new solution in points (empty if
    % the solution is not new), number of points of the simulatio
    if use_adaptive_grid>0.5
        [xt,t,visited_keys,OutL.tipo(i1),new_solution_p,OutL.time_steps_sim(i1),early_stop_level]=simulation_DI_adaptive(dim,par,OutL.x0(i1,:),tfinal,Ts,tols,spaceboundary,adaptive_grid,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight);
        cell_f=[];
    else
        [d_min,ind_tmp]=findradius_bis(OutL.x0(i1,:),OutL.xe,weight);
        closest_point=OutL.x0(i1,:);
        [xt,t,cell_f,OutL.tipo(i1),new_solution_p,OutL.time_steps_sim(i1)]=simulation_DI(dim,par,OutL.x0(i1,:),tfinal,Ts,tols,spaceboundary,discr,cell_c(1:ind_cc,1), ...
            cell_d(1:ind_dc,1),cell_dout(1:ind_doutc,1),cell_pos,dh,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight);
        [cell_f,~]=unique(cell_f,'stable'); % eliminate repeated cells from the cells of the solution
    end
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
            if use_adaptive_grid>0.5 && adaptive_undefined_updates_LIM<0.5
                adaptive_unresolved = 1;
                OutL.tipo(i1)=1;
            else
                OutL.tipo(i1)=2; % if automatic, select as diverged
            end
        end
    end

    if use_adaptive_grid>0.5
        if adaptive_unresolved>0.5
            % Undefined adaptive trajectories are not reliable
            % nonconverging evidence. Do not label visited cells or update LIM.
            adaptive_grid.record_adaptive_unresolved();
        elseif OutL.tipo(i1)==1
            adaptive_grid.update_cells(visited_keys,'converging');
        elseif OutL.tipo(i1)>1
            adaptive_grid.update_cells(visited_keys,'nonconverging');
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
            if use_adaptive_grid<0.5
                cell_c(ind_cc+1:ind_cc+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of converging cells
                ind_cc=ind_cc+length(cell_f)-1; % update index of converging cells
            end
            OutL.R(i1+1)=OutL.R(i1); % value of radius of convergence does not change
        case 2 % converging to an already known solution
            OutH.vd(ind_dp+1:ind_dp+length(t),:)=xt; % save points in vd (vector of diverging points)
            if plot_results>0.5 % if chosen to plot at every step
                figure(num_fig);plot(OutH.vd(ind_dp+1:ind_dp+length(t),var1),OutH.vd(ind_dp+1:ind_dp+length(t),var2),'r.');hold on;drawnow % add the time series in the phase space (in 2D, by default x1 and x2)
            end
            ind_dp=ind_dp+length(t);  % update index of diverging points
            if use_adaptive_grid<0.5
                cell_d(ind_dc+1:ind_dc+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of diverging cells
                ind_dc=ind_dc+length(cell_f)-1; % update index of diverging cells
            end
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
            if use_adaptive_grid<0.5
                cell_dout(ind_doutc+1:ind_doutc+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of diverging outside cells
                ind_doutc=ind_doutc+length(cell_f)-1; % update index of diverging outside cells
            end
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
            if use_adaptive_grid<0.5
                cell_d(ind_dc+1:ind_dc+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of diverging cells
                ind_dc=ind_dc+length(cell_f)-1; % update index of diverging cells
            end
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

    if OutL.R(i1+1) < R_before_main_trajectory
        xe_for_debug = OutL.xe(:).';
        weight_for_debug = weight(:).';
        n_debug = min([size(xt,2),numel(xe_for_debug),numel(weight_for_debug)]);
        dist_debug = sqrt(sum((xt(:,1:n_debug)-xe_for_debug(1:n_debug)).^2 .* weight_for_debug(1:n_debug),2));
        [dmin_debug,idx_debug] = min(dist_debug);
        lim_debug = lim_update_debug_template;
        lim_debug.iteration = i1;
        lim_debug.source = 'original_GA_trajectory';
        lim_debug.old_R = R_before_main_trajectory;
        lim_debug.new_R = OutL.R(i1+1);
        lim_debug.initial_condition = OutL.x0(i1,:);
        lim_debug.closest_point = xt(idx_debug,:);
        lim_debug.closest_distance = dmin_debug;
        lim_debug.classification = OutL.tipo(i1);
        lim_debug.stopped_by_cell = use_adaptive_grid>0.5 && exist('early_stop_level','var') && ~isempty(early_stop_level);
        if OutL.tipo(i1)==1
            lim_debug.inherited_label = 'converging';
        elseif OutL.tipo(i1)>1
            lim_debug.inherited_label = 'nonconverging';
        end
        if use_adaptive_grid>0.5 && exist('early_stop_level','var')
            lim_debug.early_stop_level = early_stop_level;
        end
        if use_adaptive_grid>0.5 && exist('visited_keys','var') && ~isempty(visited_keys)
            lim_debug.visited_first_cell = visited_keys{1};
            lim_debug.visited_last_cell = visited_keys{end};
        end
        OutL.LIM_update_debug(i1,1) = lim_debug;
        OutL.last_LIM_update = lim_debug;
        fprintf('LIM update debug: iter=%d, source=%s, old=%.8f, new=%.8f, closest=[%.8f %.8f], d=%.8f, tipo=%d, stopped_by_cell=%d, inherited_label=%s\n', ...
            i1,lim_debug.source,lim_debug.old_R,lim_debug.new_R,lim_debug.closest_point(1),lim_debug.closest_point(2),lim_debug.closest_distance,lim_debug.classification,lim_debug.stopped_by_cell,lim_debug.inherited_label);
    end

    if use_adaptive_grid>0.5 && use_adaptive_refinement>0.5 && mod(i1,refine_every)==0
        current_R_for_refinement = OutL.R(i1+1);
        if ~isempty(orbit_points)
            adaptive_target_points = orbit_points;
        elseif ~isempty(target_point)
            adaptive_target_points = target_point;
        else
            adaptive_target_points = OutL.xe;
        end
        [refine_debug,new_fine_keys] = adaptive_grid.detect_and_refine_boundary_cells(current_R_for_refinement,adaptive_target_points,weight,eta_LIM,max_refine_cells_per_iter,use_LIM_oriented_refinement);
        if do_sample_new_fine_cells_after_refinement && ~isempty(new_fine_keys)
            R_before_sampling = OutL.R(i1+1);
            [R_after_sampling,fine_sample_stats] = sample_new_fine_cells_after_refinement(dim,par,new_fine_keys,R_before_sampling,adaptive_target_points,weight,tfinal,Ts,tols,spaceboundary,adaptive_grid,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,sample_only_fine_cells_near_LIM,eta_fine_sample);
            adaptive_grid.record_fine_sampling_stats(fine_sample_stats);
            OutL.R(i1+1) = min(OutL.R(i1+1),R_after_sampling);
            if R_after_sampling < R_before_sampling && isfield(fine_sample_stats,'last_update')
                lim_debug = lim_update_debug_template;
                lim_debug.iteration = i1;
                lim_debug.source = fine_sample_stats.last_update.source;
                lim_debug.old_R = R_before_sampling;
                lim_debug.new_R = R_after_sampling;
                if ~isempty(fine_sample_stats.last_update.initial_condition)
                    lim_debug.initial_condition = fine_sample_stats.last_update.initial_condition;
                end
                if ~isempty(fine_sample_stats.last_update.closest_point)
                    lim_debug.closest_point = fine_sample_stats.last_update.closest_point;
                end
                lim_debug.closest_distance = fine_sample_stats.last_update.closest_distance;
                lim_debug.classification = fine_sample_stats.last_update.classification;
                lim_debug.stopped_by_cell = fine_sample_stats.last_update.stopped_by_cell;
                lim_debug.inherited_label = fine_sample_stats.last_update.inherited_label;
                lim_debug.early_stop_level = fine_sample_stats.last_update.early_stop_level;
                lim_debug.visited_first_cell = fine_sample_stats.last_update.visited_first_cell;
                lim_debug.visited_last_cell = fine_sample_stats.last_update.visited_last_cell;
                OutL.LIM_update_debug(i1,1) = lim_debug;
                OutL.last_LIM_update = lim_debug;
                fprintf('LIM update debug: iter=%d, source=%s, old=%.8f, new=%.8f, closest=[%.8f %.8f], d=%.8f, tipo=%d, stopped_by_cell=%d, inherited_label=%s\n', ...
                    i1,lim_debug.source,lim_debug.old_R,lim_debug.new_R,lim_debug.closest_point(1),lim_debug.closest_point(2),lim_debug.closest_distance,lim_debug.classification,lim_debug.stopped_by_cell,lim_debug.inherited_label);
            end
            if type_x0==1 && OutL.R(i1+1) < R_before_sampling
                temp_outside=find(v_inside(1:ind_v_inside,dim+1)>OutL.R(i1+1)*1.1);
                v_inside(temp_outside,:)=[];
                ind_v_inside=ind_v_inside-length(temp_outside);
            end
            refine_debug.number_of_new_fine_cells_sampled = fine_sample_stats.number_of_new_fine_cells_sampled;
            refine_debug.number_of_new_fine_cells_labelled_converging = fine_sample_stats.number_of_new_fine_cells_labelled_converging;
            refine_debug.number_of_new_fine_cells_labelled_nonconverging = fine_sample_stats.number_of_new_fine_cells_labelled_nonconverging;
            refine_debug.number_of_new_fine_cells_labelled_unknown = fine_sample_stats.number_of_new_fine_cells_labelled_unknown;
            refine_debug.number_of_fine_cell_LIM_updates_from_sampling = fine_sample_stats.number_of_fine_cell_LIM_updates_from_sampling;
            fprintf('Fine-cell sampling: iter=%d, sampled=%d, conv=%d, nonconv=%d, unknown=%d, LIM_updates=%d, R_before=%.8f, R_after=%.8f\n', ...
                i1,fine_sample_stats.number_of_new_fine_cells_sampled,fine_sample_stats.number_of_new_fine_cells_labelled_converging, ...
                fine_sample_stats.number_of_new_fine_cells_labelled_nonconverging,fine_sample_stats.number_of_new_fine_cells_labelled_unknown, ...
                fine_sample_stats.number_of_fine_cell_LIM_updates_from_sampling,R_before_sampling,OutL.R(i1+1));
        end
        OutL.adaptive_grid_debug(i1,1) = refine_debug;
        fprintf('Adaptive debug iter=%d: coarse_conv=%d, coarse_nonconv=%d, candidates_before=%d, candidates_after=%d, refined_this_iter=%d, fine_created_this_iter=%d\n', ...
            i1,refine_debug.num_coarse_converging_cells,refine_debug.num_coarse_nonconverging_cells, ...
            refine_debug.num_coarse_boundary_candidates_before_LIM_filter,refine_debug.num_coarse_boundary_candidates_after_LIM_filter, ...
            refine_debug.num_refined_cells_this_iteration,refine_debug.num_fine_cells_created_this_iteration);
    end

    if use_adaptive_grid>0.5 && use_boundary_bisection>0.5 && mod(i1,boundary_bisection_every)==0
        current_R = OutL.R(i1+1);
        adaptive_stats_for_bisect = adaptive_grid.get_stats();
        if adaptive_stats_for_bisect.number_of_fine_cells_created == 0
            fprintf('No fine cells available for bisection.\n');
        else
        if ~isempty(orbit_points)
            bisection_target_points = orbit_points;
        elseif ~isempty(target_point)
            bisection_target_points = target_point;
        else
            bisection_target_points = OutL.xe;
        end
        [R_bis,bis_stats] = adaptive_boundary_bisection(dim,par,bisection_target_points,weight,tfinal,Ts,tols,spaceboundary,adaptive_grid,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,boundary_bisection_iter,boundary_bisection_max_pairs,current_R,automatic,eta_bisect,use_LIM_oriented_refinement);
        lim_updated_by_bisection = isfinite(R_bis) && R_bis < current_R;
        if lim_updated_by_bisection
            OutL.R(i1+1) = R_bis;
            if isfield(bis_stats,'last_update')
                lim_debug = lim_update_debug_template;
                lim_debug.iteration = i1;
                lim_debug.source = bis_stats.last_update.source;
                lim_debug.old_R = current_R;
                lim_debug.new_R = R_bis;
                if ~isempty(bis_stats.last_update.initial_condition)
                    lim_debug.initial_condition = bis_stats.last_update.initial_condition;
                end
                if ~isempty(bis_stats.last_update.closest_point)
                    lim_debug.closest_point = bis_stats.last_update.closest_point;
                end
                lim_debug.closest_distance = bis_stats.last_update.closest_distance;
                lim_debug.classification = bis_stats.last_update.classification;
                lim_debug.stopped_by_cell = bis_stats.last_update.stopped_by_cell;
                lim_debug.inherited_label = bis_stats.last_update.inherited_label;
                lim_debug.early_stop_level = bis_stats.last_update.early_stop_level;
                lim_debug.visited_first_cell = bis_stats.last_update.visited_first_cell;
                lim_debug.visited_last_cell = bis_stats.last_update.visited_last_cell;
                OutL.LIM_update_debug(i1,1) = lim_debug;
                OutL.last_LIM_update = lim_debug;
                fprintf('LIM update debug: iter=%d, source=%s, old=%.8f, new=%.8f, closest=[%.8f %.8f], d=%.8f, tipo=%d, stopped_by_cell=%d, inherited_label=%s\n', ...
                    i1,lim_debug.source,lim_debug.old_R,lim_debug.new_R,lim_debug.closest_point(1),lim_debug.closest_point(2),lim_debug.closest_distance,lim_debug.classification,lim_debug.stopped_by_cell,lim_debug.inherited_label);
                fprintf('Bisection update cells: first=%s, last=%s, early_stop_level=%s\n', ...
                    lim_debug.visited_first_cell,lim_debug.visited_last_cell,lim_debug.early_stop_level);
            end
            if type_x0==1
                temp_outside=find(v_inside(1:ind_v_inside,dim+1)>OutL.R(i1+1)*1.1);
                v_inside(temp_outside,:)=[];
                ind_v_inside=ind_v_inside-length(temp_outside);
            end
        end
        adaptive_grid.record_bisection_stats(bis_stats);
        fprintf('LIM-oriented bisection: iter=%d, pairs_total=%d, pairs_near_LIM=%d, tested=%d, nonconv=%d, best_R_bis=%.8f, current_R=%.8f, updated=%d\n', ...
            i1,bis_stats.number_of_bisection_pairs_total,bis_stats.number_of_bisection_pairs_near_LIM,bis_stats.number_of_bisection_pairs_tested,bis_stats.number_of_bisection_nonconv_found,bis_stats.best_R_bis,current_R,lim_updated_by_bisection);
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
                if (ind_closest>1 || count_bis>bis_iter_max) % if the closest point to xe is not the first one OR we already had too many bisection steps we start a new bisection from the closest point
                    there_was_div=1; % mark that there was a diverging trajectory
                    there_was_conv=0; % mark that there wasn't a converging trajectory
                    count_bis=1; % restart counter for bisection method
                    lastX0div=xt(ind_closest,:); % set the closest point as the closest diverging point of the bisection
                    OutL.x0(i1+1,:)=(OutL.xe+lastX0div)/2; % find next initial condition
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
if use_adaptive_grid>0.5
    adaptive_stats=adaptive_grid.get_stats();
    adaptive_stats.final_LIM=R_final;
    adaptive_stats.total_runtime=OutL.total_time;
    adaptive_stats.last_LIM_update=OutL.last_LIM_update;
    OutL.adaptive_grid_stats=adaptive_stats;
else
    OutL.adaptive_grid_stats=[];
end
