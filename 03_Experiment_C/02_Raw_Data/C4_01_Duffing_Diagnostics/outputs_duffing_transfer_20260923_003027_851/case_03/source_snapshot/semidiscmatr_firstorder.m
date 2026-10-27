function  mapcell = semidiscmatr_firstorder(eq,dt,r,xveccell)

x = xveccell{1};
dx = xveccell{2};
xdel = xveccell{3};
s = sym('s');
dim = length(x);

xvec = [x;xdel];
dxsol = solve(eq,dx);
graddxsol_x = cellfun(@(z)gradient(z,x),struct2cell(dxsol),'UniformOutput',false);
graddxsol_xdel = cellfun(@(z)gradient(z,xdel),struct2cell(dxsol),'UniformOutput',false);

A = subs([graddxsol_x{:}].',xvec,zeros(size(xvec)));
A = double(A);
% coefficient matrix of the linear delayed state vector
R = subs([graddxsol_xdel{:}].',xvec,zeros(size(xvec)));
R = double(R);

% nonlinear part of the right-hand side
fNL = simplify(struct2cell(dxsol)-A*x-R*xdel);
fNLfunc = matlabFunction(simplify(fNL),'Vars',{x.',xdel.'});

%% matrices for the semidiscretization
Ad = expm(A*dt);
% If the condition number of matrix A is small enough, it is faster to
% calculate int(expm(-s*A),0,dt) utilizing matrix decomposition
if cond(A)<1e6 
    [P,J] = eig(A);
    intexpA = real(P*double(int(expm(-s*J),0,dt))/P);
else
    intexpA = double(int(expm(-s*A),0,dt));
end

Bd = Ad*intexpA*R;
Phi = sparse([Ad,zeros(dim,dim*(r-1)),Bd;
    eye(dim*r,dim*r),zeros(dim*r,dim)]);
mapcell = {Phi, Ad, intexpA, fNLfunc};
end