function [R1,point_crit,Jcrit,ind_closest]=cal_R_LCO(xt,xe,point_crit,type_x0,R0,weight,Nt)

[R1,Icrit]=findradius_bis(xt,xe(1,:),weight); % calculate new radius of convergence, comparing the old one with the one for the new points
Jcrit=1;
ind_closest=Icrit;

if type_x0~=2
    Jcrit=[];
    for J=2:Nt
        [R_puffer,Icrit]=findradius_bis(xt,xe(J,:),weight); % calculate new radius of convergence, comparing the old one with the one for the new points
        if R_puffer<R1
            R1 = R_puffer;
            ind_closest=Icrit;            
        end
    end
else
%     R_puffer = R0;
    for J=1:Nt
        [R_puffer,Icrit]=findradius_bis(xt,xe(J,:),weight); % calculate new radius of convergence, comparing the old one with the one for the new points
        if R_puffer<R1
            R1 = R_puffer;
            Jcrit=J;
            ind_closest=Icrit;
        end              
    end
end

if R1<R0
    point_crit=xt(ind_closest,:);
else
    R1=R0;
end