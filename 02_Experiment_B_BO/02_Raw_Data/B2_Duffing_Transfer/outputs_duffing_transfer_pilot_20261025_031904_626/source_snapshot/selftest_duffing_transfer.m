function selftest_duffing_transfer
% Fast preflight only: does not run DynIn or open a parallel pool.
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
source=fullfile(repo,'experiment_B_multi_alpha','outputs_multi_alpha_full_20261023_055518_403');
oldPath=path; cleanup=onCleanup(@() path(oldPath));
addpath(fullfile(source,'source_snapshot'),'-begin');
addpath(root,'-begin');
frozen=load(fullfile(source,'frozen_candidate.mat'));
assert(frozen.selectedBeforeValidation && isequal(size(frozen.winner),[1 8]));
cfg=ma_design('config',frozen.winner,'bistable_duffing');
assert(cfg.num_of_cell_around_equilibrium==11 && cfg.discr==1012);
assert(cfg.num_crossover==5 && cfg.newcomers==12 && cfg.number_of_steps==171);
assert(abs(cfg.Ts-.0920905251923764)<1e-15);
for alpha=[.05 .65 .6878800931 .7 .805 .82 sqrt(3/2) 1.25 2]
    [R,A]=duffing_transfer_reference(alpha);
    assert(R>0 && R<1 && all(A.integral_crosscheck_residual<1e-8));
    finite=isfinite(A.turning_residual);
    assert(all(A.turning_residual(finite)<1e-10) && all(A.turning_bracket_width(finite)<1e-12));
    assert(all(A.minimum_raw_candidate_p>=-1e-10));
    if alpha==.7, assert(abs(R-.7289278591561151)<1e-9); end
end
assert(numel((1:40)/20)*10*2==800 && numel((1:40)/20)*100*2==8000);
fprintf('PASS: frozen candidate, parameter mapping, analytical envelope and budgets.\n');
end
