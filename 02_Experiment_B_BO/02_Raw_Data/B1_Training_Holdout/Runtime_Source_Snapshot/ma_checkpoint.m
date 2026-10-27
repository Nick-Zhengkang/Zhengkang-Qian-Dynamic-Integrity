function stop=ma_checkpoint(results,state,c,restart)
stop=false;
if strcmp(state,'initial') || results.NumObjectiveEvaluations==0, return; end
n=results.NumObjectiveEvaluations; T=results.XTrace;
T.evaluation=(1:n)'; T.objective=results.ObjectiveTrace;
T.objective_error=results.ErrorTrace; T.best_so_far=cummin(T.objective);
T.phase=repmat("BO",n,1); T.phase(1:min(n,c.options.initialPoints))="initial_random";
writetable(T,fullfile(c.outDir,sprintf('restart_%d_trace.csv',restart)));
ma_io('save',fullfile(c.outDir,sprintf('restart_%d_checkpoint.mat',restart)), ...
    struct('BayesoptResults',results,'optimizerRng',rng));
stop=any(results.ErrorTrace==1) || any(~isfinite(results.ObjectiveTrace));
end
