# Experiment A: Genda Duffing single-factor sensitivity

This is a NEW study. Old Experiment A outputs and the thesis are not modified.
The purpose is to rerun the sensitivity study on the same model and transferred
baseline used by the eight-variable Experiment B, not to evaluate the BO winner.

## Run in MATLAB

```matlab
cd('C:\Users\-qian-\Documents\Codex\2026-06-28\github\experiment_A_genda_sensitivity')
open test_genda_sensitivity
test_genda_sensitivity
```

In `test_genda_sensitivity.m`, select `genda_A_options('pilot')` or
`genda_A_options('full')`. Parallel execution is enabled by default. An empty
`numWorkers` requests every worker allowed by the local Processes profile.
This uses process workers, one computation thread each; it is not a claim
that every logical CPU on every machine is enabled in that profile. An existing
incompatible pool causes a clear error; the script does not delete another pool.
The core algorithm and analytical reference do not require the BO toolbox.
Parallel execution requires Parallel Computing Toolbox. Set `useParallel=false`
explicitly for serial execution; do not combine timings from different modes.

| Mode | Configurations | Common seeds | Native runs | Fixed diagnostic points |
|---|---:|---:|---:|---:|
| smoke | 3 | 1 | 3 | 4 |
| pilot | 29 | 2 | 58 | 24 |
| full | 29 | 30 | 870 | 72 |

Warm-up runs and independent reference-label integrations are additional and
are not included in these native-run counts. Pilot is an execution check, not
evidence for a stable sensitivity ranking. Full seeds are 99101--99130, separate
from the latest BO search and confirmation; the solver uses RNG 100000 + seed.
Pilot/full results go in different folders and are never pooled.

The 30-seed revision starts a fresh full study. Keep `resumeDirectory=''` for
the first run; do not resume or copy records from an old 10-seed output folder.
The existing options/source-signature checks reject incompatible resumes.
Old outputs and their archived source snapshots remain unchanged.

## Fixed physical problem and baseline

- Equation: x'' + 0.7 |x'| x' - x + x^3 = 0.
- Target (-1,0), Euclidean weights (1,1), domain x in [-3,3], v in [-2,4].
- Reference LIM: approximately 0.728927859156115, recomputed from the existing
  Genda analytical-boundary/tangency implementation, with its root-refinement
  and integral cross-check audit saved. It is NOT Habib's published 0.7683.
- The reference is an analytical-equation value evaluated numerically, not an
  exact decimal constant and not a forward-trajectory estimate.
- Base: discr=701, k=3, tfinal=2000, Ts=.05, RelTol=AbsTol=1e-8,
  steps=100, rep_fix_point=40, rep_periodic=10, divR=40, generations=5,
  population=20, selected_opt=3, newcomers=8, near-clones=2, crossover=9.
- Other original A controls remain fixed, including type_x0=1. Native DynIn
  source files are unchanged. No BO-tuned settings are substituted into A.
- The reference enters post-run error reporting and the auxiliary diagnostic
  point locations, not the main solver's point selection or stopping rules.

## Preserved single-factor design

| Factor | Low | Baseline | High |
|---|---:|---:|---:|
| Grid resolution discr | 351 | 701 | 1051 |
| Target neighbourhood k | 1 | 3 | 7 |
| tfinal | 1000 | 2000 | 4000 |
| Ts | .025 | .05 | .1 |
| RelTol / AbsTol | 1e-6 / 1e-8 | 1e-8 / 1e-8 | 1e-10 / 1e-10 |
| number_of_steps | 50 | 100 | 200 |
| rep_fix_point | 20 | 40 | 80 |
| rep_periodic | 5 | 10 | 20 |
| divR | 20 | 40 | 80 |
| GA generations | 2 | 5 | 10 |
| Population | 10 | 20 | 40 |
| Newcomer fraction | .2 | .4 | .6 |
| Near-clones | 0 | 2 | 4 |
| selected_opt | 2 | 3 | 5 |

There are 14 factors, but only 29 unique configurations: one shared baseline
plus two non-baseline settings per factor. The baseline is run once per seed;
its repeated appearance in the factor-wise table is NOT extra independent data.

