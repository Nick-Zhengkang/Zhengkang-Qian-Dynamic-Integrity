function znew = semidiscmap(z,dim,mapcell,r)
% map the solution to the next time step with the semi-discretization technique
Phi = mapcell{1};
Ad = mapcell{2};
intexpA = mapcell{3};
fNLfunc = mapcell{4};

znew = Phi*z+[Ad*intexpA*fNLfunc(z(1:dim,1).',z(end-dim+1:end,1).');zeros(dim*r,1)];