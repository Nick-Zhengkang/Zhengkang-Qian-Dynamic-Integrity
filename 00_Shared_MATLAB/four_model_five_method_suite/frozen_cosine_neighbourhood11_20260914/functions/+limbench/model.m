function m=model(name,alpha)
% MODEL Reference-free physical problem; no scoring value belongs here.
name=char(name);
if nargin<2 || isempty(alpha)
    if strcmp(name,'quadratic_cubic'), alpha=0.4; else, alpha=0.7; end
end
validateattributes(alpha,{'numeric'},{'scalar','real','finite','positive'});
m=struct('name',name,'alpha',alpha,'target',[0 0],'weight',[1 1]);
switch name
    case 'quadratic_cubic'
        m.energy=@(z) z(:,2).^2/2+z(:,1).^2/2-z(:,1).^3/3;
        m.saddleEnergy=1/6;
    case 'bistable_duffing'
        m.target=[-1 0];
        m.energy=@(z) z(:,2).^2/2-z(:,1).^2/2+z(:,1).^4/4;
        m.saddleEnergy=0;
    otherwise
        error('limbench:Model','Use quadratic_cubic or bistable_duffing (quadratic damping).');
end
end
