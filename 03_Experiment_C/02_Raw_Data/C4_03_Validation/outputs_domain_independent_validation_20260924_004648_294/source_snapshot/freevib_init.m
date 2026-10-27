function y = freevib_init(t,x0,weight)
%weight = [om1^2,om2^2,1,1];
%t (time) can be a scalar or a row vector

iDoF = length(weight)/2;
if iDoF ~= floor(iDoF)
    error('The free vibration initial condition can be used only for systems of even dimension');
end

% make them coloumn vectors
if size(x0,2)~=1
    x0 = x0.';
end
if size(weight,2)~=1
    weight = weight.';
end

omvec = (weight(1:iDoF).^0.5);
c = (x0(1:iDoF).^2+x0(iDoF+1:end).^2./weight(1:iDoF)).^0.5;

theta = zeros(iDoF,1);
for i = 1 : iDoF
    if c(i)~=0
        if x0(iDoF+i)<0
            theta(i,1) = acos(x0(i)/c(i));
        else
            theta(i,1) = -acos(x0(i)/c(i));
        end
    end    
end

y = [c.*cos(omvec*t+theta);
    -c.*omvec.*sin(omvec*t+theta)];