The old A's population composition is preserved: crossover/newcomers/clones
are 4/4/1 at p=10, 9/8/2 at p=20, and 18/17/4 at p=40, plus one best individual.
Thus population is a composition-preserving approximately scaled group, not
an isolated change with all component counts fixed (the high newcomer ratio is
17/40=.425). Varying newcomers or clones at fixed p changes crossover to balance
the population. ODE tolerance is also a grouped RelTol/AbsTol setting. These
qualifications must remain in the later thesis description. The A ranges are
preserved, not silently restricted to B's optimization bounds.

## Diagnostic meaning

Fixed points lie at .85, 1.0 and 1.15 times the analytical reference radius.
Their independent reference labels use the NEW quadratic-damping equation,
strict ODE tolerances, and entry into radius .002 of (-1,0) or (1,0), up to
T=4000. No learned labels or energy shortcut is used in reference labelling.
Crossing the DynIn domain does not itself give a non-target reference label.
Unresolved points remain unknown and are counted, not assigned to an attractor.
These are numerical diagnostic labels, not analytical basin-membership proofs.

After each native run the original A diagnostic readout reconstructs known cells
from stored trajectories, removes conflicting cells from that readout, and checks
each reference point. Unknown cells trigger forward integration with that
configuration's settings. This readout is NOT a full replay of the native
recurrence classifier; its conflict filtering does not alter the main algorithm.
Diagnostics do not tune the settings or feed labels back into the native run.

## Timing, persistence and outputs

The configuration/seed job order is reproducibly randomized. Each configuration
at a seed starts with the same RNG state, but different settings can consume
different numbers of random draws. Runs are paired by seed, not necessarily
adjacent in time. Interpret timing under parallel CPU contention as descriptive.

`core_wall_time_s` encloses the native DynIn call only; `diagnostic_runtime_s`
is separate. Independent diagnostic-label construction, worker warm-up, scheduling
and writing are excluded. Do not compare these timings directly with old runs
on a different execution setup.

Each finished job saves `records/*.mat` atomically, then the client exports CSVs
after each small batch. Ctrl+C can discard currently unfinished jobs, but finished
records remain. To export after stopping:

```matlab
addpath('C:\Users\-qian-\Documents\Codex\2026-06-28\github\experiment_A_genda_sensitivity')
genda_A_export('C:\path\to\outputs_genda_A_pilot_...');
```

To resume, set the same mode/options and paste that folder into
`resumeDirectory`. Numerical-source SHA256 signatures, MATLAB version, options,
host and worker settings are checked. Start a new output folder if they change.
Saved failed jobs remain explicitly failed, rather than being rerun until they
succeed; failed/incomplete configurations are not assigned sensitivity scores.

Main outputs:
- `raw_data_all_runs.csv`: one row per genuinely executed configuration/seed.
- `experiment_A_design.csv`: every effective parameter and GA composition.
- `summary_by_parameter_and_level.csv`: median, P95, Q1/Q3 errors, cost, diagnostics.
- `sensitivity_ranking.csv`: range of median errors (percentage points) and ratio
  of largest/smallest median runtimes across each factor's three levels.
- `paired_changes_vs_baseline.csv`: same-seed error differences and time ratios.
- `analysis_long_with_reused_baseline.csv`: source data for later Python box plots.
- `fixed_diagnostic_set.csv`, `analytical_reference_audit.csv`: reference checks.
- `study_definition.mat`, `execution_schedule.csv`, `source_snapshot/`: provenance.

Percentiles use MATLAB `prctile` (midpoint plotting positions and endpoint
clamping). P95 is descriptive and particularly unstable for small samples;
with ten seeds it is the sample maximum under this convention; with thirty seeds
it is the second-largest observation. Do not interpret
it as a 95% confidence bound. A ranking is specific to this model, baseline,
tested levels and seeds; it does not demonstrate global sensitivity or optimality.

Optional `saveTrajectories=true` retains OutL and OutH in each per-run MAT file
for later path inspection, at increased storage cost. Existing shared dependencies
in this repository must remain available; this folder is not a standalone DynIn distribution.
