function dz=sistema(~,z,par)
dz=zeros(2,1); z=z(:); dz(1)=z(2);
dz(2)=-2*par.alpha*z(2)+z(1)-par.a*z(1)^3;
end
