function [x,s]=bisection_next(s,label,x0,traj,indClosest,R,m,c)
% Adapted from Habib's DynIn v1.1.0 compute_LIM_FP, type_x0==2.
% The label-1/2 branch order and <= / > budget tests are preserved.
% New explicit unresolved branch: do not invent a safe or unsafe endpoint.
if label==0
    s.count=0; s.hasConv=false; s.hasDiv=false;
    x=randomIC_border(2,1.1*R,m.target,m.weight);
elseif label==1
    if s.count<=c.bisIterMax && s.hasDiv
        s.conv=x0; s.hasConv=true;
        x=(s.conv+s.div)/2; s.count=s.count+1;
    else
        s.hasDiv=false; s.hasConv=false; s.count=0;
        x=randomIC_border(2,1.1*R,m.target,m.weight);
    end
else
    if indClosest>1 || s.count>c.bisIterMax
        s.hasDiv=true; s.hasConv=false; s.count=1;
        s.div=traj(indClosest,:); x=(m.target+s.div)/2;
    elseif s.hasConv
        s.div=x0; x=(s.conv+s.div)/2;
        s.hasDiv=true; s.count=s.count+1;
    else
        s.div=x0; x=(m.target+s.div)/2;
        s.hasDiv=true; s.count=s.count+1;
    end
end
% Same fallback as DynIn, with the common target-centred search rectangle.
lower=m.target-c.maxRadius./sqrt(m.weight);
upper=m.target+c.maxRadius./sqrt(m.weight);
if any(x<lower | x>upper)
    x=randomIC_border(2,R,m.target,m.weight);
end
end
