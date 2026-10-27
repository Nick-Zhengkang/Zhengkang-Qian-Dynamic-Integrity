function [R,ind]=findradius_bis(vi,xe,weight)
% findradius_bis(vi,xe,weight)
% find the minimal weighted distance of a list of points "vi" from the
% equilibrium "xe"
% In output provides the distance and the index of the closest point of the
% list of points "vi".

distances = zeros(length(vi(:,1)),1);
for i = 1:length(vi(:,1))
    distances(i) = normweight(vi(i,:)-xe,weight);
end

[R,ind] = min(distances);


        
        
        
        
        