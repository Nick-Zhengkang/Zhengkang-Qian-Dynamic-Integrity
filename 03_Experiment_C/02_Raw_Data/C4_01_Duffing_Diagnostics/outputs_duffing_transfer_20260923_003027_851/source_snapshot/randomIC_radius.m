function x0=randomIC_radius(dim,R,xe,weight)
% randomIC_radius(dim,R,xe,weight)
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
x0 = pos/normweight(pos,weight)*(rand*R^dim)^(1/dim)+xe;


% % To verify the code, you can run the following script. First it is
% verified in dimension 2, then in dimension 3 taking a section of it. It
% is a graphical validation of the algorithm utilized, not a proof of any
% sort.
% xe=[0 0];
% R=1;
% weight=[1 1/20];
% dim=2;
% vect=zeros(100000,2);
% for i=1:length(vect(:,1))
%     vect(i,:)=randomIC_radius(dim,R,xe,weight);
% end
% figure;plot(vect(:,1),vect(:,2),'.');
% 
% % or
% 
% xe=[0 0 0];
% R=1;
% dim=3;
% weight=[1 1/20 1/50];
% vect=zeros(1000000,3);
% for i=1:length(vect(:,1))
%     vect(i,:)=randomIC_radius(dim,R,xe,weight);
% end
% temp=find(abs(vect(:,3))<0.01);
% vect12=vect(temp,:);
% figure;plot(vect12(:,1),vect12(:,2),'.');
