# Eight-variable accuracy-only Bayesian search

## Start

In MATLAB:

```matlab
cd('C:\Users\-qian-\Documents\Codex\2026-06-28\github\experiment_B_bayes_8var')
test_bayes8_accuracy
```

The entry starts in `mode='pilot'`. Change it to `'full'` after checking the
pilot. Old six-variable scripts and output folders are not changed or reused.
Statistics and Machine Learning Toolbox is required; parallel mode requires
Parallel Computing Toolbox.

## Only two search coordinates are added

| Variable | Search range | Type |
| --- | --- | --- |
| k=2*qk+1 | 1,3,5,7,9,11 | integer qk=0:5 |
| discr | 351:1051, including even values | integer |
| generations | 2:10 | integer |
| population | 10:20 | integer |
| newcomers | 2:12 | integer |
| selected_opt | 2:5 | integer |
| number_of_steps | 50:200 | integer |
| Ts | 0.025 to 0.10 | continuous real |

The two new ranges match the low/high settings in Experiment A. They are
explicit experimental bounds, not universal or theoretically optimal limits.
Ts is not restricted to the three old sensitivity-test levels and is not
rounded. Cache IDs include its exact IEEE double representation. User-readable
Ts and number_of_steps columns are saved in traces, summaries and raw records.

Newcomer fraction remains in [0.2,0.6]. One best individual and two near-clones
are retained; crossover count is population-newcomers-3 and must be >=1.

## Everything else is retained

- Genda quadratic-damping Duffing:
  `x'' + 0.7*abs(x')*x' - x + x^3 = 0`.
- Target [-1,0], Euclidean weights [1,1], domain x=[-3,3], v=[-2,4].
- Reference LIM approximately 0.728927859156115, obtained by evaluating the
  analytical equations, with the existing two-resolution and integral checks.
- Pure objective: median absolute error over ten common seeds; no time gate,
  weighted score, P95 constraint, historical warm start or prior candidate.
- Two restarts, expected-improvement-plus, 16 random initial evaluations per
  restart included in the total budget; fixed-seed objective marked deterministic.
- tfinal=2000, RelTol=AbsTol=1e-8, recurrence counts, divR and native DynIn rules
  remain fixed. Ts controls the native integration/classification interval,
  not simply the solver's adaptive internal timestep. Changing Ts also changes
  the physical duration corresponding to a fixed repetition count; that count
  is deliberately NOT rescaled because the other controls must remain unchanged.
- The same seed sets and optimizer seeds as the six-variable version are kept.
  Search and confirmation sets do not overlap within this experiment. A seed
  reused across experiments is not a newly unseen seed across all studies.

The comparison baseline is the TRANSFERRED default from the six-variable BO
study: k=3, discr=701, generations=5, population=20, newcomers=8, selected_opt=3,
number_of_steps=100, Ts=0.05. It is NOT the six-benchmark comparison's Genda
configuration (k=11, discr=401, smaller domain and tfinal=1200). This script does
not silently replace the baseline or add a third method. Results must state
which baseline the reported error-reduction factor refers to.

## Budgets

| Mode | Restarts x evaluations | Seeds/config | Confirmation pairs | Maximum saved DynIn runs |
| --- | ---: | ---: | ---: | ---: |
| Pilot | 2 x 32 | 10 | 20 | 690 |
| Full | 2 x 200 | 10 | 100 | 4210 |

Full search seeds: 97101:97110. Full confirmation: 98101:98200.
Pilot search: 95101:95110. Pilot confirmation: 96101:96120.
The actual native solver RNG seed is 100000 + the recorded seed ID.
Counts include ten post-search default runs, exclude worker warm-up, and can be
lower if a configuration is repeated within a restart and its batch is cached.
Increasing the trajectory budget can make an evaluation slower; equal numbers
of evaluations do not imply the same elapsed time as the six-variable study.

The best observed configuration is frozen before independent confirmation.
Default and candidate run in randomized order on the same worker for each seed;
seed scheduling is randomized. All confirmation seeds are used, including large
errors. Execution failures stop scoring rather than being dropped. Runtime,
median/P95 error, within-1%/2% counts, and paired bootstrap bounds are reported.
No tenfold improvement or local/global optimum is guaranteed.

## Parallelism and resume

`options.useParallel=true` preserves parfor over seeds. `numWorkers=[]` requests
all workers allowed by the local Processes profile, one computational thread
per worker. At most ten workers are active in a ten-seed search batch. BO itself
is sequential, so there is no nested parallel pool. Timing reflects this
parallel workload, not isolated serial performance. An incompatible existing
pool is not deleted automatically; close it or select its worker count explicitly.

To resume, set `resumeDirectory` to an output folder from THIS eight-variable
experiment and keep options, MATLAB version, worker setup and source unchanged.
Six-variable output directories cannot be resumed here. Per-seed records,
configuration results, native BO checkpoints and optimizer RNG states are saved.
The native resume call uses only the remaining evaluation budget. Finished
studies are not run again.

## Read the results

- `confirmation_summary.csv`: held-out comparison and bootstrap bounds.
- `paired_confirmation.csv`: default and candidate results for each paired seed.
- `selected_candidate.csv`: all eight winning search coordinates.
- `search_configurations.csv`: all unique configuration batches ranked by error.
- `restart_01_trace.csv`, `restart_02_trace.csv`: every optimizer evaluation.
- `raw_data_all_runs.csv`: per-run results, including actual number_of_steps/Ts.
- `default_configuration.csv`, `model_definition.csv`: comparison definitions.
- `analytical_reference_audit.csv`: reference checks.

Dependencies remain the existing native DynIn, original_A_adapter, six-coordinate
design helper, path activation helper, reference package and generic scoring/
reporting utility in sibling folders. The new worker, batching, objective and
design functions have unique bayes8 names to avoid old-script path collisions.
Source hashes and snapshots are saved in each result folder.

## Verification

`selftest_bayes8_accuracy` runs fast checks before every pilot/full launch:
reference/model, unchanged controls, seven integer coordinates, continuous Ts,
boundary cases, exact cache keys, objective and confirmation calculations.

Optional `selftest_bayes8_accuracy(true,true)` adds a small synthetic bayesopt
pipeline and tiny native solver checks. Synthetic runs are explicitly labelled
and are never scientific results. Neither this command nor the scientific pilot
is needed just to inspect the files. See STATUS.md for actual verification here.
