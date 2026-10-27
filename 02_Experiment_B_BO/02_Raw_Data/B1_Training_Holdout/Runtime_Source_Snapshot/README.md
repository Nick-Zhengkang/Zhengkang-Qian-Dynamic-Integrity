# Experiment B: multi-alpha accuracy-only Bayesian optimization

## Run

Open `test_multi_alpha_bayes.m` in MATLAB and run it. The default is `pilot`.
Change `ma_options('pilot')` to `ma_options('full')` for the full study.
The entry script first runs unit/reference checks without a DynIn search.
Requires MATLAB, Statistics and Machine Learning Toolbox, and (by default)
Parallel Computing Toolbox. Existing experiments and their results are not edited.

## Physical model and analytical reference

The requested model is the **quadratic-cubic potential**, NOT bistable Duffing:

    x'' + alpha*abs(x')*x' + x - x^2 = 0
    V(x) = x^2/2 - x^3/3

Target (0,0), saddle (1,0), Euclidean distance. Both profiles use the previous
transferred computational domain x in [-3,3], velocity in [-2,4].
The reference follows the supplied Genda et al. V2 PDF, Sections 3.5-3.6,
Eqs.52,54,59-61. It is the smaller admissible endpoint/tangency radius when
0 < alpha < 1; for alpha >= 1 the finite left endpoint is absent.
The evaluator searches all stationary candidates and admissible endpoints,
checks two scan resolutions, and cross-checks the analytical expression with
independent quadrature of its integrating-factor formula. This is numerical
evaluation of analytical equations, not a reference trajectory simulation.

Because the saddle itself has distance 1, points with x < -1 cannot produce
a smaller radius. This justifies a finite reference-search window even when
the left separatrix has no turning point. Small-alpha cancellation is avoided
using a convergent power series. Self-tests check alpha=1, the old validated
range, and both sides of the turning-point regime change.

The optional `bistable_duffing` model is also supported, with its own equations,
target and critical value sqrt(3/2), but is NOT the default requested study.
Do not mix these models in one result table.

## Training and validation

- Training alpha: 0.1, 0.2, ..., 2.0 (20 values).
- Validation alpha: 0.05, 0.15, ..., 1.95 (20 values).
- Alpha=0 is excluded: the conservative system does not have the same
  asymptotic attraction classification. The validation value 0.05 is a small
  extrapolation below the training range; the other 19 values are interpolation.
- One fixed hyperparameter vector is used at EVERY alpha, not one winner per alpha.
- Objective: median of abs(R_hat(theta,alpha,seed)-R_reference(alpha)) over ALL
  training alpha/seed combinations. Equal seed counts give each alpha equal
  weight. This is the pooled median, NOT the mean or median of per-alpha medians.
- No time gate, weighted time score, or hidden secondary accuracy objective.
- The optimizer is declared deterministic for this fixed common-seed sample.
- Candidate selection uses the smallest OBSERVED training objective from both
  restarts. Exact ties use restart and evaluation order, not validation results.
- No Experiment A or supervisor configurations are supplied as initial points.
- The candidate is saved/frozen BEFORE the validation comparisons. The baseline
  is the current Habib-based transferred A/B controls, not a reference LIM number
  and not a baseline independently tuned on this model.
- Validation uses disjoint seed IDs as well as disjoint alpha values.

The pooled median does NOT guarantee small error for every alpha. Per-alpha
medians, P95, severe errors, number of improved alphas, and worst-alpha median
are all reported. A lower pooled median alone is not uniform dominance or proof
of optimality. This validates transfer across alpha within one model family,
not across arbitrary models. Do not repeatedly tune against the validation set;
a further independent test set is needed if it becomes part of model selection.

## Search variables and fixed controls

| Coordinate | Range / mapping |
|---|---|
| qk | integer 0..5; target-neighbourhood k=2*qk+1 |
| discr | integer 351..1051, NOT restricted to odd values |
| generations | integer 2..10 |
| population | integer 10..20 |
| newcomers | integer 2..12, additionally 20%-60% of population |
| selected | integer 2..5 |
| number_of_steps | integer 50..200 |
| Ts | real 0.025..0.10 |

Near-clones=2. Crossover count=population-1-newcomers-2 and must be >=1.
Native GA type_x0=1; tfinal=2000; RelTol=AbsTol=1e-8; recurrence=40/10;
divR=40. Both profiles use the same fixed controls and domain at every alpha.
The baseline vector is [1,701,5,20,8,3,100,0.05]. All actual inputs are exported.
At weak damping, the fixed finite-time classification may still fail to resolve
some trajectories; this test does not silently change horizon with alpha.

## Budgets

| Mode | Restarts x evaluations | Initial points/restart | Train seeds/alpha | Validation seeds/alpha | Maximum saved runs |
|---|---:|---:|---:|---:|---:|
| pilot | 2 x 8 | 4 | 2 | 5 | 880 |
| full | 2 x 200 | 16 | 10 | 100 | 84,200 |

The full budget is 80,000 training runs + 200 baseline training runs + 4,000
validation runs. Pilot is 640 + 40 + 200. Cached repeated configurations can
reduce actual executions. Untimed worker warm-ups are additional. Pilot keeps
both complete alpha grids but uses fewer seeds/evaluations; its conclusions are
preliminary and must not be substituted for the full budget.

BO evaluations are sequential. `parfor` parallelizes the alpha/seed tasks within
an evaluation, using a local Processes pool. Each validation pair runs
consecutively on the same worker in randomized order. Both profiles reset to
the same RNG seed (100000 + seed ID). Each worker runs one computation thread.
CPU and wall-clock timers enclose the same native compute_LIM_FP call on that
worker. Reference evaluation, warm-up, setup, summaries and saving are excluded;
solver plotting is disabled. These concurrent-worker timings are not serial
isolated-machine benchmarks and are not part of the optimization objective.

## Checkpoints and outputs

Each alpha/seed result (or validation pair) has an atomic MAT checkpoint. BO
state and RNG are saved after each evaluation. Set `resumeDirectory` to the
printed output folder to resume with identical options, sources, MATLAB version
and worker count. Failed numerical runs are retained, never silently removed;
a training failure stops the study. Invalid validation results invalidate the
corresponding summary instead of being discarded.

First read:

1. `validation_overall.csv`: pooled held-out error reduction and timings;
   also number of improved alphas and worst per-alpha median errors.
2. `validation_comparison_by_alpha.csv`: where the candidate helps or hurts.
3. `frozen_candidate_parameters.csv`: the one selected configuration.
4. `training_comparison.csv`: training performance versus transferred baseline;
   the NaN alpha row denotes the pooled statistic, not a failed alpha.

Other files: `validation_raw.csv`, `validation_paired.csv`,
`validation_by_alpha_and_profile.csv`, `search_configurations.csv`,
`reference_by_alpha.csv`, `reference_audit.csv`, per-restart trace files,
`transferred_baseline.csv`, `records/`, and `source_snapshot/`.

All errors use the analytical reference at THAT row's alpha, never alpha=0.7's
reference and never Habib's published numerical LIM. The main reduction is
100*(1-candidate median absolute error/baseline median absolute error).
