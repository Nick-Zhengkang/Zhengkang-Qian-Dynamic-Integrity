function xprime = sistema(~, x, par)
    xprime = zeros(2,1);
    xprime(1) = x(2);
    xprime(2) = -par.alpha * abs(x(2)) * x(2) - x(1) + x(1)^2;
end
