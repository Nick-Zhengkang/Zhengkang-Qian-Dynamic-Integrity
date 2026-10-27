function [label,nRhs,tEnd,traj]=classify(x0,m,c)
% CLASSIFY Same physical classifier and path recording for EVERY method.
% 1 = target basin, 2 = non-target, 0 = unresolved. No learned cell labels.
% nRhs=0 means the energy/invariant-region shortcut avoided an ODE solve.
% Classifier implementation is frozen except for returning solver path points.
switch m.name
    case 'quadratic_cubic'
        [label,nRhs,tEnd,traj]=classify_quadratic_cubic(x0,m,c);
    case 'bistable_duffing'
        [label,nRhs,tEnd,traj]=classify_bistable_duffing(x0,m,c);
    otherwise
        error('limbench:Classifier','Unsupported model.');
end
end
