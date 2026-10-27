function [xt,t,cell_f,tipo,new_solution_p,count_sim,j]=simulation_DI_HEPO(dim,par,x0,tfinal,Ts,tols,spaceboundary,discr,cell_c,cell_d,cell_dout ...
    ,cell_pos,dh,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight,Nt,phase_IC)
% simulation(dim,par,x0,tfinal,Ts,option,spaceboundary,discr,cell_c,cell_d,cell_dout,cell_pos,dh,rep_fix_point,rep_periodic)
%
% For each iteration step, a simulation is computed at time intervals Ts.
% Then, each simulation is classified depending on the type of convergence
%
% tipo indicates which kind of convergence occurred.
% tipo=1 -> converged to desired solution
% tipo=2 -> converged to another known solution
% tipo=3 -> diverged out of the spaceboundary
% tipo=4 -> converged to a new steady state solution
% tipo from 2 to 4 are all diverging from the desired solution. Their
% differentiation is not strictly necessary for most of the funcitonality
% of the algorithm.
%
% dim: dimension of the phase space
% par: parameters of the system
% x0: initial condition of the simulation
% tfinal: maximal simulation time
% Ts: time discretization
% option: options for the simulation (tollerances)
% spaceboundary: boundaries of the phase space
% discr: number of cells in each direction of the phase space
% cell_c: vector of converging cells
% cell_d: vector of diverging cells
% cell_dout: vector of cells diverging out of the considered phase space
% cell_pos: vector including all the used coordinates in each direction
% dh: step sizes in each dimension
% rep_fix_point: number of repetition in a cell before a new fixed point is defined
% rep_periodic: number of repetition in a cell before a new periodic solution is defined

tipo=0; % default value, needed if the system does not converge in the given time
new_solution_p=[]; % points of a new solution if found, needed empty if the system does not converge in the given time
converged=0; % marker for convergence, if 1 the simulation stops
count=zeros(Nt,1); % counter for the number of steps (starts from 1 because of x0)
count(1:phase_IC) = ones(length(1:phase_IC),1);
xt=zeros(round(tfinal/Ts),size(x0,2),Nt); % collect the position of the time series in the phase space
cell_f=zeros(round(tfinal/Ts),Nt); % initialize the vector containing the used cells
xt(count(phase_IC),:,phase_IC)=x0; % x0 is the first point of the time series

% find the cell corresponding to the initial point
temp_f=zeros(1,dim);
for i=1:dim
    temp_f(i)=find(cell_pos(:,i)>=xt(count(phase_IC),i,phase_IC)-dh(i)/2 & cell_pos(:,i)<=xt(count(phase_IC),i,phase_IC)+dh(i)/2,1);
end
% find the index of a cell from the values in the grid reference frame
cell_f(count(phase_IC),phase_IC)=find_index(temp_f,dim,discr);
j = phase_IC; % indicates on which phase is the solution for periodic orbits
t0 = x0(end);

