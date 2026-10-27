function D = genda_A_diagnostics(c)
% Fixed points for every configuration. Reference radius is used only here
% and for error reporting, never to choose the solver's initial conditions.
o=c.options; cells=cell(o.diagnosticAngles*numel(o.radiusFactors),1); i=0;
for r=o.radiusFactors
    for j=0:o.diagnosticAngles-1
        i=i+1;
        file=fullfile(c.outDir,'diagnostics',sprintf('point_%03d.mat',i));
        if isfile(file)
            a=load(file,'point'); cells{i}=a.point; continue
        end
        theta=2*pi*j/o.diagnosticAngles;
        radius=r*c.base.reference_LIM;
        x0=c.base.xe+radius*[cos(theta) sin(theta)]./sqrt(c.base.weight);
        options=odeset('RelTol',o.truthRelTol,'AbsTol',o.truthAbsTol, ...
            'Events',@(~,x) attractor_events(x,c.base.xe,o.truthTolerance));
        timer=tic;
        [~,y,~,~,ie]=ode45(@(t,x) sistema(t,x,c.base.par),[0 o.truthHorizon],x0(:),options);
        label=0; event="unresolved";
        if ~isempty(ie)
            label=ie(end); event="target";
            if label==2, event="other_attractor"; end
        end
        % Domain exit is not a reference label: a trajectory may return.
        point=struct('point_id',i,'theta_rad',theta,'radius_factor',r, ...
            'weighted_radius',radius,'x0',x0(1),'v0',x0(2), ...
            'true_label',label,'truth_event',event,'truth_time',toc(timer), ...
            'final_x',y(end,1),'final_v',y(end,2));
        surrogate_accuracy_util('save',file,struct('point',point));
        cells{i}=point;
    end
end
D=struct2table(vertcat(cells{:}));
surrogate_accuracy_util('table',D,fullfile(c.outDir,'fixed_diagnostic_set.csv'));
fprintf('Fixed independent diagnostic points: %d target, %d other, %d unresolved.\n', ...
    nnz(D.true_label==1),nnz(D.true_label==2),nnz(D.true_label==0));
end

function [value,isterminal,direction]=attractor_events(x,target,tol)
value=[norm(x(:).'-target)-tol; norm(x(:).'-[1 0])-tol];
isterminal=[1;1]; direction=[-1;-1];
end
