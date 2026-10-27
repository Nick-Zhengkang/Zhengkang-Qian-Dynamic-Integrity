function [v_inside,ind_v_inside]=points_inside_HEPO(v_inside,ind_v_inside,xt,xe,weight,Nt,phase_IC,phase_out,R,divR,dims,tipo)


if size(xt,1)>1
    Jbegin=1;
    Jend=Nt;
else
    Jbegin=phase_IC;
    Jend=phase_out;
end

for J=Jbegin:Jend
    if J<phase_IC
        ibegin=2;
    else
        ibegin=1;
    end

    if J>phase_out
        iend=size(xt,1)-1;
    else
        iend=size(xt,1);
    end

    if tipo>1
        % next couple of lines find and eliminate points from the list of
        % inside points, if they are out of the radius of convergence
        % (plus 10%)
        [~,Isort]=sort(v_inside(1:ind_v_inside(J),dims+1,J));
        v_inside(1:ind_v_inside(J),:,J)=v_inside(Isort,:,J);
        temp_outside = find(v_inside(1:ind_v_inside(J),dims+1,J)>R*1.1,1);
        if ~isempty(temp_outside)
            v_inside(temp_outside:ind_v_inside(J),:,J)=zeros(ind_v_inside(J)+1-temp_outside,dims+1);
            ind_v_inside(J)=temp_outside-1; % update the index of inside points accounting for the eliminated points
        end
    end

    if ibegin<=iend
        xt_dist=distance_from_xe(xt(ibegin:iend,1:dims,J),xe(J,1:dims),weight); % find weighted distance of each point of the time series from the equilibrium
        ind_xt_inside=find(xt_dist<R*1.1); % pick indeces of all the points within a weighted distance of R*1.1 form the equilibrium, needed later for find new initial condition (not exactly R, in order to keep points close to the coverging circle and improve choice of initial condition
        temp_conv=uniquetol([xt(ind_xt_inside+ibegin-1,1:dims,J),xt_dist(ind_xt_inside)],R/divR,'ByRows',true); % picking from points within the radius of convergence, eliminate points very close, within a tollerance of 1/divR of the actual radius of convergence
        v_inside(ind_v_inside(J)+1:ind_v_inside(J)+length(temp_conv(:,1)),:,J)=temp_conv; % add points to the vector of points within the radius of convergence
        ind_v_inside(J)=ind_v_inside(J)+length(temp_conv(:,1)); % update the index of the points inside the radius of convergence
    end

end


