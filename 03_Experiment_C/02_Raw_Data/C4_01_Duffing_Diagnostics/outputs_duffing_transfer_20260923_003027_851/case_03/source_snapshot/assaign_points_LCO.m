function [v,ind]=assaign_points_LCO(tipo,xt,v,ind)

if tipo~=3
    v(ind+1:ind+size(xt,1),:)=xt; % save points in v
    ind=ind+size(xt,1); % update index of points
else
    v(ind+1:ind+size(xt,1)-1,:)=xt(1:end-1,:); % save points in v (vector of points diverging out of phase)
    ind=ind+size(xt,1)-1; % update index of points diverging out of phase
end