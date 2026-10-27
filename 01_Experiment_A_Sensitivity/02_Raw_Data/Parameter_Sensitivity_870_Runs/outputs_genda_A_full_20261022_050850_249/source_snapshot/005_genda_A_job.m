function row = genda_A_job(c,cfg,seed,order)
key=cfg.config_id+"__seed_"+seed;
% The shared atomic writer appends suffixes with character concatenation.
file=char(fullfile(c.outDir,'records',key+".mat"));
if isfile(file)
    a=load(file,'row'); row=a.row;
    assert(row.seed==seed && row.config_id==cfg.config_id && row.execution_order==order);
    return
end
old=rng; cleanup=onCleanup(@() rng(old));
rng(100000+seed,'twister');
[result,OutL,OutH]=original_A_adapter('execute',cfg,c.base);
row=cfg; row.run_key=key; row.seed=seed; row.execution_order=order;
row.reference_LIM=c.base.reference_LIM;
row.success=result.success; row.R_hat=result.R_hat;
row.absolute_error=abs(result.R_hat-c.base.reference_LIM);
row.relative_error_percent=100*row.absolute_error/c.base.reference_LIM;
row.signed_relative_error_percent=100*(result.R_hat-c.base.reference_LIM)/c.base.reference_LIM;
row.core_wall_time_s=result.wall_runtime_s;
row.algorithm_runtime_s=result.algorithm_runtime_s;
row.trajectory_evaluations=result.trajectory_evaluations;
row.processed_time_samples=result.processed_time_samples;
row.internal_unresolved_count=result.internal_unresolved_count;
row.error_message=string(result.error_message);
row.worker_task_id=0;
if c.options.useParallel
    task=getCurrentTask(); row.worker_task_id=task.ID;
end
row.pilot_only=~strcmp(c.options.mode,'full');
row.saved_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
row.diagnostic_success=false; row.diagnostic_error_message="";
row.diagnostic_runtime_s=NaN;
metrics=original_A_adapter('empty_diagnostic');
if result.success
    timer=tic;
    try
        % Reuse the old A diagnostic readout, but its sys_solver now resolves
        % to the quadratic-damping model. It does not change the native run.
        metrics=original_A_adapter('evaluate',c.diagnostic,OutH,cfg,c.base);
        row.diagnostic_success=true;
    catch ME
        row.diagnostic_error_message=string(getReport(ME,'basic','hyperlinks','off'));
    end
    row.diagnostic_runtime_s=toc(timer);
end
names=fieldnames(metrics);
for j=1:numel(names), row.(names{j})=metrics.(names{j}); end
data=struct('row',row);
if c.options.saveTrajectories, data.OutL=OutL; data.OutH=OutH; end
surrogate_accuracy_util('save',file,data);
end
