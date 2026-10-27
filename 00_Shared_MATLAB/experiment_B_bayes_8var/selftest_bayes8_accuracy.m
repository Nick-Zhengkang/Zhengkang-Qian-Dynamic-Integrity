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
function selftest_bayes8_accuracy(runSmoke,runNative)
% Fast contracts by default; optional synthetic BO and native trajectory tests.
if nargin<1, runSmoke=false; end
if nargin<2, runNative=false; end
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
oldPath=path; oldFolder=pwd; oldRng=rng;
cleanup=onCleanup(@() restore_session(oldPath,oldFolder,oldRng));
shared=fullfile(repo,'experiment_A_bayesian_optimization');
adapter=fullfile(repo,'experiment_A_top6_exhaustive');
native=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
model=fullfile(root,'model_genda_duffing');
addpath(root,shared,adapter,fullfile(repo,'experiment_B_accuracy_first_bayes'), ...
    fullfile(repo,'experiment_B_surrogate_accuracy'), ...
    fullfile(repo,'four_model_five_method_suite','functions'));
accuracy_first_activate(root,shared,adapter,native,model);
o=bayes8_options('pilot'); f=bayes8_options('full');
assert(numel(o.screenSeeds)==10 && numel(f.screenSeeds)==10);
assert(o.evaluationsPerRestart==32 && f.evaluationsPerRestart==200);
assert(f.initialPoints==16 && numel(f.optimizerSeeds)==2 && numel(f.confirmSeeds)==100);
assert(isempty(intersect(f.screenSeeds,f.confirmSeeds)));
assert(~isfield(o,'maxTimeRatio') && ~isfield(o,'priorCandidate') && ~isfield(o,'accuracyAnchor'));
[base,reference,audit]=bayes8_problem(o);
assert(abs(reference.R-.7289278591561151)<1e-10 && height(audit)==2);
assert(isequal(base.xe,[-1 0]) && isequal(base.weight,[1 1]));
assert(isequal(base.spaceboundary,[-3 -2 3 4]) && ~isfield(base.par,'zeta'));
assert(norm(sistema(0,[0;2],base.par)-[2;-2.8])<1e-12);
assert(norm(sistema(0,[0;-2],base.par)-[-2;2.8])<1e-12);
for x=[-1 0 1], assert(norm(sistema(0,[x;0],base.par))==0); end
bx=bayes8_design('baseline',base);
assert(isequal(bx,[1 701 5 20 8 3 100 .05]));
b=bayes8_design('config',bx,base);
q=bayes8_design('config',[3 900 8 12 5 4 161 .0748123456789],base);
changed={'num_of_cell_around_equilibrium','discr','num_gen','population_size', ...
    'newcomers','selected_opt','num_crossover','newcomer_fraction','config_id', ...
    'number_of_steps','Ts'};
assert(isequaln(rmfield(b,changed),rmfield(q,changed)), ...
    'Nonsearched algorithm controls must remain unchanged.');
