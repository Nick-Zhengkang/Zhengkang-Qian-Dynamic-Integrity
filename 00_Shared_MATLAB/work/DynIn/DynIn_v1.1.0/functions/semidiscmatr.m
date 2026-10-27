function  [mapcell,x1_q,x2_q] = semidiscmatr(eq,dt,r,xveccell,varargin)

x = xveccell{1};
dx = xveccell{2};
ddx = xveccell{3};
xdel = xveccell{4};
dxdel = xveccell{5};

n = size(x,1);  %DoF of the system
dim = 2*n;      %dimension of the system

% parameter
DEFU = eye(n);
Dvar1 = 1;
Dvar2 = 2;
% optional input organization
p=inputParser;
addOptional(p,'U',DEFU);
addOptional(p,'var1',Dvar1);
addOptional(p,'var2',Dvar2);
parse(p,varargin{:});
% assign values
U=p.Results.U;
var1=p.Results.var1;
var2=p.Results.var2;

s = sym('s');

q =sym('q',[n,1]);
dq =sym('dq',[n,1]);
ddq =sym('ddq',[n,1]);
qdel = sym('qdel',[n,1]);
dqdel = sym('dqdel',[n,1]);
%% changing the coordinates to modal coordinates

x_q = solve(x == U*q);
if n>1
    x_q = structfun(@simplify,x_q);
end
dx_q = cellfun(@(x)subs(x,q,dq),sym2cell(x_q));
ddx_q = cellfun(@(x)subs(x,q,ddq),sym2cell(x_q));
xdel_q = cellfun(@(x)subs(x,q,qdel),sym2cell(x_q));
dxdel_q = cellfun(@(x)subs(x,q,dqdel),sym2cell(x_q));

% for the back transformation
if n == 1
    x1_q = matlabFunction(simplify(x_q(var1)));
    x2_q = [];
else
    x1_q = matlabFunction(simplify(x_q(var1)));
    x2_q = matlabFunction(simplify(x_q(var2)));
end
%% Equation of motion as a function of the modal coordinates
eq_q = subs(eq,[x;dx;ddx;xdel;dxdel],[x_q;dx_q;ddx_q;xdel_q;dxdel_q]);


if n==1    
    ddqsoltemp = solve(eq_q,ddq);
    ddqsol.ddq1 = ddqsoltemp;
else
    ddqsol = solve(eq_q,ddq);
end
gradddqsol_q = cellfun(@(x)gradient(x,q),struct2cell(ddqsol),'UniformOutput',false);
gradddqsol_dq = cellfun(@(x)gradient(x,dq),struct2cell(ddqsol),'UniformOutput',false);
gradddqsol_qdel = cellfun(@(x)gradient(x,qdel),struct2cell(ddqsol),'UniformOutput',false);
gradddqsol_dqdel = cellfun(@(x)gradient(x,dqdel),struct2cell(ddqsol),'UniformOutput',false);


qvec = [q;dq;qdel;dqdel];
% coefficient matrix of the linear non-delayed state vector
A = [zeros(dim/2),eye(dim/2);
    subs([gradddqsol_q{:}].',qvec,zeros(size(qvec))),subs([gradddqsol_dq{:}].',qvec,zeros(size(qvec)))];
A = double(A);
% coefficient matrix of the linear delayed state vector
R = [zeros(dim/2,dim);
    subs([gradddqsol_qdel{:}].',qvec,zeros(size(qvec))),subs([gradddqsol_dqdel{:}].',qvec,zeros(size(qvec)))];
R = double(R);

% nonlinear part of the right-hand side
fNL = simplify([dq;struct2cell(ddqsol)]-A*[q;dq]-R*[qdel;dqdel]);
fNLfunc = matlabFunction(simplify(fNL),'Vars',{[q.',dq.'],[qdel.',dqdel.']});
        
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