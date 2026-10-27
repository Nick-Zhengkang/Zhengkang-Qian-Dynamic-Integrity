function dz=sistema(~,z,par)
dz=zeros(2,1); z=z(:); dz(1)=z(2);
dz(2)=-par.alpha*abs(z(2))*z(2)-z(1)+z(1)^2;
end
