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
function selftest_surrogate_accuracy(runSmoke)
% Fast contract checks; optional smoke test runs real surrogateopt on fake data.
if nargin<1, runSmoke=false; end
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
old=path; cleanup=onCleanup(@() path(old));
addpath(fullfile(repo,'experiment_A_bayesian_optimization'));
o=surrogate_accuracy_options('pilot');
assert(~isfield(o,'accuracyAnchor') && ~isfield(o,'priorCandidate') && ~isfield(o,'maxTimeRatio'));
assert(numel(o.optimizerSeeds)==2 && isempty(intersect(o.screenSeeds,o.confirmSeeds)));
[A,b]=surrogate_accuracy_util('constraints');
for p=10:20
    for n=2:12
        for s=2:5
            x=[1 701 5 p n s];
            expected=bayes_A_design('feasible',x,o);
            assert(expected==all(A*x.'<=b+1e-12));
        end
    end
end
assert(bayes_A_design('feasible',[0 352 2 10 2 2],o),'Even discr must remain legal.');
assert(~bayes_A_design('feasible',[0 350 2 10 2 2],o));
R=repmat(struct('valid_for_score',true,'absolute_error',0, ...
    'core_wall_time_s',1,'seed',1),3,1);
for j=1:3, R(j).seed=j; R(j).absolute_error=j; end
assert(surrogate_accuracy_util('score',R)==2);
slow=R;
for j=1:3, slow(j).core_wall_time_s=1e8; end
assert(surrogate_accuracy_util('score',slow)==surrogate_accuracy_util('score',R));
bad=R; bad(1).valid_for_score=false; rejected=false;
try
    surrogate_accuracy_util('score',bad);
catch ME
    rejected=strcmp(ME.identifier,'surrogate_accuracy:InvalidBatch');
end
assert(rejected,'Failed seeds must not disappear from the objective.');
Q=R;
for j=1:3, Q(j).absolute_error=R(j).absolute_error/20; end
C=surrogate_accuracy_util('confirmation',R,Q,o);
assert(C.observed_tenfold_improvement && C.bootstrap_supports_error_improvement);
assert(abs(C.error_reduction_factor-20)<1e-12);
fprintf('PASS: integer bounds, GA constraints, accuracy-only score, failure policy and confirmation checks.\n');
if runSmoke
    so=surrogate_accuracy_options('selftest');
    directory=run_surrogate_accuracy(so,'');
    D=load(fullfile(directory,'study_finished.mat'));
    assert(D.decision.invalid_runs==0);
    T=readtable(fullfile(directory,'optimizer_trace.csv'),'TextType','string');
    assert(~any(T.point_origin=="initial") && any(T.point_origin=="random"));
    assert(any(T.point_origin=="adaptive"),'Smoke budget did not exercise adaptive sampling.');
    files=dir(fullfile(directory,'records','*.mat'));
    before={files.name}; timestamps=[files.datenum];
    run_surrogate_accuracy(so,directory);
    files=dir(fullfile(directory,'records','*.mat'));
    assert(isequal(before,{files.name}) && isequal(timestamps,[files.datenum]));
    fprintf('PASS: real surrogateopt synthetic smoke test and completed-study resume.\n');
end
end
