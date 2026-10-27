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
function [base,reference,audit]=bayes8_problem(o)
% Transfer algorithm controls only; replace the physical model and metric.
assert(strcmp(o.modelId,'genda_bistable_duffing'));
validateattributes(o.alpha,{'numeric'},{'scalar','real','finite','>=',.1,'<=',1});
base=original_A_adapter('base');
base.model="Genda bistable Duffing with quadratic damping";
base.par=struct('alpha',o.alpha);
base.xe=[-1 0]; base.weight=[1 1];
% Keep the transferred computational domain fixed for both groups.
base.spaceboundary=[-3 -2 3 4];
[reference,audit]=limbench.reference('bistable_duffing',o.alpha);
reference.kind='analytical_equations_evaluated_numerically';
reference.published_source='https://doi.org/10.1007/s11071-026-12948-0';
reference.published_equations='83-87, 94-96';
base.reference_LIM=reference.R;
assert(isfinite(reference.R) && reference.R>0 && reference.R<1);
assert(reference.resolutionDifference<1e-8);
% Independent 60-digit evaluation of the same formulas at the fixed benchmark.
if o.alpha==.7
    assert(abs(reference.R-.72892785915611505908)<1e-10, ...
        'Genda analytical reference does not match its independent check.');
end
assert(~isfield(base.par,'zeta') && isequal(base.weight,[1 1]));
end
