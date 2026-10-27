# Frozen adaptive-angle LIM package, v1.0.0

## Start here

Keep `run_frozen_five_method_benchmark.m` next to this `functions` directory.
No changes to either existing DynIn functions directory are required.
No `restoredefaultpath`, global `sistema` replacement, or extra toolbox is used.

```matlab
run_frozen_five_method_benchmark('quadratic_cubic',0.4,'quick')
run_frozen_five_method_benchmark('bistable_duffing',0.7,'full')
run_frozen_five_method_benchmark('quadratic_cubic',0.4,'sensitivity')
```

`quick`: three paired seeds, radial step 0.05.
`full`: ten paired seeds, radial step 0.05.
`sensitivity`: ten paired seeds at both 0.05 and 0.025. The radial step changes
only the proposed policy; baseline repeats are separate timing observations.
Each run has the same upper limits of 4096 classifier queries and 3 seconds.
These are upper limits, not an instruction to spend the entire budget.
The defaults of the frozen engine have not been tuned to a benchmark/reference.

Direct use from a later script:

```matlab
addpath('C:/Users/-qian-/Documents/Codex/2026-06-28/github/functions');
m = limbench.model('quadratic_cubic',0.4);
c = limbench.defaults();
rng(1,'twister');
[result,history,queries] = limbench.proposed(m,c);
```

`result.R`, `result.runtime`, `result.queries`, `result.odeCalls`, `result.rhs`
are the estimate, elapsed seconds, classification calls, ODE trajectories,
and RHS evaluations. A physical shortcut counts as a query but not an ODE.
Models supported here are **two-dimensional autonomous equilibria**, not limit
cycles or higher-dimensional directional searches.

## What is frozen

`proposed_method` is the former `angular_improved` policy in
`genda_quadratic_cubic_angular_efficiency.m`, tested on 2026-09-12, and the
identical search policy in `genda_duffing_angular_efficiency.m`.
The previous coarse-GA polishing method is NOT called by this package.

- 16 initial rays; near-origin linear radial probing, step 0.05 by default.
- Safe/unsafe radial brackets; tolerance 1e-4; no reference-based brackets.
- Round-robin exploration and incumbent-based pruning.
- Four-ray batches: local promising gaps plus global angular coverage.
- Maximum 64 directions; global/local gap targets 2*pi/32 and 2*pi/256.
- Plateau tolerance 2e-5 + 2e-4*current_radius, minimum three rounds,
  patience two, and no unknown-blocked rays for heuristic plateau stopping.
- All three archived regression traces are isolated in test fixtures. They
  and the analytical reference are NEVER loaded by a production search.

Only interfaces changed: classifier callback, externally supplied timer,
returning the solver path, and inclusive timing/bookkeeping. Selection,
brackets, pruning, angular scoring, and stopping branches are unchanged.
Changing the physical classifier would still change query labels; that is
why both extracted model classifiers retain the previous events/tolerances.

## Important identity distinction

This is a **common-direct-classifier controlled comparison**, NOT an unchanged
reproduction of the original paper or the old five-method results.

| Run label | Actual meaning in this package |
|---|---|
| coarse_GA | DynIn maximin GA helper, 10 generations per selected point |
| fine_GA | Same helper, 40 generations per selected point |
| dynin_original_bisection | DynIn type_x0=2 selection branches, common classifier |
| proposed_method | Frozen adaptive-angle v1.0.0 |
| energy_informed | Energy + IDW uncertainty + shell candidate score, then refinement |

Previously coarse/fine GA mainly differed in **classification-grid resolution**.
That distinction cannot simultaneously be kept and eliminated by using one
identical, grid-free direct classifier. Here low/high **GA search effort** is
the explicit distinction. Do not label these results as the previous coarse/
fine grid baselines. Their GA budgets are transparent comparison settings,
not claimed to be optimal or paper parameters. Population settings are the
same: crossover=9, selected=3, newcomers=8, almost-clones=2, divR=40.

The original GA helper files are copied verbatim modulo line endings, including
the `points(1,:)` return convention. This package does not silently fix or
reinterpret that helper. Reproduction of the original grid-based procedure
must remain a separate experiment using the old scripts.

DynIn adaptation preserves safe/divergent branch order, closest-trajectory-point
restart, midpoint updates, 1.1R random-border restart, domain fallback, and
the original <= / > tests with bisIterMax=5. Differences are documented:
the grid classifier is replaced; unknown is not forced to divergent; the
initial domain radius is not reported as a measured LIM before finding an
unsafe point; common caps replace a fixed number-of-steps stopping rule.
The rectangular search domain is target +/- maxRadius/sqrt(weight), giving
initial R=2.5 for both models; it is a search bound, not an escape condition.

