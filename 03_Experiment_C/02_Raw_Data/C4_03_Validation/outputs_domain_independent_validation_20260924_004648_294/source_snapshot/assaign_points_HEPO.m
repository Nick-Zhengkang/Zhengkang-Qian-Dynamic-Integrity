function [v,ind]=assaign_points_HEPO(tipo,phase_IC,phase_out,Nt,xt,v,ind,dims,d_ind)

for J = 1:phase_IC-1
    if size(xt,1)>1
        v(ind(J)+1:ind(J)+size(xt,1)-1,1:dims,J)=xt(2:end,1:dims,J); % save points in v
        ind(J)=ind(J)+size(xt,1)-1; % update index of points
    end
end

for J = phase_IC:Nt
    v(ind(J)+1:ind(J)+size(xt,1),1:dims,J)=xt(:,1:dims,J); % save points in v
    ind(J)=ind(J)+size(xt,1); % update index of points
end

if tipo==3 % ellimante last, already out of phase point
    v(ind(end-(d_ind)),:,phase_out)=zeros(1,dims);
    ind(end-(d_ind):end) = ind(end-(d_ind):end)-1;
elseif d_ind > 0
    ind(end-(d_ind-1):end) = ind(end-(d_ind-1):end)-1; % substract zero-value points
end