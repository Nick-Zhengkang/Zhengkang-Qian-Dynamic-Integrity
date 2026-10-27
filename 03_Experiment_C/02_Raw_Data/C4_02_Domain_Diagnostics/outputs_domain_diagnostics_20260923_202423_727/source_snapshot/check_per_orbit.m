function x=check_per_orbit(tend,Ts,x0,par,tols,Poincare_sec,number_of_steps,dim)
val_P=Poincare_sec(2);

x=zeros(number_of_steps,dim);
% t=zeros(1,number_of_steps);
i=1;

x(i,:)=x0;
% t(i)=0;
i=i+1;

dt=Ts/10;
TE=0;

flag_dir=sign(x0(1,Poincare_sec(1)) - val_P);
if flag_dir>0.5 && abs(x0(1,Poincare_sec(1))-val_P) < tols(1)
   flag_dir=-1; 
end

while TE < tend
    
    X=sys_solver(dt,x0,par,tols);
    
    vars_P=X(2:end,Poincare_sec(1));
    
    values=vars_P-val_P;
    
    if flag_dir > 0.5
        k=find(values<0,1);
        if ~isempty(k)
            if abs(X(k,Poincare_sec(1))-val_P) < tols(1)
                x(i:i+k-2,:)=X(2:k,:);
%                 t(i:i+k-2)=tau(2:k);
                i=i+k-2;
                
                x=x(1:i,:);
%                 t=t(1:i);
                return
            end
            TE=TE+k*dt/size(X,1);%tau(k);
            x0=X(k,:);
            dt=dt/2;
            
            if k > 1
                x(i:i+k-2,:)=X(2:k,:);
%                 t(i:i+k-2)=tau(2:k);
                i=i+k-1;
            end
        else
            TE=TE+dt;%tau(end);
            x0=X(end,:);
            
            x(i:i+size(X,1)-2,:)=X(2:end,:);
%             t(i:i+length(tau)-2)=tau(2:end);
            i=i+size(X,1)-1;
        end
    else
        k=find(values>0,1);
        if ~isempty(k)
            flag_dir=1;
            kn=find(values(k+1:end)<0,1);
            if ~isempty(kn)
                if abs(X(k+kn,Poincare_sec(1))-val_P) < tols(1)                    
                    x(i:i+k+kn-2,:)=X(2:k+kn,:);
%                     t(i:i+k+kn-2)=tau(2:k+kn);
                    i=i+k+kn-2;

                    x=x(1:i,:);
%                     t=t(1:i);
                    return
                end
                TE=TE+(k+kn)*dt/size(X,1);%tau(k+kn);
                x0=X(k+kn,:);
                dt=dt/2;
                
                x(i:i+k+kn-2,:)=X(2:k+kn,:);
%                 t(i:i+k+kn-2)=tau(2:k+kn);
                i=i+k-1;
            else
                TE=TE+dt;%tau(end);
                x0=X(end,:);
                
                x(i:i+size(X,1)-2,:)=X(2:end,:);
%                 t(i:i+length(tau)-2)=tau(2:end);
                i=i+size(X,1)-1;
            end
        else
            TE=TE+dt;%tau(end);
            x0=X(end,:);
            
            x(i:i+size(X,1)-2,:)=X(2:end,:);
%             t(i:i+length(tau)-2)=tau(2:end);
            i=i+size(X,1)-1;
        end
    end
    
    if TE+dt > tend
        dt=tend-TE;
    end
end

x=x(1:i-1,:);
% t=t(1:i-1);


