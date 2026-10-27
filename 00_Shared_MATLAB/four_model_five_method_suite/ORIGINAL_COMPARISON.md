# Original full methods versus frozen adaptive-angle proposed

This is the primary comparison requested by the user. It supersedes the
common-classifier experiment for the question of overall algorithm performance.
The previous 10-versus-40-generation GA adaptation is NOT called here.

## Run

```matlab
run_original_five_method_benchmark('quadratic_cubic',0.4,1:3)
run_original_five_method_benchmark('bistable_duffing',0.7,1:10)
```

An alpha vector can be supplied, for example `[0.2 0.4 0.7]`. The frozen
reference helpers currently support quadratic-cubic alpha in [0.1,0.95] and
bistable Duffing alpha in [0.1,1]. Defaults are quadratic-cubic, alpha=0.4,
three seeds. Both benchmarks have quadratic drag and unit distance weights.
The frozen proposed has not yet been connected to the linear-damped paper
Duffing or cosine model; this runner rejects those names instead of silently
using a different classifier or an incompatible reference.

Keep the runner alongside `functions/+limbench`. It also requires the existing
DynIn installation specified by `originalFunctionsDir` near the top of the
runner. Nothing in that installation is rewritten. The old benchmark script
on the Desktop is likewise unchanged.

## Precisely what changes

Starting point: the existing Desktop script `genda_five_method_four_benchmark.m`.

1. Coarse GA: original compute_LIM_FP, type_x0=1, grid discr=169,
   equilibrium-cell setting=15. Original classification and GA helpers retained.
2. Fine GA: same original implementation, discr=673, equilibrium-cell
   setting=60 (interpreted by the original function). Both GA baselines retain
   num_gen=10 and number_of_steps=100. Fine does NOT mean 40 generations.
3. DynIn original bisection: original compute_LIM_FP, type_x0=2, with exactly
   the existing model-specific parameter helper. For these two models:
   discr=401, equilibrium-cell setting=12, steps=120, tfinal=1200, Ts=0.05,
   bis_iter_max=8, RelTol=1e-8, AbsTol=1e-9. Domains are respectively
   [-1,-1,1,1] and [-2,-2,1,2]. The original code interprets these settings;
   no new midpoint, unknown-label, grid-classification or stopping logic is
   inserted into that code.
4. Proposed: replace ONLY the old coarse-plus-polish block with a standalone
   call to `limbench.proposed`. It has its own paired random seed, frozen
   settings, native classifier and native stopping rule. It does not read
   coarse/fine/DynIn/energy results or the reference, and is not skipped if
   coarse GA fails. Neither coarse runtime nor coarse queries are added to it.
5. Energy-informed: retain the old energy_informed_search and all its
   classification/scoring helpers and parameters. No common-oracle adapter
   from the previous controlled-comparison package is called.

The existing originalFunctionsDir contains a version with optional adaptive
experiments. As in the previous benchmark, use_adaptive_grid,
use_adaptive_refinement and use_boundary_bisection are explicitly zero for
the original baselines. This preserves the existing legacy execution path;
it is not a new verification that every installed file is identical to the
historically published distribution. The runner checks the resolved function
and model paths, and saves SHA-256 hashes of all installed .m files for audit.

## Timing and interpretation

Each complete method is measured by an outer timer around its call. All
internal initialization, classification and search work is included. Reference
evaluation, parameter/source audits, output files and plotting are excluded.
The original OutL.total_time no longer overrides this consistent measurement;
the original algorithm itself is not edited. There is no common time/query
cap imposed on the original baselines. Proposed retains its frozen 3-second /
4096-query upper limits and heuristic early stopping. These different native
budgets and stopping rules are part of the full-method comparison.

The raw CSV keeps the old schema and adds comparison_profile, classifier,
proposed_version and timing_rule. Grid and generation fields are NaN for
proposed: it has no classification grid or GA. Proposed's number_of_steps
column records its query upper limit, not its actual calls; use
trajectory_evaluations for actual calls. Detailed proposed query/history
files record RHS and actual ODE counts. The original interfaces do not expose
equivalent RHS counts, so the runner does not invent them.

Different classifiers are intentional here. Consequently any performance
difference reflects the COMPLETE implementations, not only angular sampling.
In particular, the retained old energy classifier has heuristic side-crossing
and terminal-state rules, whereas the frozen proposed uses energy trapping
and invariant-region tests. The original grid classifier has its own finite
domain and grid-label approximations. Inspect errors and failures against the
same analytical reference; do not claim identical classification decisions.
An apparent speed advantage without adequate accuracy is not an improvement.

Reference formulas are taken from the verified frozen Genda helpers and are
evaluated outside method timers. Per-alpha reference_audit CSVs and full
baseline argument MAT files are saved. `success` is finite-result status,
not a guarantee of meeting an accuracy threshold or mathematical safety.

## Verification status

Static MATLAB analysis: no syntax errors (legacy style/unused-helper warnings
remain). Source audit: the GA/bisection calls, baseline parameter helper and
energy implementation are preserved; only outer timing and finite-result
reporting changed for the original baseline blocks. Frozen package hashes
and previous archived-query regressions remain intact.

MATLAB batch startup in this environment fails before executing scripts with
`File system inconsistency`. This new complete-method comparison has NOT yet
been executed end to end. Run the three-seed example in the working MATLAB
session before relying on its results.
