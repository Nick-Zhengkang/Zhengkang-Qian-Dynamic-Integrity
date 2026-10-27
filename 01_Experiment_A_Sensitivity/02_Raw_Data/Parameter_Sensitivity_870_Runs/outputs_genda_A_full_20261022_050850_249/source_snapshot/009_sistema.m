function dz = sistema(~,z,par)
% Same quadratic-damping Duffing equation as the eight-variable BO study.
dz = [z(2); z(1)-z(1)^3-par.alpha*abs(z(2))*z(2)];
end
