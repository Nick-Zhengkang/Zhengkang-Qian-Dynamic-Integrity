function x0=randomIC_fullspace(dim,spaceboundary)
% define a uniformly random point in the phace space limited by
% spaceboundary.
% dim: dimension of the system
% spaceboundary: boundaries of the phase space

x0=zeros(1,dim);
for i=1:dim
    x0(i)=rand*(spaceboundary(dim+i)-spaceboundary(i))+spaceboundary(i);
end