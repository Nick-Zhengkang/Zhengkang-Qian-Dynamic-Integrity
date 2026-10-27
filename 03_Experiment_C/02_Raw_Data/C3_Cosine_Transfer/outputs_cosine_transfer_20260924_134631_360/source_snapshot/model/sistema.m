function dz = sistema(~,z,par)
% Autonomous one-degree-of-freedom potential with quadratic drag.
switch char(par.model)
    case 'quadratic_cubic'
        restoring = z(1)-z(1)^2;
    case 'bistable_duffing'
        restoring = -z(1)+z(1)^3;
    case 'cosine_quadratic_drag'
        restoring = sin(z(1));
    otherwise
        error('Unknown model: %s',char(par.model));
end
dz = [z(2); -par.alpha*abs(z(2))*z(2)-restoring];
end
