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
