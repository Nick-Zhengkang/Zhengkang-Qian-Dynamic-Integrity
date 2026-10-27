function [red_vect,eliminated]=reduce_vect_NOSELF(v1,v2,R,weight)
% reduce_vect_NOSELF(v1,v2,R,weight)
%
% eliminate points which are very close to each other (within a distance R)
% between two lists of points (v1 and v2).
% weight is used for computaing the weighted distance.
% This function is not used in the lates version of the code, but it is
% substituted by the Matlab function uniquetol

n1 = length(v1(:,1));
n2 = length(v2(:,1));
eliminated = zeros(n1,1);
Rq = R^2;

for i1 = 1:n1
    for i2 = 1:n2
        if normweight_q(v1(i1,1:end-1)-v2(i2,1:end-1),weight)<Rq
            eliminated(i1) = 1;
            break
        end
    end
end
red_vect = v1(eliminated==0,:);