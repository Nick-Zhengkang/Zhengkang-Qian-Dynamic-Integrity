function [xt,t,visited_keys,tipo,new_solution_p,count,early_stop_level]=simulation_DI_adaptive(dim,par,x0,tfinal,Ts,tols,spaceboundary,adaptive_grid,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight)
%SIMULATION_DI_ADAPTIVE Original simulation_DI logic with finest-cell lookup.
% The only adaptive behavior here is cell lookup: if a coarse cell has been
% refined, the fine child cell is used. Classification and stopping rules
% otherwise mirror the original simulation_DI implementation.

tipo=0;
new_solution_p=[];
converged=0;
count=1;
early_stop_level='';
xt=zeros(round(tfinal/Ts),dim);
cell_f=cell(round(tfinal/Ts),1);
visited_keys={};
xt(1,:)=x0;

[cell_info,cell_key]=adaptive_grid.get_cell_info(x0);
cell_f{count}=cell_key;
visited_keys{end+1}=cell_key;
[tipo,converged,early_stop_level]=adaptive_cell_stop(cell_info,cell_key,adaptive_grid);

while converged<0.5
    if count>tfinal/Ts
        t=[Ts:Ts:Ts*count]';
        return
    end
    count=count+1;
    x=sys_solver(Ts,x0,par,tols);
    x0=x(end,:);
    xt(count,:)=x0;

    out_of_bounds=0;
    for i=1:dim
        if (xt(count,i)>spaceboundary(i) && xt(count,i)<spaceboundary(dim+i))
            % inside phase space
        else
            tipo=3;
            converged=1;
            out_of_bounds=1;
            break
        end
    end

    if out_of_bounds<0.5
        [cell_info,cell_key]=adaptive_grid.get_cell_info(xt(count,:));
        cell_f{count}=cell_key;
        visited_keys{end+1}=cell_key;
        [tipo,converged,early_stop_level]=adaptive_cell_stop(cell_info,cell_key,adaptive_grid);
    end

    if converged<0.5
        if tipo==0
            if count>3
                temp_selfconv=find(strcmp(cell_f{count},cell_f(1:count-1)));
                if ~isempty(temp_selfconv)
                    if nnz(~(diff(temp_selfconv)-1)) > rep_fix_point
                        converged=1;
                        tipo=4;
                        new_solution_p=xt(count,:);
                    elseif (length(temp_selfconv)>rep_periodic+1 && temp_selfconv(end)~=count-1)
                        count_rep=0;
                        for i=2:length(temp_selfconv)
                            if temp_selfconv(i)-temp_selfconv(i-1)~=1
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
                    end
                end
            end
        end
    end
end
xt=xt(1:count,:);
visited_keys=visited_keys(1:min(count,length(visited_keys)));
t=[Ts:Ts:Ts*count]';
end

function [tipo,converged,early_stop_level]=adaptive_cell_stop(cell_info,cell_key,adaptive_grid)
tipo=0;
converged=0;
early_stop_level='';
if strcmp(cell_info.label,'converging')
    tipo=1;
    converged=1;
    adaptive_grid.record_early_stop(cell_key);
    early_stop_level=strtok(cell_key,':');
elseif strcmp(cell_info.label,'nonconverging')
    tipo=2;
    converged=1;
    adaptive_grid.record_early_stop(cell_key);
    early_stop_level=strtok(cell_key,':');
else
    % unknown cells do not stop integration.
end
end
