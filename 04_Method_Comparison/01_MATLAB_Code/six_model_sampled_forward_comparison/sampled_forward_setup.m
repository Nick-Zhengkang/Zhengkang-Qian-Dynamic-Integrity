% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Proposed-method implementation, comparison, or supporting model code.
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
function [root,repo,original,cleanup]=sampled_forward_setup()
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
oldPath=path; oldDir=pwd; oldRng=rng;
cleanup=onCleanup(@() restore(oldPath,oldDir,oldRng));
addpath(root,fullfile(repo,'six_model_dynin_vs_proposed'), ...
    fullfile(repo,'four_model_five_method_suite','functions'), ...
    fullfile(repo,'habib_4d_adaptive_radial'), ...
    fullfile(repo,'separable_4d_analytic_benchmark'), ...
    fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions'), ...
    fullfile(repo,'work','DynIn','DynIn_v1.1.0','VanDerPolDuffing_NLTVA'),'-begin');
original=run_six_model_dynin_vs_proposed("comparison_api");
limbench.verify_freeze();
end
function restore(p,d,r)
path(p); cd(d); rng(r);
end


