function [R,audit]=ma_reference(model,a)
% Evaluate V2 Eqs.52/54/61 or 94/96/103-108. No trajectory integration.
validateattributes(a,{'numeric'},{'scalar','finite','>=',.05,'<=',2});
duffing=strcmp(model,'bistable_duffing');
assert(duffing || strcmp(model,'quadratic_cubic'));
if duffing
    center=-1; saddle=0; cutoff=-2; critical=sqrt(3/2);
    force=@(x) 2*x-2*x.^3;
else
    center=0; saddle=1; cutoff=-1; critical=1;
    force=@(x) -2*x+2*x.^2;
end
p=@(x) branch(x,a,duffing);
g=@(x) 2*(x-center)+force(x)-2*a*p(x);
rows=zeros(2,9);
for stage=1:2
    n=1024*2^stage; opts=optimset('TolX',10^(-9-3*(stage-1)),'Display','off');
    left=cutoff; turn=NaN;
    if p(cutoff)<0
        turn=fzero(p,[cutoff center],opts); left=turn;
    end
    % Saddle distance is 1. Points outside [center-1,saddle] cannot improve it.
    xs=linspace(left,saddle,n+1); gs=g(xs); roots=[];
    for k=1:n
        if gs(k)==0, roots(end+1)=xs(k); end %#ok<AGROW>
        if gs(k)*gs(k+1)<0
            roots(end+1)=fzero(g,[xs(k) xs(k+1)],opts); %#ok<AGROW>
        end
    end
    candidates=unique([left roots saddle]); pv=p(candidates);
    assert(all(pv>=-1e-8),'Inadmissible analytical boundary candidate.');
    [r2,idx]=min((candidates-center).^2+max(0,pv)); x=candidates(idx);
    % Independent quadrature of the integrating-factor formula at all candidates.
    err=0;
    for xx=candidates
        integralP=integral(@(s) force(s).*exp(2*a*(s-xx)),saddle,xx, ...
            'AbsTol',1e-12,'RelTol',1e-12);
        err=max(err,abs(integralP-p(xx)));
    end
    residual=NaN; if isfinite(turn), residual=abs(p(turn)); end
    rows(stage,:)=[a stage n left turn x sqrt(r2) err residual];
end
assert(abs(rows(1,7)-rows(2,7))<1e-8 && max(rows(:,8))<1e-8, ...
    'Analytical reference failed cross-checks.');
R=rows(2,7); assert(isfinite(R) && R>0 && R<=1);
audit=array2table(rows,'VariableNames',{'alpha','stage','scan_intervals', ...
    'scan_left','turning_point_within_radius_one','minimizer_x','reference_LIM', ...
    'integral_crosscheck_residual','turning_residual'});
audit.finite_left_turn_exists=repmat(a<critical,2,1);
audit.model=repmat(string(model),2,1);
end

function p=branch(x,a,duffing)
% A convergent power series avoids cancellation in small-alpha closed forms.
k=2*a;
if duffing
    p=(-4*a^3*x.^3+6*a^2*x.^2+(4*a^3-6*a)*x ...
        -(3-2*a^2)*expm1(-2*a*x))/(4*a^4);
    use=abs(k*x)<2; z=x(use); s=zeros(size(z)); term=ones(size(z));
    for n=0:70
        s=s+term.*(2*z.^2/(n+2)-2*z.^4/(n+4));
        term=term.*(k*z)/(n+1);
    end
    p(use)=exp(-k*z).*s;
else
    p=(2*a^2*x.^2-2*a^2*x-2*a*x+2*a ...
        -(1-a)*expm1(2*a*(1-x)))/(2*a^3);
    % Shift s=1+y: -2*s+2*s^2=2*y+2*y^2, lower limit y=0.
    use=abs(k*(x-1))<2; z=x(use)-1; s=zeros(size(z)); term=ones(size(z));
    for n=0:70
        s=s+term.*(2*z.^2/(n+2)+2*z.^3/(n+3));
        term=term.*(k*z)/(n+1);
    end
    p(use)=exp(-k*z).*s;
end
end
