function d=normweight(x0,weight)
% compute weighted distance between point x0 and the origin

temp=0;
for i=1:length(x0)
    temp=temp+x0(i)^2*weight(i);
end
d=sqrt(temp);
