function y = lininit(t,tau,xe,x0)
dim = length(xe);
y = nan(size(xe));
for i = 1 : dim
    y(i) = interp1([-tau,0],[xe(i),x0(i)],t);
end
end