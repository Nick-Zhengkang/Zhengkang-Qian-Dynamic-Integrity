function plot_results(T,S,folder,label)
methods=unique(T.method,'stable'); alphas=unique(T.alpha,'stable');
if numel(alphas)>1
    f=figure('Color','w','Visible','off');
    tiledlayout(2,2);
    names={'R_num_mean','mean_relative_absolute_error','mean_runtime_s','within_1pct_rate'};
    titles={'Mean LIM','Mean relative absolute error','Mean runtime (s)','Fraction within 1%'};
    for k=1:4
        ax=nexttile; hold(ax,'on');
        for m=methods(:)'
            z=S(S.method==m,:); plot(ax,z.alpha,z.(names{k}),'-o','DisplayName',char(m));
        end
        if k==1
            z=S(S.method==methods(1),:); plot(ax,z.alpha,z.R_ref_mean,'k--','DisplayName','Reference');
        end
        title(ax,titles{k}); xlabel(ax,'alpha'); grid(ax,'on');
    end
    legend('Interpreter','none','Location','bestoutside');
else
    f=figure('Color','w','Visible','off'); tiledlayout(2,2);
    names={'R_num','relative_signed_error','runtime_s','trajectory_evaluations'};
    titles={'LIM over paired seeds','Signed relative error','Runtime (s)','Trajectory queries'};
    for k=1:4
        ax=nexttile; hold(ax,'on');
        for j=1:numel(methods)
            z=T(T.method==methods(j),:);
            offsets=linspace(-.16,.16,height(z))';
            scatter(ax,j+offsets,z.(names{k}),18,'filled');
        end
        if k==1, yline(ax,T.R_ref(1),'k--','Reference'); end
        if k==2, yline(ax,0,'k--'); end
        xticks(ax,1:numel(methods)); xticklabels(ax,methods);
        ax.TickLabelInterpreter='none'; xtickangle(ax,25); grid(ax,'on'); title(ax,titles{k});
    end
end
f.Position=[50 50 1500 900]; sgtitle(label,'Interpreter','none');
exportgraphics(f,fullfile(folder,'comparison.png'),'Resolution',180); close(f);
end
