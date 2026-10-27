function [red_vect,eliminated]=reduce_vect_self(v,R,weight)

% dim=length(v(1,:));
n=length(v(:,1));
eliminated=zeros(n,1);
Rq=R^2;

for i1=1:n
    if eliminated(i1)==0
        for i2=i1+1:n
            if normweight_q(v(i1,1:end-1)-v(i2,1:end-1),weight)<Rq
%                 v(i1,:)=(v(i1,:)+v(i2,:))/2;
                eliminated(i2)=1;
            end
        end
    end
end
red_vect=v(eliminated==0,:);