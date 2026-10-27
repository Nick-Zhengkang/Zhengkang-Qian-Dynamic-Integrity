function [R,id] = findradius_id(vi,xe,weight)
% findradius(vi,xe,weight)
% find the minimal weighted distance of a list of points "vi" from the
% equilibrium "xe".
% In output provides the distance

distances = zeros(length(vi(:,1)),1);
for i = 1:length(vi(:,1))
    distances(i) = normweight(vi(i,:)-xe,weight);
end

[R,id] = min(distances);


        
        
        
        
        