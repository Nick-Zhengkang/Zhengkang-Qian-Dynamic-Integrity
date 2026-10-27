% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
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
