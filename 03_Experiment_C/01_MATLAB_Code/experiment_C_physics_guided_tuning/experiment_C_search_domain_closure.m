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
function varargout=experiment_C_search_domain_closure(action,varargin)
% Certified geometry for quadratic-drag Duffing, target (-1,0), W=I.
% Does not use reference LIM or change any original DynIn routine.
switch char(action)
    case 'audit'
        g=varargin{1}; p=varargin{2}; validate_model(g);
        d=g.domain; h=(d(3:4)-d(1:2))/p.discr;
        R=min([g.target-d(1:2),d(3:4)-g.target]);
        assert(R>0);
        % For u=x+1 and u^2+v^2<=R^2, the maximum is at u=-R,v=0.
        E=-0.25+R^2+R^3+R^4/4;
        X=1+R; V=R*(R+2)/sqrt(2);
        bound=[-X -V X V];
        slack=[bound(1:2)-d(1:2),d(3:4)-bound(3:4)];
        a=struct('alpha',g.alpha,'initial_search_radius',R, ...
            'search_energy_cap',E,'required_xmin',-X,'required_vmin',-V, ...
            'required_xmax',X,'required_vmax',V,'xmin',d(1),'vmin',d(2), ...
            'xmax',d(3),'vmax',d(4),'discr',p.discr,'hx',h(1),'hv',h(2), ...
            'left_slack',slack(1),'bottom_slack',slack(2), ...
            'right_slack',slack(3),'top_slack',slack(4), ...
            'exact_energy_envelope_covered',all(slack>=-1e-12), ...
            'strict_margin_all_faces',all(slack>1e-12));
        varargout={a};
    case 'build'
        f=varargin{1}; p=varargin{2}; maxGrid=varargin{3};
        a=experiment_C_search_domain_closure('audit',f,p);
        % Pin the left face that defines R0. No claim for other limiting faces.
        R=a.initial_search_radius;
        assert(abs(f.domain(1)-(-1-R))<1e-12, ...
            'This construction requires the left x face to determine R0.');
        h=[a.hx a.hv]; d=f.domain;
        guard=2; % Extra lattice cells on the three unpinned faces.
        nx=max(0,ceil((a.required_xmax-d(3))/h(1))+guard);
        nvLo=max(0,ceil((d(2)-a.required_vmin)/h(2))+guard);
        nvHi=max(0,ceil((a.required_vmax-d(4))/h(2))+guard);
        M=max(nx,nvLo+nvHi);
        % Scalar discr needs the same total number of extra cells per axis.
        nvLo=nvLo+floor((M-nvLo-nvHi)/2); nvHi=M-nvLo;
        g=f; q=p; q.discr=p.discr+M;
        g.domain=d+[0 -nvLo*h(2) M*h(1) nvHi*h(2)];
        audit=experiment_C_search_domain_closure('audit',g,q);
        assert(abs(audit.initial_search_radius-R)<1e-12,'R0 changed.');
        assert(max(abs([audit.hx audit.hv]-h))<1e-12,'Grid widths changed.');
        assert(audit.exact_energy_envelope_covered,'Search envelope is not covered.');
        oldBelt=belt(f,p); newBelt=belt(g,q);
        audit.max_target_belt_difference=max(abs(oldBelt-newBelt));
        assert(audit.max_target_belt_difference<1e-10,'Target belt changed.');
        audit.within_grid_limit=q.discr<=maxGrid;
        audit.radius_preserved=true;
        audit.added_x_lower=0; audit.added_x_upper=M;
        audit.added_v_lower=nvLo; audit.added_v_upper=nvHi;
        varargout={g,q,audit};
    otherwise
        error('Unknown closure action.');
end
end

function validate_model(g)
assert(string(g.model)=="bistable_duffing" && g.alpha>0 && ...
    isequal(g.target,[-1 0]) && isequal(g.weight,[1 1]), ...
    'Proof is restricted to dissipative bistable Duffing, target (-1,0), W=I.');
end

function b=belt(g,p)
h=(g.domain(3:4)-g.domain(1:2))/p.discr; c=zeros(1,2);
for j=1:2
    centers=g.domain(j)+((0:p.discr-1)+0.5)*h(j);
    [~,c(j)]=min(abs(centers-g.target(j)));
end
assert(mod(p.k,2)==1,'This audit expects an odd target-neighbourhood width.');
half=(p.k-1)/2;
b=[g.domain(1:2)+(c-half-1).*h,g.domain(1:2)+(c+half).*h];
end