while converged<0.5 % stop if converged=1
    if sum(count)+1-phase_IC>tfinal/Ts % leave the loop if the final time is reached
        count_sim = sum(count)-phase_IC+1;
        xt=xt(1:max(count),:,:); % store the last point
        cell_f=cell_f(1:max(count),:); % store the last cell
        t=[t0:Ts:t0+Ts*(count_sim-1)]'; % create a time vector for the time series        
        return % terminate the function (not only the loop) [THIS MIGHT CUASE PROBLEM, IT NEEDS TO BE TESTED BETTER]
    end
    j = j+1;
    if j > Nt
        j = 1;
    end
    count(j)=count(j)+1; % update counter for each step
    T0=x0(end);
    %     [t,x]=ode45 (@(t,xt) feval(system_name,t,xt,par), [0 Ts], x0, option); % single simulation of length Ts (one time steps)
    [t,x]=sys_solver_HEPO(T0,T0+Ts,x0(1:dim),par,tols); % single simulation of length Ts (one time section)
    
    x0=[x(end,:),t(end)]; % last point of simulation will be initial condition of next one
    xt(count(j),:,j)=x0; % add the point to the lists of points
    
    temp_f=zeros(1,dim); % temporary variable used for finding the cell of the point (in coordinates)
    for i=1:dim
        if (xt(count(j),i,j)>spaceboundary(i) && xt(count(j),i,j)<spaceboundary(dim+i)) % check if the point is withing the phase space
            temp_f0=find(cell_pos(:,i)>=xt(count(j),i,j)-dh(i)/2 & cell_pos(:,i)<=xt(count(j),i,j)+dh(i)/2,1);
            if isempty(temp_f0)
                warning('The point is inside the phase space, but it does not belong to any cell, probably it is on a boundary between two cells');
            end
            temp_f(i)=temp_f0;
            % find the index of a cell from the values in the grid reference frame
            cell_f(count(j),j)=find_index(temp_f,dim,discr); % IMPORTANT, THIS IS THE CELL OF THE CURRENT STEP
        else % if the point is outside the phase space, then tipo=3 (gone outside) and leave this for loop (no need to check the other dimensions)
            cell_f(count(j),j)=-1; % marking that the last cell was out of the phase plane
            tipo=3;
            converged=1;
            break % leave only the single level for loop in which we are
        end
    end
    if converged<0.5 % if the time series is not definite yet (only case 3 was possible so far)
        temp_c=find(cell_f(count(j),j)==cell_c(:,j), 1); % check if the current cell correspond to any of the converging cells
        if ~isempty(temp_c) % if it does correspond to a converging cell (temp_c not empty) then tipo=1 and converged
            tipo=1;
            converged=1;
        else
            if ~isempty(cell_d(:,j)) % if it does not correspond to a converged cell, it goes on checking for convergence to other solutions known or unknown
                temp_d=find(cell_f(count(j),j)==cell_d(:,j), 1); % check if the current cell correspond to any of the cells converging to another solution (d stands for "diverged")
                if ~isempty(temp_d) % if it does correspond to a cell converging to another solution (temp_c not empty) then tipo=2 and diverged
                    tipo=2;
                    converged=1;
                end
            end
            if ~isempty(cell_dout(:,j)) % otherwise, it goes on checking for matching with cells leading out of the phase space (dout, diverged outside)
                temp_dout=find(cell_f(count(j),j)==cell_dout(:,j), 1); % check if the current cell correspond to any of the cells diverging outside the phase space (dout, diverged outside)
                if ~isempty(temp_dout) % if it does correspond to a cell diverging outside(temp_dout not empty) then tipo=3 and diverged
                    tipo=3;
                    converged=1;
                end
            end
            if tipo==0 % last considered case, is the case of a new solution, previously unknown
                if count(j)>3 % checking only after 3 steps at least
                    temp_selfconv=find(cell_f(count(j),j)==cell_f(1:count(j)-1,j)); % checks for previous cells of the same time series corresponding to the current cell
                    if ~isempty(temp_selfconv) % if there are recurrent cells, then goes on checking, otherwise it stops this search and simulate another point
                        if length(temp_selfconv)>rep_fix_point % if the cell was repeated more than "rep_fix_point" times then it is assumed that we have a new fixed point, tipo=4
                            converged=1;
                            tipo=4;
                            temp_selfconv_cells=1;
                            if j~=1
                                temp_selfconv_cells=temp_selfconv_cells+length(find(cell_f(count(j),j)==cell_f(count(j),1:j-1))); % checks for previous cells of previous phases corresponding to the current cell
                            end
                            if j~=Nt
                                temp_selfconv_cells=temp_selfconv_cells+length(find(cell_f(count(j),j)==cell_f(count(j)-1,j+1:end))); % checks for previous cells of subsequent phases corresponding to the current cell
                            end
                            if temp_selfconv_cells == Nt
                                new_solution_p=xt(count(j),:,j); % store the point of the new fixed point
                            else
                                if check_min_periodic==1
                                    new_solution_p=zeros(dim+1,Nt);
                                    new_solution_p(:,:)=xt(count(j)-1,:,:); % store the points of the new periodic orbit
                                    new_solution_p = new_solution_p';
                                    temp_dist=maximal_distances(xt(count(j),1:dim,j),new_solution_p(:,1:dim),weight);
                                    if temp_dist<=min_periodic_radius
%                                         new_solution_c=cell_f(count(j)-1,:)'; % store the cells of the new periodic orbit
%                                     else
                                        new_solution_p=[];
                                    end
                                else
                                    new_solution_p=zeros(dim+1,Nt);
                                    new_solution_p(:,:)=xt(count(j)-1,:,:); % store the points of the new periodic orbit
                                    new_solution_p = new_solution_p';
                                end
                            end
                        elseif (length(temp_selfconv)>rep_periodic+1 && temp_selfconv(end)~=count(j)-1) % if the cell is repeated, less then "rep_fix_point" times but more than ...
                            % "rep_periodic" times then check for periodic (or potentially quasiperiodic) new solutions
                            count_rep=0;
                            for i=2:length(temp_selfconv)
                                if temp_selfconv(i)-temp_selfconv(i-1)~=1 % check if repetition of the cell are not subsequent
                                    count_rep=count_rep+1;
                                end
                            end
                            if count_rep>rep_periodic
                                converged=1;
                                tipo=4;
                                if check_min_periodic==1
                                    new_solution_p=zeros(dim+1,Nt*(temp_selfconv(end)-temp_selfconv(end-1)));
                                    sol_index=0;
                                    temp_dist = 0;
                                    for J=temp_selfconv(end-1):temp_selfconv(end)-1
                                        sol_index=sol_index+1;
                                        new_solution_p(:,(sol_index-1)*Nt+1:Nt*(sol_index))=xt(J,:,:);
                                        temp_dist=max(temp_dist,maximal_distances(xt(count(j),1:dim,j),new_solution_p(1:dim,(sol_index-1)*Nt+1:Nt*(sol_index))',weight));
                                    end
                                    if temp_dist>min_periodic_radius
                                        new_solution_p=new_solution_p';
                                    else
                                        new_solution_p=[];
                                    end
                                else
                                    new_solution_p=zeros(dim+1,Nt*(temp_selfconv(end)-temp_selfconv(end-1)));
                                    sol_index=0;
                                    for J=temp_selfconv(end-1):temp_selfconv(end)-1
                                        sol_index=sol_index+1;
                                        new_solution_p(:,(sol_index-1)*Nt+1:Nt*(sol_index))=xt(J,:,:);
                                    end
                                    new_solution_p=new_solution_p';
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
count_sim = sum(count)-phase_IC+1;
xt=xt(1:max(count),:,:); % store the last point
cell_f=cell_f(1:max(count),:); % store the last cell
t=[t0:Ts:t0+Ts*(count_sim-1)]';% create a time vector for the time series
