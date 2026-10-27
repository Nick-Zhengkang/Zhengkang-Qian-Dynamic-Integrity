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
function [R,audit]=duffing_transfer_reference(a)
% Fig.9 lower envelope, V2 Eqs.94/96. No trajectory integration.
% Keep the frozen BO study's reference evaluator unchanged.
validateattributes(a,{'numeric'},{'scalar','finite','>=',.05,'<=',2});
p=@(x) branch(x,a);
force=@(x) 2*x-2*x.^3;
g=@(x) 2*(x+1)+force(x)-2*a*p(x);
rows=zeros(2,11);
for stage=1:2
    n=1024*2^stage;
    opts=optimset('TolX',1e-13,'Display','off');
    left=-2; turn=NaN; width=NaN; residual=NaN;
    if p(-2)<0
        % Return the p>=0 side of a tight root bracket, not a coarse fzero
        % iterate which can fall outside the physical branch.
        [turn,width]=admissible_turn(p,-2,-1);
        left=turn; residual=abs(p(turn));
        assert(residual<1e-10 && width<1e-12, ...
            'duffing_transfer:TurningResidual', ...
            'alpha=%.17g: turning residual %.3g, bracket width %.3g.',a,residual,width);
    end
    xs=linspace(left,0,n+1); gs=g(xs); roots=[];
    for k=1:n
        if gs(k)==0, roots(end+1)=xs(k); end %#ok<AGROW>
        if gs(k)*gs(k+1)<0
            roots(end+1)=fzero(g,[xs(k) xs(k+1)],opts); %#ok<AGROW>
        end
    end
    candidates=unique([left roots 0]); pv=p(candidates);
    minP=min(pv);
    assert(all(pv>=-1e-10),'duffing_transfer:InadmissibleBoundary', ...
        'alpha=%.17g, stage=%d: minimum candidate p=%.17g.',a,stage,minP);
    % The turning-point velocity is exactly zero; its raw numerical residual
    % is checked above and retained below. Other candidates remain checked.
    if isfinite(turn), pv(candidates==turn)=0; end
    [r2,idx]=min((candidates+1).^2+max(0,pv));
    err=0;
    for xx=candidates
        integralP=integral(@(s) force(s).*exp(2*a*(s-xx)),0,xx, ...
            'AbsTol',1e-12,'RelTol',1e-12);
        err=max(err,abs(integralP-p(xx)));
    end
    rows(stage,:)=[a stage n left turn candidates(idx) sqrt(r2) err residual width minP];
end
assert(abs(rows(1,7)-rows(2,7))<1e-8 && max(rows(:,8))<1e-8, ...
    'duffing_transfer:ReferenceCrosscheck','alpha=%.17g: analytical cross-check failed.',a);
R=rows(2,7); assert(isfinite(R) && R>0 && R<=1);
audit=array2table(rows,'VariableNames',{'alpha','stage','scan_intervals', ...
    'scan_left','turning_point_within_radius_one','minimizer_x','reference_LIM', ...
    'integral_crosscheck_residual','turning_residual','turning_bracket_width', ...
    'minimum_raw_candidate_p'});
audit.finite_left_turn_exists=repmat(a<sqrt(3/2),2,1);
audit.model=repmat("bistable_duffing",2,1);
end

function [hi,width]=admissible_turn(p,lo,hi)
assert(p(lo)<0 && p(hi)>0,'Turning-point bracket must straddle p=0.');
for j=1:100
    mid=lo+(hi-lo)/2;
    if mid==lo || mid==hi, break; end
    if p(mid)<0, lo=mid; else, hi=mid; end
end
width=hi-lo;
assert(p(hi)>=0,'Turning-point endpoint must be on the admissible side.');
end

function p=branch(x,a)
% Stable evaluation of the analytical velocity-squared separatrix.
k=2*a;
p=(-4*a^3*x.^3+6*a^2*x.^2+(4*a^3-6*a)*x ...
    -(3-2*a^2)*expm1(-2*a*x))/(4*a^4);
use=abs(k*x)<2; z=x(use); s=zeros(size(z)); term=ones(size(z));
for n=0:70
    s=s+term.*(2*z.^2/(n+2)-2*z.^4/(n+4));
    term=term.*(k*z)/(n+1);
end
p(use)=exp(-k*z).*s;
end
