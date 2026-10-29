function dz=sistema(~,z,par)
dz=zeros(4,1); z=z(:);
dz(1)=z(2);
dz(2)=-par.alpha_qc*abs(z(2))*z(2)-z(1)+z(1)^2;
dz(3)=z(4);
dz(4)=-par.alpha_bd*abs(z(4))*z(4)+z(3)-z(3)^3;
end
