function [ref,audit]=reference(name,alpha)
% REFERENCE Scoring only; evaluate Genda analytical equations, never an ODE.
switch char(name)
    case 'quadratic_cubic'
        [ref,audit]=reference_quadratic_cubic(alpha);
    case 'bistable_duffing'
        [ref,audit]=reference_bistable_duffing(alpha);
    otherwise
        error('limbench:Reference','No verified analytical reference for this model.');
end
end
