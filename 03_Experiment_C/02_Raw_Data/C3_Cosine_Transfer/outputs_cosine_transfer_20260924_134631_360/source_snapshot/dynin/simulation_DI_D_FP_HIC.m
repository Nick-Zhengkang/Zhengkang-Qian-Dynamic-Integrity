% for each iteration step, here a simulation is computed at intervals Ts.
% Then, each simulation is classified depending on the type of convergence

function [xtdense,t,cell_f_matr,tipo,new_solution_c,new_solution_p,count]=simulation_DI_D_FP_HIC(dim,x0,tfinal,Ts,Ntau,r_sd,mapcell,spaceboundary,discr_f,cell_c_f,cell_d_f,cell_dout_f,cell_pos_f,dh_f,weight,rep_fix_point,rep_periodic,ind_check,ind_check_conv,init_type)
% tipo indicates which kind of convergence occurred.
% tipo=1 -> converged to desired solution
% tipo=2 -> converged to another known solution
% tipo=3 -> diverged out of the spaceboundary
% tipo=4 -> found new solution
dt = Ts/(r_sd+1/2);   % time step within the semi-discretization
tipo=0; % default value, needed if the system does not converge in the given time
new_solution_c=[]; % cells of a new solution if found, needed empty if the system does not converge in the given time
new_solution_p=[]; % points of a new solution if found, needed empty if the system does not converge in the given time
converged=0; % marker for convergence, if 1 the simulation stops
count=0; % counter for the number of steps
cell_f_matr = zeros(round(tfinal/Ts),Ntau); % initialize the matrix containing the used cells
xtdense=x0; % vector of points in the trajectory
% matrices and functions for the semi-discretization map
Phi = mapcell{1};
Ad = mapcell{2};
intexpA = mapcell{3};
fNLfunc = mapcell{4};