Energy-informed retains the previous 0.45 energy / 0.35 IDW uncertainty /
0.20 shell score, 24 initial queries, 50 active queries, pool=4000, and eight
final bisections. Unknown samples are excluded from IDW training. Refinement
starts at the known target (radius zero), instead of assuming a small offset
safe. Pool candidates, score, and local refinement use no reference LIM.
This is not Gaussian-process Bayesian optimization.

## Shared classifier and estimator evidence

All methods call `limbench.classify` with identical tolerances, energy margin,
stage times [100,400,1200], MaxStep=0.25, and the same path-return work.
Label 1 = target, 2 = non-target, 0 = unresolved. Unexpected solver exceptions
are recorded as failed runs, not silently converted into successful estimates.

For quadratic-cubic: E=v^2/2+x^2/2-x^3/3; E<1/6 in x<1 certifies trapping;
x>=1 and v>=0 certifies non-return. Exterior inward states are not automatically
unsafe. For quadratic-drag bistable Duffing: E=v^2/2-x^2/2+x^4/4; E<0 traps
the trajectory in its current well. Merely crossing x=0 is not a basin label.

Both use unit weights, target (0,0) or (-1,0). The linear-damped paper Duffing
reference 0.7683 and weights [4,1] are NOT used here.

GA, DynIn bisection, and energy-informed can update from the closest recorded
point on a classified non-target trajectory, as in the original DynIn logic.
The frozen angular method updates from the radius of its classified initial
point. This policy difference is intentional. Recorded solver trajectories
are truncated at the common classification event, not continued just for a
particular method. No grid interpolation or reverse-time integration is used.
Numerical path minima are sample-based, not exact continuous-time minima.

## Timing and scoring

Timers start at the same `limbench.run` boundary. They include candidate pool
generation, GA generations, adaptive decisions, classification, path collection,
and per-run result bookkeeping. They exclude model/reference setup, MATLAB
path setup, warm-up runs, CSV/MAT writes, plotting, and post-hoc statistics.
The old `OutL.total_time` is never substituted for elapsed wall time.

An ODE or candidate-generation operation may overshoot the 3-second horizon;
such cost remains in full runtime, while results first available after the
horizon do NOT count toward time-to-accuracy. No new baseline query is started
after the timer has expired. The frozen angular loop keeps its original
budget-check position. Early-stopped estimates are held to the horizon.

Primary comparison: **success probability and time to sustained relative
accuracy**, at 0.5%, 0.2%, and 0.1%. Sustained means all later observed outputs
within the horizon meet the tolerance; it is a retrospective evaluation, not
an online guarantee. Report success fraction beside successful-run mean time.
A failure has NaN success time and the full horizon in capped mean time.
The retained 0-100 score in per-run hit logs is secondary, not a certificate.

Reference values evaluate Genda V2 analytical equations, with scalar root and
integral cross-checks; evaluation cost is saved separately in reference_audit.
The available implementation supports alpha in [0.1,0.95] for quadratic-cubic
and [0.1,1] for bistable Duffing. No reference is accepted by run/proposed.
These are numerical evaluations of analytical formulas, not arbitrary-precision
certified bounds. Radius/angle sampling can miss thin unsafe intervals; neither
heuristic plateau stopping nor a small error makes the returned ball certified.

## Tests and provenance

```matlab
addpath('functions');
limbench.selftest();        % old/new synthetic regression + archived replay
limbench.selftest('ode');   % additionally run actual ODE checks
```

`FREEZE_MANIFEST.json` records source/package SHA-256 hashes. The runner checks
package hashes before starting, using MATLAB's standard bundled JVM. Do not
edit versioned functions in place; configuration overrides belong in the
calling script. Copy files byte-for-byte, since hashes include line endings.
The original
scripts and original DynIn directories are not modified. `frozen_search_v1.m`
is an independent pre-extraction policy snapshot, used only by selftest.

Static MATLAB analysis completed with no syntax errors. An independent offline
source audit confirmed unchanged selection/stopping/defaults/classifier math,
and replayed three archived physical query traces (635, 1192, and 716 queries),
matching all candidate points, final radii, and 44-direction plateau stops.
This replay tests scheduling against recorded labels, NOT new ODE accuracy or
the runtime performance of the four newly integrated baseline adapters.
In this Codex
environment MATLAB's batch launcher fails at startup with `File system
inconsistency`, before executing any test. Therefore actual MATLAB selftests
and full five-method runtime results still require execution in the user's
working MATLAB session. Do not claim the new baselines outperform one another
until those experiments have run.

DynIn-derived helpers and bisection branches originate from Giuseppe Habib's
DynIn v1.1.0, `work/DynIn/DynIn_v1.1.0/functions`. See `DynIn_LICENSE.txt`
(GNU GPL v3). Preserve the license and attribution when distributing the
derived package. Changed adapter files are identified above; the original
authors did not produce or validate this benchmark integration.
