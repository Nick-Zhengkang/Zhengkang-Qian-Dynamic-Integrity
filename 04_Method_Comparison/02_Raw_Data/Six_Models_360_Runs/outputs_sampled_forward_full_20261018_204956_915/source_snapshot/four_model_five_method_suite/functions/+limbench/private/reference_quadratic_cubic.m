function [ref,audit]=reference_quadratic_cubic(a)
% Eq.61: compare the left endpoint and the interior Lambert-W candidate.
% Restrict to the finite-left-turn regime; the default test is alpha=0.4.
assert(a>=0.1 && a<=0.95,'This reference supports 0.1 <= alpha <= 0.95.');
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
    xL=fzero(p,[left 0],opts);
    % Eq.54: alpha*p(x) = x^2. Include all stationary roots as a check.
    g=@(x) a*p(x)-x.^2;
    xs=linspace(xL,1,n+1); gs=g(xs); roots=[];
    for k=1:n
        if gs(k)==0, roots(end+1)=xs(k); end %#ok<AGROW>
        if gs(k)*gs(k+1)<0
            roots(end+1)=fzero(g,[xs(k) xs(k+1)],opts); %#ok<AGROW>
        end
    end
    roots=unique(roots);
    candidates{stage}=[xL roots 1];
    values=candidates{stage}.^2+max(0,p(candidates{stage}));
    boundaryMinimum=sqrt(min(values));
    % Evaluate principal Lambert W without Symbolic Math Toolbox.
    D=(a-1)/(a+1)*exp(2*a-1);
    w=fzero(@(w) w.*exp(w)-D,[-1 0],opts);
    xint=(1+w)/(2*a); rint=xint*sqrt(1+1/a); rend=abs(xL);
    R=min(rend,rint);
    if rend<=rint, xstar=xL; else, xstar=xint; end
    % Cross-check Eq.52 against the general integral representation, Eq.8.
    pi=exp(-2*a*xstar)*integral(@(s)(-2*s+2*s.^2).*exp(2*a*s), ...
        1,xstar,'AbsTol',1e-12,'RelTol',1e-12);
    residual=abs(pi-p(xstar));
    rows(end+1,:)=[stage,n,tol,xL,xstar,R,abs(p(xL)),residual,toc(t), ...
        rint,rend,abs(boundaryMinimum-R),abs(w*exp(w)-D)]; %#ok<AGROW>
end
delta=abs(rows(2,6)-rows(1,6));
assert(delta<1e-8 && max(rows(:,8))<1e-8 && max(rows(:,12))<1e-8, ...
    'Analytical-reference evaluation failed its checks.');
ref=struct('R',rows(2,6),'xstar',rows(2,5),'xL',rows(2,4), ...
    'resolutionDifference',delta,'runtime',toc(timer), ...
    'source','Genda V2, Secs.3.5-3.6, Eqs.52,54,56-61', ...
    'candidates',{candidates});
audit=array2table(rows,'VariableNames',{'stage','root_scan_intervals','root_tolerance', ...
    'left_turning_point','minimizer_x','reference_LIM','turning_residual', ...
    'integral_crosscheck_residual','evaluation_s','interior_radius','endpoint_radius', ...
    'stationary_root_crosscheck_difference','Lambert_equation_residual'});
end

function p=paper_p(x,a)
% Eq.52 with expm1: p(1)=0 exactly in this algebraic representation.
p=(2*a^2*x.^2-2*a^2*x-2*a*x+2*a ...
    -(1-a)*expm1(2*a*(1-x)))/(2*a^3);
end