[A,rhs]=surrogate_accuracy_util('constraints');
for p=10:20
    for n=2:12
        for s=2:5
            x=[1 701 5 p n s 100 .05];
            assert(bayes8_design('feasible',x,o)==all(A*x(1:6).'<=rhs+1e-12));
        end
    end
end
assert(bayes8_design('feasible',[0 352 2 10 2 2 50 .025],o));
assert(~bayes8_design('feasible',[0 350 2 10 2 2 50 .025],o));
assert(isequal(bayes8_design('matrix',bayes8_design('table',bx)),bx));
assert(isequal(bayes8_design('names'), ...
    {'qk','discr','generations','population','newcomers','selected','number_of_steps','Ts'}));
assert(q.number_of_steps==161 && q.Ts==.0748123456789);
for steps=[50 100 200]
    for interval=[.025 .05 .0748123456789 .1]
        x=bx; x(7:8)=[steps interval];
        assert(bayes8_design('feasible',x,o));
        cfg=bayes8_design('config',x,base);
        assert(cfg.number_of_steps==steps && cfg.Ts==interval);
    end
end
for badSteps=[49 200.5 201 NaN Inf]
    x=bx; x(7)=badSteps; assert(~bayes8_design('feasible',x,o));
end
for badTs=[0 .0249 .1001 NaN Inf]
    x=bx; x(8)=badTs; assert(~bayes8_design('feasible',x,o));
end
x=bx; x(8)=x(8)+eps(x(8));
assert(~strcmp(bayes8_design('key',x),bayes8_design('key',bx)), ...
    'Distinct continuous intervals cannot share a cached configuration.');
x=bx; x(7)=101;
assert(~strcmp(bayes8_design('key',x),bayes8_design('key',bx)));
assert(isequal(bayes8_design('feasible',bayes8_design('table',[bx;x]),o),[true;true]));
R=repmat(struct('valid_for_score',true,'absolute_error',0, ...
    'relative_error_percent',0,'reference_LIM',reference.R,'R_hat',reference.R, ...
    'core_wall_time_s',1,'seed',1,'worker_task_id',0,'execution_order',1),3,1);
for j=1:3
    R(j).seed=j; R(j).absolute_error=j*.01;
    R(j).R_hat=reference.R+R(j).absolute_error;
    R(j).relative_error_percent=100*R(j).absolute_error/reference.R;
end
assert(abs(surrogate_accuracy_util('score',R)-.02)<1e-12);
Q=R;
for j=1:3, Q(j).core_wall_time_s=1e8; end
assert(surrogate_accuracy_util('score',Q)==surrogate_accuracy_util('score',R));
bad=R; bad(1).valid_for_score=false; rejected=false;
try
    surrogate_accuracy_util('score',bad);
catch ME
    rejected=strcmp(ME.identifier,'surrogate_accuracy:InvalidBatch');
end
assert(rejected,'Failed seeds cannot be dropped from the objective.');
for j=1:3
    Q(j).absolute_error=R(j).absolute_error/20;
    Q(j).R_hat=reference.R+Q(j).absolute_error;
    Q(j).relative_error_percent=100*Q(j).absolute_error/reference.R;
    Q(j).execution_order=2;
end
[C,P]=bayes8_confirmation(R,Q,o);
assert(C.observed_tenfold_improvement && C.bootstrap_supports_error_improvement);
assert(C.bootstrap_supports_tenfold_improvement);
assert(abs(C.error_reduction_factor-20)<1e-12 && abs(C.error_reduction_percent-95)<1e-12);
assert(C.candidate_within_1_percent==3 && height(P)==3);
assert(all(P.error_difference<0) && C.descriptive_time_ratio==1e8);
fprintf('PASS: quadratic model, analytical reference, fixed controls, mixed integer/real bounds, accuracy-only score, pairing and budgets.\n');
if runNative
    % Changing only the reference must not change the native solver's radius.
    cfg=b; cfg.number_of_steps=2;
    rng(771,'twister'); r1=original_A_adapter('execute',cfg,base);
    differentReference=base; differentReference.reference_LIM=2*base.reference_LIM;
    rng(771,'twister'); r2=original_A_adapter('execute',cfg,differentReference);
    assert(r1.success && r2.success && isfinite(r1.R_hat) && r1.R_hat==r2.R_hat);
    fprintf('PASS: native two-trajectory smoke; analytical reference is not a solver input.\n');
end
if runSmoke
    directory=run_bayes8_accuracy(bayes8_options('selftest'),'');
    D=load(fullfile(directory,'study_finished.mat'));
    assert(D.decision.invalid_runs==0 && D.decision.saved_runs<=57);
    for restart=1:2
        T=readtable(fullfile(directory,sprintf('restart_%02d_trace.csv',restart)), ...
            'TextType','string');
        assert(height(T)==8 && sum(T.phase=="initial_random")==3);
        assert(all(isfinite(T.objective)) && ~any(T.objective_error==1));
        assert(all(bayes8_design('feasible',T,bayes8_options('selftest'))));
        assert(all(T.number_of_steps==round(T.number_of_steps)));
        assert(any(T.Ts~=round(T.Ts)), 'Ts must remain a real-valued coordinate.');
    end
    S=readtable(fullfile(directory,'confirmation_summary.csv'));
    assert(S.paired_seeds==3 && S.synthetic);
    files=dir(fullfile(directory,'records','*.mat'));
    before={files.name}; timestamps=[files.datenum];
    run_bayes8_accuracy(bayes8_options('selftest'),directory);
    files=dir(fullfile(directory,'records','*.mat'));
    assert(isequal(before,{files.name}) && isequal(timestamps,[files.datenum]));
    fprintf('PASS: real bayesopt synthetic pipeline and completed-study resume.\n');
end
end

function restore_session(p,f,r)
cd(f); path(p); rng(r);
end
