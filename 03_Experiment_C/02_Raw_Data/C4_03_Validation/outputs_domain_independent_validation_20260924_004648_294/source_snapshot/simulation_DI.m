function [xt,t,cell_f,tipo,new_solution_p,count]=simulation_DI(dim,par,x0,tfinal,Ts,tols,spaceboundary,discr,cell_c,cell_d,cell_dout, ...
    cell_pos,dh,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight)
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
count=1; % counter for the number of steps (starts from 1 because of x0)
xt=zeros(round(tfinal/Ts),dim); % collect the position of the time series in the phase space
cell_f=zeros(round(tfinal/Ts),1); % initialize the vector containing the used cells
xt(1,:)=x0; % x0 is the first point of the time series

% find the cell corresponding to the initial point
temp_f=zeros(1,dim);
for i=1:dim
    temp_f(i)=find(cell_pos(:,i)>=xt(count,i)-dh(i)/2 & cell_pos(:,i)<=xt(count,i)+dh(i)/2,1);
end
% find the index of a cell from the values in the grid reference frame
cell_f(count)=find_index(temp_f,dim,discr);

while converged<0.5 % stop if converged=1
    if count>tfinal/Ts % leave the loop if the final time is reached
        t=[Ts:Ts:Ts*count]'; % create a time vector for the time series
        return % terminate the function (not only the loop) [THIS MIGHT CUASE PROBLEM, IT NEEDS TO BE TESTED BETTER]
    end
    count=count+1; % update counter for each step
    x=sys_solver(Ts,x0,par,tols); % single simulation of length Ts (one time section)
    x0=x(end,:); % last point of simulation will be initial condition of next one
    xt(count,:)=x0; % add the point to the lists of points
    temp_f=zeros(1,dim); % temporary variable used for finding the cell of the point (in coordinates)
    for i=1:dim
        if (xt(count,i)>spaceboundary(i) && xt(count,i)<spaceboundary(dim+i)) % check if the point is withing the phase space
            temp_f0=find(cell_pos(:,i)>=xt(count,i)-dh(i)/2 & cell_pos(:,i)<=xt(count,i)+dh(i)/2,1);
            if isempty(temp_f0)
                warning('The point is inside the phase space, but it does not belong to any cell, probably it is on a boundary between two cells');
            end
            temp_f(i)=temp_f0;
            % find the index of a cell from the values in the grid reference frame
            cell_f(count)=find_index(temp_f,dim,discr); % IMPORTANT, THIS IS THE CELL OF THE CURRENT STEP
        else % if the point is outside the phase space, then tipo=3 (gone outside) and leave this for loop (no need to check the other dimensions)
            tipo=3;
            converged=1;
            break % leave only the single level for loop in which we are
        end
    end
    if converged<0.5 % if the time series is not definite yet (only case 3 was possible so far)
        temp_c=find(cell_f(count)==cell_c, 1); % check if the current cell correspond to any of the converging cells
        if ~isempty(temp_c) % if it does correspond to a converging cell (temp_c not empty) then tipo=1 and converged
            tipo=1;
            converged=1;
        else
            if ~isempty(cell_d) % if it does not correspond to a converged cell, it goes on checking for convergence to other solutions known or unknown
                temp_d=find(cell_f(count)==cell_d, 1); % check if the current cell correspond to any of the cells converging to another solution (d stands for "diverged")
                if ~isempty(temp_d) % if it does correspond to a cell converging to another solution (temp_c not empty) then tipo=2 and diverged
                    tipo=2;
                    converged=1;
                end
            end
            if ~isempty(cell_dout) % otherwise, it goes on checking for matching with cells leading out of the phase space (dout, diverged outside)
                temp_dout=find(cell_f(count)==cell_dout, 1); % check if the current cell correspond to any of the cells diverging outside the phase space (dout, diverged outside)
                if ~isempty(temp_dout) % if it does correspond to a cell diverging outside(temp_dout not empty) then tipo=3 and diverged
                    tipo=3;
                    converged=1;
                end
            end
            if tipo==0 % last considered case, is the case of a new solution, previously unknown
                if count>3 % checking only after 3 steps at least
                    temp_selfconv=find(cell_f(count)==cell_f(1:count-1)); % checks for previous cells of the same time series corresponding to the current cell
                    if ~isempty(temp_selfconv) % if there are recurrent cells, then goes on checking, otherwise it stops this search and simulate another point
                        if nnz(~(diff(temp_selfconv)-1)) > rep_fix_point % if the cell was subsequently repeated more than "rep_fix_point" times then it is assumed that we have a new fixed point, tipo=4
                            converged=1;
                            tipo=4;
                            new_solution_p=xt(count,:); % store the point of the new fixed point
                        elseif (length(temp_selfconv)>rep_periodic+1 && temp_selfconv(end)~=count-1) % if the cell is repeated, less then "rep_fix_point" times but more than ...
                            % "rep_periodic" times then check for periodic (or potentially quasiperiodic) new solutions
                            count_rep=0;
                            for i=2:length(temp_selfconv)
                                if temp_selfconv(i)-temp_selfconv(i-1)~=1 % check if repetition of the cell are not subsequent
                                    count_rep=count_rep+1;
                                end
                            end
                            if count_rep>rep_periodic
                                if check_min_periodic==1
                                    temp_dist=maximal_distances(xt(count,:),xt(temp_selfconv(end)+1:count-1,:),weight);
                                    if temp_dist>min_periodic_radius
                                        converged=1;
                                        tipo=4;
                                        new_solution_p=xt(temp_selfconv(end):count-1,:);
                                    end
                                else
                                    converged=1;
                                    tipo=4;
                                    new_solution_p=xt(temp_selfconv(end):count-1,:);
                                end
                            end
                            %                         min_dist=10^9;
                            %                         for i=1:length(temp_selfconv) % measure the minimal distance between the present point and all other points that previously tracked the same cell
                            %                             min_dist=min(min_dist,normweight(xt(temp_selfconv(i),:)-xt(count,:),weight));
                            %                         end
                            %                         if 10*min_dist<normweight(xt(count,:)-xt(count-1,:),weight) % if the distance between the current point and the previous one is larger than 10 times the minimal distance, then we have a new periodic solution
                            %                             converged=1;
                            %                             tipo=4;
                            %                             new_solution_c=cell_f(temp_selfconv(end):count-1);
                            %                             new_solution_p=xt(temp_selfconv(end):count-1,:);
                            %                         end
                        end
                    end
                end
            end
        end
    end
end
xt=xt(1:count,:); % store the last point
cell_f=cell_f(1:count); % store the last cell
t=[Ts:Ts:Ts*count]'; % create a time vector for the time series
