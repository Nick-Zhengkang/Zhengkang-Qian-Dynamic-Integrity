function distances=minimal_distances(v,vi,weight)
% minimal_distances(v,vi,weight)
%
% find the minimal distance of each point of a vector v from a vector of
% points vi. Distance is weighted according to the vector "weigth"

distances = zeros(length(v(:,1)),1); % vector containing minimal distance from vi of each center
for i1 = 1:length(v(:,1))
    distances(i1) = inf;
    for i2 = 1:length(vi(:,1))
        if normweight(v(i1,:)-vi(i2,:),weight)<distances(i1) % if new distance is smaller than previous value, then substitute it
            distances(i1) = normweight(v(i1,:)-vi(i2,:),weight); 
        end
    end
end
