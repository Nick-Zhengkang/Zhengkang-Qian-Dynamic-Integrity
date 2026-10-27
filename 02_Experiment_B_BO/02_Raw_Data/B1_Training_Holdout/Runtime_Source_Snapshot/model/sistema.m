function dz=sistema(~,z,par)
if strcmp(par.model,'bistable_duffing')
    force=z(1)-z(1)^3;
elseif strcmp(par.model,'quadratic_cubic')
    force=-z(1)+z(1)^2;
else
    error('Unknown physical model.');
end
dz=[z(2);force-par.alpha*abs(z(2))*z(2)];
end
