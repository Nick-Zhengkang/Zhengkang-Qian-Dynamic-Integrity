function [ref,audit]=reference_bistable_duffing(a)
% Numerically evaluate the paper's analytical equations, not trajectory data.
% Restrict this implementation to a well-conditioned range with a left turn.
assert(a>=0.1 && a<=1,'Reference implementation validated for 0.1 <= alpha <= 1.');
timer=tic; rows=[]; candidates=cell(1,2);
for stage=1:2
    n=1024*2^stage; tol=10^(-9-3*(stage-1)); t=tic;
    p=@(x) paper_p(x,a);
    left=-2;
    while p(left)>0
        left=left*1.25;
        assert(abs(left)<50,'Cannot bracket the nontrivial left turning point.');
    end
    opts=optimset('TolX',tol,'Display','off');
    xL=fzero(p,[left -1],opts);
    % Eq. (96): alpha*p(x) = 2*x + 1 - x^3.
    g=@(x) a*p(x)-2*x-1+x.^3;
    xs=linspace(xL,0,n+1); gs=g(xs); roots=[];
    for k=1:n
        if gs(k)==0, roots(end+1)=xs(k); end %#ok<AGROW>
        if gs(k)*gs(k+1)<0
            roots(end+1)=fzero(g,[xs(k) xs(k+1)],opts); %#ok<AGROW>
        end
    end
    roots=unique(roots);
    candidates{stage}=[xL roots 0];
    values=(candidates{stage}+1).^2+max(0,p(candidates{stage}));
    [v,ind]=min(values); R=sqrt(v); xstar=candidates{stage}(ind);
    % Independent evaluation of the SAME formula via its integral form, Eq.113.
    pi=exp(-2*a*xstar)*integral(@(s)(2*s-2*s.^3).*exp(2*a*s), ...
        0,xstar,'AbsTol',1e-12,'RelTol',1e-12);
    residual=abs(pi-p(xstar));
    rows(end+1,:)=[stage,n,tol,xL,xstar,R,abs(p(xL)),residual,toc(t)]; %#ok<AGROW>
end
delta=abs(rows(2,6)-rows(1,6));
assert(delta<1e-8 && max(rows(:,8))<1e-8,'Analytical-reference evaluation failed its checks.');
ref=struct('R',rows(2,6),'xstar',rows(2,5),'xL',rows(2,4), ...
    'resolutionDifference',delta,'runtime',toc(timer), ...
    'source','Genda V2, Sec.4.5, Eqs.94,96,103-105,110-112', ...
    'candidates',{candidates});
audit=array2table(rows,'VariableNames',{'stage','root_scan_intervals','root_tolerance', ...
    'left_turning_point','minimizer_x','reference_LIM','turning_residual', ...
    'integral_crosscheck_residual','evaluation_s'});
end

function p=paper_p(x,a)
% Eq.94 with expm1 to reduce subtraction of equal constant terms.
p=(-4*a^3*x.^3+6*a^2*x.^2+(4*a^3-6*a)*x ...
    -(3-2*a^2)*expm1(-2*a*x))/(4*a^4);
end
