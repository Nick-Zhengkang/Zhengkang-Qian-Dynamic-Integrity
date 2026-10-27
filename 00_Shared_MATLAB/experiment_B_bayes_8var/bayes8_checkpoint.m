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
function stop=bayes8_checkpoint(results,state,c,restart)
% Atomic native-object checkpoint, including the optimizer RNG for resume.
stop=false;
if strcmp(state,'initial'), return; end
n=results.NumObjectiveEvaluations;
if n==0, return; end
T=results.XTrace;
T.restart=repmat(restart,n,1); T.evaluation=(1:n).';
T.objective=results.ObjectiveTrace;
T.objective_error=results.ErrorTrace;
T.best_objective=cummin(T.objective);
T.phase=repmat("post_initialization",n,1);
T.phase(1:min(n,c.options.initialPoints))="initial_random";
surrogate_accuracy_util('table',T, ...
    fullfile(c.outDir,sprintf('restart_%02d_trace.csv',restart)));
BayesoptResults=results;
optimizerRng=rng;
file=fullfile(c.outDir,sprintf('restart_%02d_checkpoint.mat',restart));
temp=[file '.tmp.mat'];
save(temp,'BayesoptResults','optimizerRng','-v7.3');
[ok,msg]=movefile(temp,file,'f'); assert(ok,'%s',msg);
% bayesopt can otherwise catch an objective error and keep searching.
stop=any(results.ErrorTrace==1) || any(~isfinite(results.ObjectiveTrace));
if stop, fprintf('Stopping after an invalid objective. Inspect raw records and the trace.\n'); end
end
