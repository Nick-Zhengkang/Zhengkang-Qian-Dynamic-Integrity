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
function selftest_multi_alpha_bayes()
% No DynIn searches, pool creation or Bayesian evaluations are performed here.
selftest_ma_report;
o=ma_options('full'); b=ma_design('baseline');
assert(strcmp(o.model,'quadratic_cubic'));
assert(isequal(o.trainAlpha,(1:20)/10) && isequal(o.validationAlpha,(1:2:39)/20));
assert(isempty(intersect(o.trainSeeds,o.validationSeeds)));
assert(numel(o.trainSeeds)==10 && numel(o.validationSeeds)==100);
assert(ma_design('feasible',b,o));
assert(~ma_design('feasible',[b(1:4) 19 b(6:8)],o));
assert(~ma_design('feasible',[b(1:6) 100.5 b(8)],o));
assert(~strcmp(ma_design('key',b),ma_design('key',[b(1:7) b(8)+eps(b(8))])));
cfg=ma_design('config',b,o.model);
assert(cfg.num_of_cell_around_equilibrium==3 && cfg.num_crossover==9 ...
    && cfg.tfinal==2000 && cfg.type_x0==1 && isequal(cfg.weight,[1 1]));
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
native=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
source=fileread(fullfile(native,'compute_LIM_FP.m'));
found=regexp(source,'addOptional\(p,''([^'']+)''','tokens');
assert(isequal(string(cellfun(@(x) x{1},found,'UniformOutput',false)),string(ma_design('order'))));
% Compare the new evaluator with the previously audited finite-turn routines.
oldPath=path; cleanup=onCleanup(@() path(oldPath));
addpath(fullfile(repo,'four_model_five_method_suite','functions'),'-begin');
for a=[.1 .3 .7 .95]
    [old,~]=limbench.reference('quadratic_cubic',a);
    R=ma_reference('quadratic_cubic',a); assert(abs(R-old.R)<1e-8);
end
assert(abs(ma_reference('quadratic_cubic',1)-sqrt(.5))<1e-10);
for model={'quadratic_cubic','bistable_duffing'}
    for a=[.05 .1 .27944 .6878800931 1 sqrt(3/2) 1.5 2]
        [R,A]=ma_reference(model{1},a);
        assert(isfinite(R) && R>0 && R<=1 && max(A.integral_crosscheck_residual)<1e-8);
    end
end
assert(abs(ma_reference('bistable_duffing',.7)-.72892785915611505908)<1e-10);
fprintf('PASS: alpha/seed split, eight-variable mapping, analytical branches and error summaries.\n');
end
