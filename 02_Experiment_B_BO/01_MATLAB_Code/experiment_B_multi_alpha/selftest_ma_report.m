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
function selftest_ma_report()
% Fast regression check: no reference evaluation, solver, optimizer or pool.
alpha=repelem([.05;.15],10); seed=repmat((1:10)',2,1); e=(1:20)'/1000;
T=table([alpha;alpha],[seed;seed],[repmat("baseline",20,1);repmat("candidate",20,1)], ...
    true(40,1),ones(40,1),1+[e;e/2],[e;e/2],100*[e;e/2],ones(40,1),2*ones(40,1), ...
    'VariableNames',{'alpha','seed','role','success','reference_LIM','R_hat','absolute_error', ...
    'relative_error_percent','core_wall_time_s','core_cpu_time_s'});
[C,P]=ma_report('compare',T); S=ma_report('profile',T);
assert(height(C)==3 && isnan(C.alpha(1)) && isequal(C.alpha(2:end),[.05;.15]));
assert(height(P)==20 && height(S)==4 && all(S.n==10));
assert(all(abs(C.improvement_factor-2)<1e-12));
assert(all(abs(C.reduction_percent-50)<1e-10));
assert(all(C.complete) && all(C.candidate_has_lower_median));
% A single-alpha comparison still includes a pooled and a per-alpha row.
C1=ma_report('compare',T(T.alpha==.05,:));
assert(height(C1)==2 && all(abs(C1.improvement_factor-2)<1e-12));
% Training objective reports only one role, across multiple alphas.
S1=ma_report('profile',T(T.role=="candidate",:));
assert(height(S1)==2 && all(S1.role=="candidate"));
% A failure invalidates its profile and pooled score, not the other alpha.
T.success(21)=false; T.absolute_error(21)=NaN;
C=ma_report('compare',T); S=ma_report('profile',T);
assert(~C.complete(1) && isnan(C.candidate_median_absolute_error(1)));
assert(~C.complete(2) && C.complete(3));
assert(sum(~S.complete)==1 && sum(S.n_success)==39);
assert(isnan(C.improvement_factor(1)) && ~C.candidate_has_lower_median(1));
fprintf('PASS: report aggregation, pooled/per-alpha comparisons and failure retention.\n');
end
