function checkoninput_D_HIC(dim,spaceboundary,xe,weight,var)
% checkoninput(dim,spaceboundary,xe,weight)
% dim: dimension of the system
% spaceboundary: boundaries of the phase space
% xe: equilibrium point
% weigth: weigth for computing weighted distance
% perform various control about the inserted parameters

% check on dimension
if dim>8
    warning('dimension of system exceed 8, convergence might be very slow');
end

% check on dimension real
if abs(imag(dim))>0
    error('dimension must be real (and integer)');
end

% check on dimension positive
if dim<1
    error('dimension must be greater than 0');
end

% check on dimension integer
if rem(dim,1)>0
    error('dimension must be an integer');
end

% check on correct length of spaceboundary
if length(spaceboundary)~=2*dim
    error('spaceboundary must include 2*dimension elements');
end

% check on positive spaceboundary
for i = 1:dim
    if spaceboundary(dim+i)-spaceboundary(i)<0
        error('one of the dimension of the working space is negative, check the vector "spaceboundary"');
    end
end

% check on correct length of weight
if length(weight)~=dim
    error('weight must include as many elements as the value of "dimension"');
end

% check on correct values of variables to be plotted
if var(1)>dim
    error('"var1" should be equal or less than "dimension"');
end
if var(2)>dim
    error('"var2" should be equal or less than "dimension"');
end

% check that spaceboundary is real
if max(abs(imag(spaceboundary)))>0
    error('spaceboundary must include only real values');
end

% check that xe is real
if max(abs(imag(xe)))>0
    error('xe must include only real values');
end