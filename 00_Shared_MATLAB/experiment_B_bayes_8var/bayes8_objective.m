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
function f=bayes8_objective(x,c,restart)
% Fixed seeds make the sampled objective reproducible within this study.
x=reshape(x,1,[]);
assert(numel(x)==8,'Expected eight coordinates.');
assert(all(x(1:7)==round(x(1:7))),'Solver supplied a noninteger discrete coordinate.');
assert(bayes8_design('feasible',x,c.options),'Solver supplied an invalid eight-variable configuration.');
key=bayes8_design('key',x);
tag=sprintf('r%02d_%s',restart,key);
file=fullfile(c.outDir,'observations',[tag '.mat']);
if isfile(file)
    a=load(file,'summary'); f=a.summary.median_absolute_error;
    return
end
fprintf('\nRestart %d: %s, %d common seeds\n',restart,key,numel(c.options.screenSeeds));
R=bayes8_batch(c,x,c.options.screenSeeds,'search',tag);
f=surrogate_accuracy_util('score',R);
summary=table2struct(bayes8_design('table',x));
summary.k=2*x(1)+1; summary.config_id=string(key); summary.restart=restart;
summary.seeds=numel(R); summary.median_absolute_error=f;
summary.median_relative_error_percent=100*f/c.base.reference_LIM;
summary.p95_absolute_error=prctile([R.absolute_error],95);
summary.median_core_time_s=median([R.core_wall_time_s]);
summary.synthetic=c.options.synthetic;
surrogate_accuracy_util('save',file,struct('summary',summary));
surrogate_accuracy_util('export',c.outDir);
fprintf('Median absolute error %.9g; P95 %.9g; median time %.3fs (report only).\n', ...
    f,summary.p95_absolute_error,summary.median_core_time_s);
end
