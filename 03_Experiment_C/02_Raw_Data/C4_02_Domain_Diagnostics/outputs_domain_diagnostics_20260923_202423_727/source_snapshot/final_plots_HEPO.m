function final_plots_HEPO(xE,xe,x0,vc,vd,vdout,other_solutions_p,point_crit,par,LIM,var1,var2,weight,plot_in_time,plot_results_final,tols)

num_fig2=round(rand*10000);

T=par.T;
if plot_in_time == 1
   num_fig=2*num_fig2;
   figure(num_fig);plot3(rem(round(vc(:,end),-log10(tols(2))),T),vc(:,var1),vc(:,var2),'.',...
       rem(round(vd(:,end),-log10(tols(2))),T),vd(:,var1),vd(:,var2),'.',...
       rem(round(vdout(:,end),-log10(tols(2))),T),vdout(:,var1),vdout(:,var2),'.',...
       rem(round(x0(:,end),-log10(tols(2))),T),x0(:,var1),x0(:,var2),'kx','LineWidth',2);xlabel('t');ylabel('var1');zlabel('var2');hold on;
    for i=1:length(other_solutions_p)
        plot3(rem(other_solutions_p{i,1}(:,end),T),other_solutions_p{i,1}(:,var1),other_solutions_p{i,1}(:,var2),'g.','MarkerSize',16);
    end
    plot3(rem(round(xe(:,end),-log10(tols(2))),T),xe(:,var1),xe(:,var2),'r.','MarkerSize',16);
    plot3(rem(round(point_crit(:,end),-log10(tols(2))),T),point_crit(:,var1),point_crit(:,var2),'m+','MarkerSize',8,'LineWidth',2)
end

if plot_results_final == 1
    % plot the phase space with all trajectories, initial conditions 
    % utilized and new steady state solutions identified
    figure(num_fig2);plot(vc(:,var1),vc(:,var2),'.',vd(:,var1),vd(:,var2),'.',vdout(:,var1),vdout(:,var2),'.',x0(:,var1),x0(:,var2),'kx',...
        'LineWidth',2);xlabel('var1');ylabel('var2');hold on;
    for i=1:length(other_solutions_p)
        plot(other_solutions_p{i,1}(:,var1),other_solutions_p{i,1}(:,var2),'g.','MarkerSize',16);
    end
    % plot(Z(:,var1),Z(:,var2),'.','MarkerSize',16,'color',[0.4660 0.6740 0.1880]);
    plot(xE(:,var1),xE(:,var2),'p','MarkerSize',8,'LineWidth',2,'Color',[0.6350 0.0780 0.1840]);
    plot(xe(:,var1),xe(:,var2),'r.','MarkerSize',16);
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

        if plot_in_time==1 && size(xe,1) > 1
            figure(num_fig)
            plot3(rem(xe(j,end),T)*ones(size(xcircW(:,1))),xcircW(:,1),xcircW(:,2),'k--','LineWidth',2);
        end
    end
end