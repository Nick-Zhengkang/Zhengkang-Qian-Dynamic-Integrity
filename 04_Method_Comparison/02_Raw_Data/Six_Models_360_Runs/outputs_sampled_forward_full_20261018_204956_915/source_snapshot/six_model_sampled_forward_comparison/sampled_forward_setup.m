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


