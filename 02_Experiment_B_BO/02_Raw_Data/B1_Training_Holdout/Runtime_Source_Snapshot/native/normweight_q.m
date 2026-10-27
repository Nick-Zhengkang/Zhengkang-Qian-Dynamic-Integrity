function d=normweight_q(x0,weight)
% compute weighted distance squared between point x0 and the origin

d=0;
for i=1:length(x0)
    d=d+x0(i)^2*weight(i);
end
