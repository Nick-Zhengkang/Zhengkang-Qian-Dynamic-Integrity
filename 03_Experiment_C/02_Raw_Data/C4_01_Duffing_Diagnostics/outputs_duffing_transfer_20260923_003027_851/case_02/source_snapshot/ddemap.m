function [x,z] = ddemap(xz,par,dim,init)
%par.k: multiplier for the extension of the phase space
%par.tau: time delay
%par.N: number of states within delay tau saved in the xt variable  
r = par.k*(par.N-1);
tvec_xt = 0:-par.tau/(par.N-1):-par.tau;
tvec_z = 0:-par.tau/r:-par.tau;
z_dim = (r+1)*dim/par.N;
dim_df = dim/par.N;

if size(xz,2)~=1
    xz = xz.';
end

% is it the first step of a trajectory or not
if init == 1
    z(1:dim_df,1) = xz(1:dim_df);
    z(dim_df+1:z_dim,1) = repmat(xz(dim_df+1:2*dim_df),r,1);
else
    z = xz;
end

% small time step inside for loop for accuracy (in the compute_LIM function
% larger time steps are enough)
for istep = 1 : par.k
    znew = semidiscmap(z,dim/par.N,par.mapcell,r);
    z = znew;
end

% the original state vector is returned as well
xinterp = interp1(tvec_z,reshape(z,dim/par.N,r+1).',tvec_xt);
x = reshape(xinterp.',dim,1).';


