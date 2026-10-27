% Duffing-Van der Pol with attached NLTVA (in modal coordinates)

function xprime = sistema(t,x,par)
    xprime=zeros(4,1);
    % ============================= State Space ========================
    xprime(1)=x(2);
    xprime(2)=par(1)*x(1)+par(2)*x(2)+par(3)*x(4)+par(4)*x(1)*x(2)*x(3)+par(5)*x(1)*x(3)*x(4)+par(6)*x(1)*x(3)^2+par(7)*x(1)^2*x(2)+...
        par(8)*x(2)*x(3)^2+par(9)*x(1)^2*x(3)+par(10)*x(1)^2*x(4)+par(11)*x(3)^2*x(4)+par(23)*x(1)^3+par(24)*x(3)^3;
    xprime(3)=x(4);
    xprime(4)=par(12)*x(2)+par(13)*x(3)+par(14)*x(4)+par(15)*x(1)*x(2)*x(3)+par(16)*x(1)*x(3)*x(4)+par(17)*x(1)*x(3)^2+par(18)*x(1)^2*x(2)+...
        par(19)*x(2)*x(3)^2+par(20)*x(1)^2*x(3)+par(21)*x(1)^2*x(4)+par(22)*x(3)^2*x(4)+par(25)*x(1)^3+par(26)*x(3)^3;
    % ===================================================================
end