function score=ma_objective(T,c)
x=ma_design('matrix',T);
assert(ma_design('feasible',x,c.options));
R=ma_batch(c,x,'train');
% Numerical failures are not removed from the distribution or made attractive.
assert(all(R.success) && all(isfinite(R.absolute_error)), ...
    'multiAlpha:InvalidRun','Training has failed runs. Inspect records; search must stop.');
score=median(R.absolute_error);
id=ma_design('key',x);
byAlpha=ma_report('profile',R);
ma_io('save',fullfile(c.outDir,'observations',[id '.mat']), ...
    struct('x',x,'score',score,'byAlpha',byAlpha));
fprintf('Training %s: median absolute error %.9g; worst alpha median %.9g.\n', ...
    id,score,max(byAlpha.median_absolute_error));
end
