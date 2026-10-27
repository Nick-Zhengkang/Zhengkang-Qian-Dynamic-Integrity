function xt_dist = distance_from_xe(xt,xe,weight)
% distance_from_xe(xt,xe,weight)
% weighted distance of a list of points xt from a given point xe
% weight is required to balance the distance in the various directions of
% the phase space

xt_dist = zeros(length(xt(:,1)),1);
for i = 1:length(xt(:,1))
    xt_dist(i) = normweight(xt(i,:)-xe,weight);
end