% double well (unforced)
function xprime = sistema(t,x,par)
%par = [zeta a b];
    xprime=zeros(2,1);
    % ============================= State Space ========================
    xprime(1)=x(2);
    xprime(2)=-2*par.zeta*x(2)+par.b*x(1)-par.a*x(1)^3;
    % ===================================================================
end
