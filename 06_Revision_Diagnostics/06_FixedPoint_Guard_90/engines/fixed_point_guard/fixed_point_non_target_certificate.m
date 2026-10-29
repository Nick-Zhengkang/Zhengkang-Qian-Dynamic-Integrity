function [accepted,energy,margin]=fixed_point_non_target_certificate(z,d)
% AI-assisted implementation of the author's requested fixed-point repair.
% Residence alone is not evidence of a non-target attractor. For these
% autonomous quadratic-drag models, dE/dt=-alpha*abs(v)^3 <= 0.
% No reference LIM, search radius, seed or query number enters this test.
assert(numel(z)==2 && all(isfinite(z)) && d.par.alpha>0);
id=char(d.model_id);
x=z(1); v=z(2); accepted=false;
switch id
    case 'quadratic_cubic'
        assert(norm(reshape(d.target,1,[])-[0,0],Inf)<1e-12);
        energy=0.5*v^2+0.5*x^2-x^3/3; margin=1/6-energy;
        % The other equilibrium is a saddle, not a stable non-target well.
        % Reject residence-based termination; retain direct domain-exit logic.
    case 'bistable_duffing'
        assert(norm(reshape(d.target,1,[])-[-1,0],Inf)<1e-12);
        energy=0.5*v^2+0.25*(x^2-1)^2; margin=0.25-energy;
        accepted=x>0 && margin>1e-7;
    case 'genda_cosine_quadratic_drag'
        assert(norm(reshape(d.target,1,[])-[0,0],Inf)<1e-12);
        energy=0.5*v^2+1-cos(x); margin=2-energy;
        accepted=abs(x)>pi && margin>1e-7;
    otherwise
        error('Fixed-point certificate is not defined for model %s.',id);
end
end