z=zeros(length(x0)*(r_sd+1),1);
while converged~=1 % stop if converged=1
    if count>tfinal/Ts % leave the loop if the final time is reached
        t=[0:Ts/Ntau:Ts*(count)]'; % create a time vector for the time series
        return % terminate the function (not only the loop) [THIS MIGHT CUASE PROBLEM, IT NEEDS TO BE TESTED BETTER]
    end
    count=count+1; % update counter for each step
    x = nan(Ntau,dim);
    for i_Ntau = 1 : Ntau       % semi-discretization map
        if count==1 && i_Ntau == 1 % first round
            for i_IC = 1:r_sd+1    % save the initial functions
                switch init_type
                    case 0  %constant IC
                        z((i_IC-1)*length(x0)+1:i_IC*length(x0),1) = x0;
                    case 1  % linear IC
                        z((i_IC-1)*length(x0)+1:i_IC*length(x0),1) = x0/(r_sd+0.5)*(-(i_IC-1)+r_sd+0.5);
                    case 2  % jump IC
                        if i_IC == 1
                            z((i_IC-1)*length(x0)+1:i_IC*length(x0),1) = x0;
                        else
                            z((i_IC-1)*length(x0)+1:i_IC*length(x0),1) = zeros(size(x0));
                        end
                    case 3  %free vibration IC
                        z((i_IC-1)*length(x0)+1:i_IC*length(x0),1) = freevib_init(-(i_IC-1)*dt,x0,weight);
                end
            end
        end
        for i_inter = 1 : round(r_sd/Ntau)
            z = Phi*z+[Ad*intexpA*fNLfunc(z(1:dim,1).',z(end-dim+1:end,1).');zeros(dim*r_sd,1)];
        end       
        x(i_Ntau,:) = z(1:length(x0),1).';
    end
    xtdense = [xtdense;x];  % update the vector of the trajectory
    temp_f=zeros(1,dim); % temporary variable used for finding the cell of the point (in coordinates)
    for ix = 1 : size(x,1)
        for i=1:dim
            if (x(ix,i)>spaceboundary(i) && x(ix,i)<spaceboundary(dim+i)) % check if the point is withing the phase space
                if isempty(find(cell_pos_f(:,i)>=x(ix,i)-dh_f(i)/2 & cell_pos_f(:,i)<=x(ix,i)+dh_f(i)/2,1))
                    warning('The point is inside the phase space, but it does not belong to any cell, probably it is on a boundary between two cells');
                end
                temp_f(i)=find(cell_pos_f(:,i)>=x(ix,i)-dh_f(i)/2 & cell_pos_f(:,i)<=x(ix,i)+dh_f(i)/2,1);
            else % if the point is outside the phase space, then tipo=3 (gone outside) and leave this for loop (no need to check the other dimensions)
                tipo=3;
                converged=1;
                break % leave only the single level for loop in which we are
            end
        end
        % find the index of a cell from the values in the grid reference frame
        cell_f_matr(count,ix)=find_index(temp_f,dim,discr_f);    
    end
        
    if converged < 0.5 % if the time series is not definite yet (only case 3 was possible so far)
        % check if the current cell correspond to any of the converging cells
        temp_c1 = strfind(cell_c_f(1:end-ind_check_conv(end)+1).',cell_f_matr(count,1));
        for icheck = 1 : length(temp_c1)
            if isequal(cell_c_f(temp_c1(icheck)+ind_check_conv-1).',cell_f_matr(count,ind_check_conv))
                tipo=1;
                converged=1;
            end
        end
        if converged<0.5            
            if ~isempty(cell_d_f) % if it does not correspond to a converged cell, it goes on checking for convergence to other solutions known or unknown
                temp_d1 = strfind(cell_d_f(1:end-ind_check(end)+1).',cell_f_matr(count,1));
                for icheck = 1 : length(temp_d1)
                    if isequal(cell_d_f(temp_d1(icheck)+ind_check-1).',cell_f_matr(count,ind_check))
                        tipo=2;
                        converged=1;
                    end
                end
            end
            if ~isempty(cell_dout_f) % otherwise, it goes on checking for matching with cells leading out of the phase space (dout, diverged outside)
                temp_dout1 = strfind(cell_dout_f(1:end-ind_check(end)+1).',cell_f_matr(count,1));
                for icheck = 1 : length(temp_dout1)
                    if isequal(cell_dout_f(temp_dout1(icheck)+ind_check-1).',cell_f_matr(count,ind_check))
                        tipo=3;
                        converged=1;
                    end
                end
            end
            %last considered case, is the case of a new solution, previously unknown
            if tipo==0 && count>max(rep_periodic,rep_fix_point) % checking only after N_per steps at least
                Fix_count = 0;
                for irepf = 1 : rep_fix_point
                    Fix_count = Fix_count+sum(abs(cell_f_matr(count+1-irepf,:)-cell_f_matr(count,end)));
                    if Fix_count>0
                        break;
                    end
                end
                if Fix_count == 0 % in the last few periods the solution remained the same -> new solution
                    converged=1;
                    tipo=4;
                    new_solution_c=cell_f_matr(count,end); % store the cell of the new fixed point
                    new_solution_p=xtdense(end,:); % store the point of the new fixed point
                elseif sum(abs(cell_f_matr(count,1:end-1)-cell_f_matr(count,1)))>0   % if the last subtrajectory is not constant
                    cell_f_matr_reshape = reshape(cell_f_matr(2:count-1,1:end-1).',[],1);                    
                    temp_rep1 = strfind(cell_f_matr_reshape(1:end-ind_check(end)+1).',cell_f_matr(count,1));    % find the the first point of the current substep in the previous part of the trajectory
                    irep = 0;   % initialize the repetition counter
                    for icheck = 1 : length(temp_rep1)
                        if isequal(cell_f_matr_reshape(temp_rep1(icheck)+ind_check-1).',cell_f_matr(count,ind_check))
                            irep = irep+1;
                            if irep==rep_periodic
                                tipo=4;
                                converged=1;
                                new_solution_c=cell_f_matr_reshape(temp_rep1(end):end);
                                new_solution_p=xtdense(temp_rep1(end):end,:);
                                break;
                            end
                        end
                    end                    
                end
            end
        end
    end
end

cell_f_matr = cell_f_matr(1:count,:); % store the nonzero/important cells
t=[0:Ts/Ntau:Ts*(count)]'; % create a time vector for the time series
end

