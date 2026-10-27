function [R1,point_crit,ind_closest]=cal_R_HEPO(xt,xe,point_crit,dims,type_x0,R0,phase_IC,phase_out,weight,Nt)

if type_x0~=2
    ind_closest=[];
    R_puffer = R0;
    if size(xt,1)==1
        for J=phase_IC:phase_out
            [R1,Icrit]=findradius_bis(xt(:,1:dims,J),xe(J,1:dims),weight); % calculate new radius of convergence, comparing the old one with the one for the new points
            if R1<R_puffer
                R_puffer = R1;
                point_crit=xt(Icrit,:,J);
            end
        end
    else 
        for J=1:Nt
            if J<phase_IC
                ibegin=2;
            else
                ibegin=1;
            end
            if J>phase_out
                iend=size(xt,1)-1;
            else
                iend=size(xt,1);
            end
            if ibegin<=iend
                [R1,Icrit]=findradius_bis(xt(ibegin:iend,1:dims,J),xe(J,1:dims),weight); % calculate new radius of convergence, comparing the old one with the one for the new points
                if R1<R_puffer
                    R_puffer = R1;
                    point_crit=xt(Icrit+ibegin-1,:,J);
                end
            end
        end
    end
    R1=R_puffer;
else
    R_puffer = R0;
    if size(xt,1)==1
        for J=phase_IC:phase_out
            [R1,Icrit]=findradius_bis(xt(:,1:dims,J),xe(J,1:dims),weight); % calculate new radius of convergence, comparing the old one with the one for the new points
            if R1<R_puffer
                R_puffer = R1;
                point_crit=xt(Icrit,:,J);
            end
            if J==phase_IC
                ind_closest=Icrit;
            end              
        end
    else 
        for J=1:Nt
            if J<phase_IC
                ibegin=2;
            else
                ibegin=1;
            end
            if J>phase_out
                iend=size(xt,1)-1;
            else
                iend=size(xt,1);
            end
            if ibegin<=iend
                [R1,Icrit]=findradius_bis(xt(ibegin:iend,1:dims,J),xe(J,1:dims),weight); % calculate new radius of convergence, comparing the old one with the one for the new points
                if R1<R_puffer
                    R_puffer = R1;
                    point_crit=xt(Icrit+ibegin-1,:,J);
                end
                if J==phase_IC
                    ind_closest=Icrit;
                end   
            end
        end
    end
    R1=R_puffer;
end