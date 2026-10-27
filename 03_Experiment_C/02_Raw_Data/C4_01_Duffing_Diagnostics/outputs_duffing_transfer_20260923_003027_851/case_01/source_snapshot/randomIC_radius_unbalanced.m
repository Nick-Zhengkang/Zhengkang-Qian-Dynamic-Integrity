function x0=randomIC_radius_unbalanced(dim,R,xe,weight)
% randomIC_radius_unbalanced(dim,R,xe,weight)
%
% Chose a random point of an hypersphere. The hypersphere is
% weighted, in the sense that the distance from the border to the center (xe)
% is constant using certain weights provided in the vector "weight".
% dim: dimension of the phasespace
% R: radius of the hypersphere
% xe: center of the hypersphere
% weight: weight for computing the distance
% A generic direction is define. Each direction has the same probability
% to be chosen (if there are no mistakes).
% In order to define a generic direction with uniform probability, standard
% normalized distributed number are generated in each direction. This 
% generate a vetor with a uniformly distributed direction (proven at
% http://corysimon.github.io/articles/uniformdistn-on-sphere/, alternative
% method 1). Each direction is streched by sqrt(weight(i)) in order to
% compensate that it is actually an hyperellipsoid because of the weights.
% Then, the radious is 

% chose a random point into an hypersphere with weighted dimensions,
% radially the point is unbalancedtowards large radius values


pos = zeros(1,dim); % initialize the vector position

for i = 1:dim
    pos(i) = randn/sqrt(weight(i));
end

% Once a direction is defined, the vector is normalizing by its weighted
% length. Then a random number (between 0 and 1) is
% generated and multiplied by the radius. In order to avoid to have more
% points close to the center, the radius is scaled by the dimension as
% illustrated in the equation below. This increases the probability of having a
% point far from the center, compensating that close to the center surfaces
% with equal radius are smaller.
% The larger is a, the more points are concentrated around the periphery of the hypersphere
a = 5;
x0 = pos/normweight(pos,weight)*(random('beta',a,1)*R^dim)^(1/dim)+xe;