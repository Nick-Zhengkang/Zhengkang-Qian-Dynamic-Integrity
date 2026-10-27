function x0=randomIC_border(dim,R,xe,weight)
% Chose a random point on the border of an hypersphere. The hypersphere is
% weighted, in the sense that the distance from the border to the center (xe)
% is constant using certain weights provided in the vector "weight".
% dim: dimension of the phasespace
% R: radius of the hypersphere
% xe: center of the hypersphere
% weight: weight for computing the distance
% A generic direction is define and the point on the boundary in that
% direction is selected. Each point of the boundary has the same probability
% to be chosen (if there are no mistakes).
% In order to define a generic direction with uniform probability, standard
% normalized distributed number are generated in each direction. This 
% generate a vetor with a uniformly distributed direction (proven at
% http://corysimon.github.io/articles/uniformdistn-on-sphere/, alternative
% method 1). Each direction is streched by sqrt(weight(i)) in order to
% compensate that it is actually an hyperellipsoid because of the weights.

pos=zeros(1,dim); % initialize the position vector

for i=1:dim
    pos(i)=randn/sqrt(weight(i));
end

% once a direction is defined, by normalizing the pos vector by its weighted
% length we obtain the corresponding point on the border of the hypersphere
% (or better hyperellipsoid)
x0=pos/normweight(pos,weight)*R+xe;
