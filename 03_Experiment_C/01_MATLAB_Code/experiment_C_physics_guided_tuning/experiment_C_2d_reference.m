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
function [R,residual]=experiment_C_2d_reference(model,a)
% Published separatrix-based 2-D LIM, used only for post-run scoring.
assert(a>0 && isfinite(a));
opts=optimset('TolX',1e-12,'Display','off');
switch char(model)
    case 'quadratic_cubic'
        assert(a<1,'This reference implementation is restricted to 0<a<1.');
        p=@(x)(2*a^2*x.^2-2*a^2*x-2*a*x+2*a ...
            -(1-a)*expm1(2*a*(1-x)))/(2*a^3);
        left=-2;
        while p(left)>0, left=left*1.25; end
        xL=fzero(p,[left 0],opts);
        D=(a-1)/(a+1)*exp(2*a-1);
        w=fzero(@(u)u.*exp(u)-D,[-1 0],opts);
        xint=(1+w)/(2*a);
        R=min(abs(xL),xint*sqrt(1+1/a));
        residual=max(abs(p(xL)),abs(w*exp(w)-D));
    case 'bistable_duffing'
        p=@(x)(-4*a^3*x.^3+6*a^2*x.^2+(4*a^3-6*a)*x ...
            -(3-2*a^2)*expm1(-2*a*x))/(4*a^4);
        left=-2;
        while p(left)>0, left=left*1.25; end
        xL=fzero(p,[left -1],opts);
        g=@(x)a*p(x)-2*x-1+x.^3;
        xs=linspace(xL,0,4097); gs=g(xs); roots=[];
        for i=1:numel(xs)-1
            if gs(i)*gs(i+1)<0
                roots(end+1)=fzero(g,[xs(i) xs(i+1)],opts); %#ok<AGROW>
            end
        end
        candidates=unique([xL roots 0]);
        values=(candidates+1).^2+max(0,p(candidates));
        R=sqrt(min(values));
        residual=abs(p(xL));
    case 'cosine_quadratic_drag'
        p=@(x)2/(1+4*a^2)*(cos(x)-2*a*sin(x)+ ...
            exp(2*a*(pi-x)));
        stationarity=@(x)(1+4*a^2)*x-sin(x)- ...
            2*a*cos(x)-2*a*exp(2*a*(pi-x));
        xstar=fzero(stationarity,[0 pi],opts);
        R=sqrt(xstar^2+p(xstar));
        residual=abs(stationarity(xstar));
    otherwise
        error('No reference for %s',char(model));
end
assert(isfinite(R) && R>0 && residual<1e-6, ...
    'Analytical reference residual is too large.');
end
