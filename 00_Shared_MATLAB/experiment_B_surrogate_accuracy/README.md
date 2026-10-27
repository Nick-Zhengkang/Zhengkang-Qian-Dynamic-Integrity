# Accuracy-only surrogateopt experiment

## Run

In MATLAB R2025b, with Global Optimization Toolbox and Parallel Computing Toolbox:

```matlab
cd('C:\Users\-qian-\Documents\Codex\2026-06-28\github\experiment_B_surrogate_accuracy')
test_surrogate_accuracy
```

The entry script defaults to `pilot`. Change `mode` to `full` only after inspecting
the pilot. No full experiment is started automatically.

| Setting | Pilot | Full |
|---|---:|---:|
| Independent surrogateopt restarts | 2 | 2 |
| Maximum evaluations per restart | 24 | 120 |
| Common search seeds per configuration | 6 | 30 |
| Fresh paired confirmation seeds | 20 | 100 |
| Maximum saved DynIn runs, excluding warm-up | 334 | 7430 |

The native solver generates its own initial points. `InitialPoints` is empty.
`MinSurrogatePoints=14` controls construction of the surrogate, including after
internal resets; it does not guarantee an exact number of adaptive points.
`optimizer_trace.csv` records `random` versus `adaptive` evaluations.
Neither baseline, Experiment A configurations nor old candidates are supplied
to the optimizer. No historical output files are loaded.

## Objective and space

Minimize `median(abs(R_hat - 0.7683))` over the common search seeds.
The reference is Habib's published numerical value, not an exact analytical LIM.
Small reference mismatch does not certify correct trajectory classification.

Coordinates are `[qk, discr, generations, population, newcomers, selected]`.
Bounds are `[0 351 2 10 2 2]` to `[5 1051 10 20 12 5]`, all integer-valued.
`k=2*qk+1`. `discr` can be even or odd. Other original DynIn controls remain
unchanged. Linear constraints enforce newcomer fraction 0.2--0.6, two
near-clones, one elite, at least one crossover individual, and selected <= population.
These bounds intentionally match the last six-variable experiment, not all
fourteen controls or every level explored in Experiment A.

There is no runtime constraint, P95 constraint, weighted score, Bayesian stage,
or added integer-neighbourhood search. Ranking uses median absolute error only;
exact ties use configuration ID, not time. The returned configuration is the
best observed within this budget, not a proven global or local optimum.

## Parallel execution and timing

`parfor` runs the seeds of a configuration on local process workers.
The outer surrogateopt uses `UseParallel=false` to avoid nested parallelism.
By default all workers allowed by the local Processes profile are opened, with
one computational thread per worker. Actual concurrency is limited by the
number of seeds: the default pilot has at most six simultaneous search runs.
This does not guarantee occupation of every logical hardware core. Increase
the pilot seed count explicitly if more concurrency is required; this increases
the statistical and computational budget. An incompatible existing pool is not
deleted automatically.

Every worker performs an untimed two-trajectory warm-up using the baseline.
Those results never enter the optimizer. After both searches, the selected
configuration is frozen. Only then is the baseline measured on search seeds
for comparison. Baseline and candidate subsequently run as same-worker pairs
on fresh confirmation seeds, with randomized pair order and seed order.
Times describe this loaded parallel environment, not isolated serial speed.
Time cannot disqualify a configuration or change its objective.

## Output

- `optimizer_trace.csv`: solver evaluation count, random/adaptive origin and incumbent error.
- `search_configurations.csv`: all completed configuration batches ranked by error.
- `selected_candidate.csv`: frozen best searched configuration.
- `search_baseline_comparison.csv`: common-seed comparison against baseline.
- `confirmation_summary.csv`: independent error statistics, reduction factor,
  descriptive time ratio, and paired percentile-bootstrap upper bounds.
- `raw_data_all_runs.csv`: per-seed estimates, errors, timings and status.
- `study_decision.csv`: completion status; pilot remains preliminary.
- Native per-restart checkpoints, seed-level MAT records and source snapshots.

The bootstrap uses 5000 paired resamples of fresh seed pairs. It estimates
uncertainty in the difference of the two medians; it does not prove optimality
or guaranteed performance for future seeds.

## Interrupt / resume

Use Ctrl+C in MATLAB. Set `resumeDirectory` in the entry script to the absolute
output directory, keeping the original options unchanged, and run it again.
The official surrogateopt checkpoint is resumed. Saved seed records allow
interrupted batches to continue; an interrupted confirmation pair is rerun
in full. Never edit native checkpoint contents.

Repeated configurations within the same restart reuse their fixed-seed
objective, including checkpoint replay. Different restarts keep separate
records. Thus actual saved run counts can be lower than the upper budgets.
All scientific source hashes, MATLAB version and execution settings must
match for resume. Do not move a pending study to a different folder.

Failed runs are saved and stop the experiment; they are not dropped or replaced
with an invented favourable score. Inspect `last_failure.mat` and raw records.
If a numerical failure requires code or parameter changes, start a new study.
Exported CSVs reflect the last completed batch, or the caught error; seed MAT
files may contain newer results after a manual interrupt.

## Tests

`selftest_surrogate_accuracy` checks pure scoring and constraint contracts.
`selftest_surrogate_accuracy(true)` additionally runs the actual surrogateopt
solver with synthetic observations (no expensive DynIn runs) and tests a
completed-study resume. Synthetic folders are explicitly marked.

Reused helpers are only the original DynIn adapter, common encoding, and
previously verified worker/path setup. No historical objective or selection
logic is reused. Old experiments and original DynIn sources remain untouched.

MATLAB references:
[surrogateopt](https://www.mathworks.com/help/gads/surrogateopt.html),
[options](https://www.mathworks.com/help/gads/surrogate-optimization-options.html),
[checkpoint files](https://www.mathworks.com/help/gads/work-with-checkpoint-files.html).
