function [ref,audit]=reference(name,alpha)
% Scoring only. These values never enter a search or trajectory classifier.
if any(strcmp(name,{'quadratic_cubic','bistable_duffing'}))
    [ref,audit]=limbench.reference(name,alpha);
    ref.kind='analytical_branch_evaluated_numerically'; return
end
assert(abs(alpha-.05)<1e-12,'Fixed-paper settings require 0.05.');
timer=tic;
switch char(name)
    case 'paper_unforced_duffing'
        ref=struct('R',.7683,'kind','published_approximate_numerical', ...
            'source','Habib 2021, doi:10.1007/s11071-021-06936-9, Fig.1 and Sec.4.1', ...
            'runtime',toc(timer),'resolutionDifference',NaN);
        audit=table(alpha,.7683,string(ref.kind),'VariableNames', ...
            {'damping_parameter','reference_LIM','reference_kind'});
    case 'genda_cosine_quadratic_drag'
        a=alpha;
        p=@(x) 2/(1+4*a*a)*(cos(x)-2*a*sin(x)+exp(2*a*(pi-x)));
        F=@(x) (1+4*a*a)*x-sin(x)-2*a*cos(x)-2*a*exp(2*a*(pi-x));
        xs=fzero(F,[0 pi],optimset('TolX',1e-12,'Display','off'));
        R=sqrt(xs^2+p(xs));
        xm=fminbnd(@(x)x*x+p(x),0,pi,optimset('TolX',1e-12,'Display','off'));
        delta=abs(R-sqrt(xm*xm+p(xm)));
        assert(delta<1e-8 && abs(F(xs))<1e-8,'Cosine reference check failed.');
        ref=struct('R',R,'xstar',xs,'kind','analytical_branch_evaluated_numerically', ...
            'source','Genda Manuscript version 2, Fig.2 alpha=.05; Eqs.26,29,34,37', ...
            'runtime',toc(timer),'resolutionDifference',delta);
        audit=table(alpha,xs,R,abs(F(xs)),delta,'VariableNames', ...
            {'alpha','xstar','reference_LIM','stationarity_residual','minimization_crosscheck'});
    otherwise, error('Unknown reference.');
end
end
