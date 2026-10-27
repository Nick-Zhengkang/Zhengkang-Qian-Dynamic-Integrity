function m=model(name,alpha)
if any(strcmp(name,{'quadratic_cubic','bistable_duffing'}))
    m=limbench.model(name,alpha); return
end
validateattributes(alpha,{'numeric'},{'scalar','positive','finite'});
m=struct('name',char(name),'alpha',alpha,'target',[0 0],'weight',[1 1]);
switch char(name)
    case 'paper_unforced_duffing'
        m.target=[-1 0]; m.weight=[4 1]; m.a=1;
        m.energy=@(z) z(:,2).^2/2-z(:,1).^2/2+z(:,1).^4/4;
        m.saddleEnergy=0;
    case 'genda_cosine_quadratic_drag'
        m.energy=@(z) z(:,2).^2/2-cos(z(:,1)); m.saddleEnergy=1;
    otherwise, error('Unknown physical model.');
end
end
