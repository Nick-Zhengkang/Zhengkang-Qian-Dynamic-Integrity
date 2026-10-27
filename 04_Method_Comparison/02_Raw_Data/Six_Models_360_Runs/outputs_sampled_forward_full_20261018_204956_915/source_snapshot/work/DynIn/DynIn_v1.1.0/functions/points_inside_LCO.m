function [v_inside,ind_v_inside]=points_inside_LCO(v_inside,ind_v_inside,xt,xe,weight,Nt,R,divR,dims,tipo)

if tipo>1
    % next couple of lines find and eliminate points from the list of
    % inside points, if they are out of the radius of convergence
    % (plus 10%)
    [~,Isort]=sort(v_inside(1:ind_v_inside,dims+1));
    v_inside(1:ind_v_inside,:)=v_inside(Isort,:);
    temp_outside = find(v_inside(1:ind_v_inside,dims+1)>R*1.1,1);
    if ~isempty(temp_outside)
        v_inside(temp_outside:ind_v_inside,:)=zeros(ind_v_inside+1-temp_outside,dims+1);
        ind_v_inside=temp_outside-1; % update the index of inside points accounting for the eliminated points
    end
end

XT=xt;
for J=1:Nt
    xt_dist=distance_from_xe(XT,xe(J,:),weight); % find weighted distance of each point of the time series from the equilibrium
    ind_xt_inside=find(xt_dist<R*1.1); % pick indeces of all the points within a weighted distance of R*1.1 form the equilibrium, needed later for find new initial condition (not exactly R, in order to keep points close to the coverging circle and improve choice of initial condition
    temp_conv=uniquetol([XT(ind_xt_inside,:),xt_dist(ind_xt_inside)],R/divR,'ByRows',true); % picking from points within the radius of convergence, eliminate points very close, within a tollerance of 1/divR of the actual radius of convergence
    v_inside(ind_v_inside+1:ind_v_inside+length(temp_conv(:,1)),:)=temp_conv; % add points to the vector of points within the radius of convergence
    ind_v_inside=ind_v_inside+length(temp_conv(:,1)); % update the index of the points inside the radius of convergence
    
    XT = XT(setdiff(1:1:size(XT,1),ind_xt_inside),:);% elliminate points already inside the radius of convergence
    if isempty(XT)
        % every point was inside the radius of convergence, there is 
        % no more points to examine
        break
    end
end


