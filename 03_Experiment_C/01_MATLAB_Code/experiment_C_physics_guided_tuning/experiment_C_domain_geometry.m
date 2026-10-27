% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
function varargout=experiment_C_domain_geometry(action,varargin)
% Duffing energy bounds and integer padding preserving the original lattice.
switch char(action)
    case 'energy_bounds'
        E=varargin{1};
        assert(isscalar(E) && isfinite(E) && E>=-0.25-1e-12);
        E=max(E,-0.25);
        xmax=sqrt(1+sqrt(max(0,1+4*E)));
        vmax=sqrt(max(0,2*(E+0.25)));
        varargout={[-xmax -vmax xmax vmax]};
    case 'pad'
        f=varargin{1}; p=varargin{2}; required=varargin{3}; margin=varargin{4}; maxN=varargin{5};
        assert(numel(required)==4 && all(isfinite(required)) && margin>=0);
        assert(all(required(3:4)>=required(1:2)));
        dh=(f.domain(3:4)-f.domain(1:2))/p.discr;
        extra=margin*(required(3:4)-required(1:2));
        wanted=[min(f.domain(1:2),required(1:2)-extra), ...
            max(f.domain(3:4),required(3:4)+extra)];
        need=[(f.domain(1:2)-wanted(1:2))./dh, ...
            (wanted(3:4)-f.domain(3:4))./dh];
        m=max(0,ceil(max(need)));
        g=f; q=p;
        g.domain=f.domain+[-m*dh m*dh]; q.discr=p.discr+2*m;
        audit=struct('padding_cells_each_side',m,'requested_discr',q.discr, ...
            'within_grid_limit',q.discr<=maxN,'hx',dh(1),'hv',dh(2), ...
            'xmin',g.domain(1),'vmin',g.domain(2),'xmax',g.domain(3),'vmax',g.domain(4));
        newDh=(g.domain(3:4)-g.domain(1:2))/q.discr;
        oldCenter=floor((f.target-f.domain(1:2))./dh)+1;
        newCenter=floor((g.target-g.domain(1:2))./newDh)+1;
        half=(p.k-1)/2;
        oldBelt=[f.domain(1:2)+(oldCenter-half-1).*dh, ...
            f.domain(1:2)+(oldCenter+half).*dh];
        newBelt=[g.domain(1:2)+(newCenter-half-1).*newDh, ...
            g.domain(1:2)+(newCenter+half).*newDh];
        audit.max_step_difference=max(abs(newDh-dh));
        audit.max_target_belt_difference=max(abs(newBelt-oldBelt));
        assert(audit.max_step_difference<1e-12 && audit.max_target_belt_difference<1e-10, ...
            'Padding changed the physical lattice or target belt.');
        assert(all(g.domain(1:2)<=required(1:2)+1e-12) && ...
            all(g.domain(3:4)>=required(3:4)-1e-12),'Envelope was not contained.');
        varargout={g,q,audit};
    otherwise
        error('Unknown geometry action.');
end
end
