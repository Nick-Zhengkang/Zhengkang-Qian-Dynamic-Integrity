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
function [C,P]=bayes8_confirmation(B,Q,o)
% All metrics use the frozen candidate and the independent paired seed set.
C=surrogate_accuracy_util('confirmation',B,Q,o);
assert(isequal([B.seed],[Q.seed]));
assert(all([B.reference_LIM]==B(1).reference_LIM) && ...
    all([Q.reference_LIM]==B(1).reference_LIM));
ref=B(1).reference_LIM;
C.reference_LIM=ref;
C.reference_kind="analytical_equations_evaluated_numerically";
C.baseline_median_R_hat=median([B.R_hat]);
C.candidate_median_R_hat=median([Q.R_hat]);
C.bootstrap_supports_tenfold_improvement= ...
    C.baseline_median_absolute_error>0 && C.tenfold_difference_upper95<0;
C.baseline_median_relative_error_percent=100*C.baseline_median_absolute_error/ref;
C.candidate_median_relative_error_percent=100*C.candidate_median_absolute_error/ref;
C.baseline_p95_relative_error_percent=100*C.baseline_p95_absolute_error/ref;
C.candidate_p95_relative_error_percent=100*C.candidate_p95_absolute_error/ref;
C.baseline_within_1_percent=sum([B.relative_error_percent]<=1);
C.candidate_within_1_percent=sum([Q.relative_error_percent]<=1);
C.baseline_within_2_percent=sum([B.relative_error_percent]<=2);
C.candidate_within_2_percent=sum([Q.relative_error_percent]<=2);
C.error_reduction_percent=NaN;
if C.baseline_median_absolute_error>0
    C.error_reduction_percent=100*(1-C.candidate_median_absolute_error/C.baseline_median_absolute_error);
end
C.time_increase_percent=100*(C.descriptive_time_ratio-1);
P=table([B.seed].',[B.R_hat].',[Q.R_hat].',[B.absolute_error].', ...
    [Q.absolute_error].',[B.core_wall_time_s].',[Q.core_wall_time_s].', ...
    [B.worker_task_id].',[Q.worker_task_id].',[B.execution_order].', ...
    'VariableNames',{'seed','default_R_hat','optimized_R_hat','default_absolute_error', ...
    'optimized_absolute_error','default_core_time_s','optimized_core_time_s', ...
    'default_worker_id','optimized_worker_id','default_execution_order'});
assert(all(P.default_worker_id==P.optimized_worker_id), ...
    'Confirmation pair did not stay on the same worker.');
P.error_difference=P.optimized_absolute_error-P.default_absolute_error;
end
