function final_plots_LCO(xE,Z,xe,x0,vc,vd,vdout,other_solutions_p,point_crit,LIM,var1,var2,weight)

num_fig2=round(rand*10000);
% plot the phase space with all trajectories, initial conditions 
% utilized and new steady state solutions identified
figure(num_fig2);plot(vc(:,var1),vc(:,var2),'.',vd(:,var1),vd(:,var2),'.',vdout(:,var1),vdout(:,var2),'.',x0(:,var1),x0(:,var2),'kx',...
    'LineWidth',2);xlabel('var1');ylabel('var2');hold on;
for i=1:length(other_solutions_p)
    plot(other_solutions_p{i,1}(:,var1),other_solutions_p{i,1}(:,var2),'g.','MarkerSize',16);
end
plot(Z(:,var1),Z(:,var2),'.','MarkerSize',16,'color',[0.4660 0.6740 0.1880]);
plot(xE(:,var1),xE(:,var2),'p','MarkerSize',8,'LineWidth',2,'Color',[0.6350 0.0780 0.1840]);
plot(point_crit(:,var1),point_crit(:,var2),'m+','MarkerSize',8,'LineWidth',2)

% plot a circle representing the LIM
phi=linspace(0,2*pi,1000);
Rw=LIM;
xcircW=zeros(length(phi),2);
if exist('var1','var')==0
    var1=1;
end
if exist('var2','var')==0
    var2=2;
end
for j=1:size(xe,1)
    for i=1:length(phi)
        xcircW(i,:)=[xe(j,var1)+Rw/sqrt(weight(var1))*cos(phi(i)),xe(j,var2)+Rw/sqrt(weight(var2))*sin(phi(i))];
    end
    figure(num_fig2)
    plot(xcircW(:,1),xcircW(:,2),'k--','LineWidth',2);
end