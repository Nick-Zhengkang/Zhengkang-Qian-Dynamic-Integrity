# Four models, five complete methods

## Run one model

Open `test_one_model.m` in MATLAB. Edit **line 2**, then press Run.
Keep the complete folder together. No Statistics or Optimization Toolbox is
required: the original GA is the existing custom implementation, not `ga()`.

| Model name | Default parameter values | Reference |
|---|---|---|
| `quadratic_cubic` | alpha = 0.1:0.1:0.9 | Genda V2 analytical branch / LIM equations |
| `bistable_duffing` | alpha = 0.1:0.1:1.0 | Genda V2 analytical branch / stationarity equations |
| `paper_unforced_duffing` | zeta = 0.05, a = 1 | Habib Fig.1: approximate numerical LIM 0.7683 |
| `genda_cosine_quadratic_drag` | alpha = 0.05 | Genda cosine Eqs.26,29,34,37 evaluated numerically |

Every parameter value uses seeds 1:30 and all five methods. These polynomial
alpha grids are an explicit experimental choice within the existing reference
implementation's supported range, not a claim that the paper uses that exact grid.
The fixed cases accept only 0.05 to prevent accidental use of an unrelated reference.
The column `alpha` means **zeta** for Paper Duffing; `damping_parameter_name`
makes this explicit in the CSV.

Default first run is Paper Duffing to check alignment with Habib before the longer
sweeps. It produces 150 runs; quadratic-cubic produces 1350, bistable 1500.
This is a serial full-method experiment and can take considerable time.

## What stays frozen

- coarse_GA / fine_GA retain the existing GA and coarse/fine classification grids.
  They are not redefined as 10 versus 40 GA generations.
- DynIn retains `compute_LIM_FP`, its grid classifier and `type_x0=2` point-selection
  branches. No shared direct classifier replaces it. Added adaptive flags remain off.
- Proposed means **adaptive angular search**, not the old coarse-GA correction.
  The angular engine, defaults and the original two classifiers are byte-identical
  to the frozen package. New functions adapt only the two additional physical models.
- Energy-informed retains the existing candidate scoring and local refinement.
  The quadratic-cubic direct-event location is corrected from 0.98 to the actual
  saddle x=1. This is a disclosed model-threshold change, not a search-policy change.

For Paper Duffing, proposed uses linear damping and weight [4,1], with an added
2000-time-unit classification stage. Cosine uses quadratic damping, energy trapping
inside the central well and outward escape at +/-pi. Neither classifier reads a
reference value. All angular sampling, gap scoring, stopping and budgets are unchanged.
The existing proposed 3-second soft search limit remains in force. One trajectory
can overrun this limit because the frozen loop checks time between queries.
Inspect the saved stop reason, unknown counts and query histories; a finite estimate
is not a guarantee that the angular search fully converged.

## Habib alignment and its limits

Habib (2021), *Dynamical integrity assessment of stable equilibria: a new rapid
iterative procedure*, DOI 10.1007/s11071-021-06936-9:

- Eq.5: x'' + 2*zeta*x' - x + a*x^3 = 0; target (-1,0), zeta=.05, a=1.
- Published distance convention and DynIn Starter: weight=[4,1]. This preserves
  the reported metric rather than substituting a different linearization convention.
- Table1: domain [-2,-2,2,2], grid701, Ts=.05, RelTol=AbsTol=1e-8.
- Fig.1: 0.7683 is a numerical BOA reference, **not an analytical solution**.
- The 2021 worked algorithm example discusses GA selection and an estimate0.7791.
  The later DynIn tutorial supplies `type_x0=2`. Thus this suite tests the original
  tutorial bisection against the same physical benchmark/reference; it does not claim
  to reproduce the exact random path or algorithm variant of Fig.4.

Paper-bisection uses Table1 domain/grid/Ts/tolerances, together with tutorial tfinal2000,
50 search queries and local limit5. For unattended 30-seed testing, `automatic=1`
replaces the tutorial's interactive0. Unresolved trajectories are handled by the
original automatic rule, not by a new classifier. This choice can bias results and
must be checked using raw results and saved `OutL` records.
The other baselines retain their existing profiles, so the experiment compares
complete implementations, not identical-classifier/equal-budget sampling policies.

`habib_reproduction_check.csv` reports error against0.7683. The warning threshold
is at least90% of attempts within1%; this is our reporting criterion, not a threshold
stated in Habib, not an algorithm input, and not guaranteed before the experiment.
No result is clipped, rescaled, rejected or rerun to make it match the reference.

Cosine uses alpha=.05 from Fig.2 of *Manuscript version 2*. Its reference is calculated
from the paper's unique tangency root, not misrepresented as a printed numerical
constant. Numerical root finding of analytical equations is separate from the search.

## Outputs and timing

- `raw_data_all_runs.csv`: checkpointed after each completed five-method seed.
- `summary_by_alpha_and_method.csv`: accuracy, relative errors, runtime, failure and
  fractions within1%,2%,5%; threshold denominators include failed attempts.
- `summary_by_method.csv`: pooled results within this model. For sweeps, examine
  per-alpha results before making an overall claim.
- `reference_audit_alpha_*.csv`: scoring-reference checks, outside algorithm timers.
- `effective_dynin_alpha_*.mat`, `baseline_trace_*.mat`: actual baseline settings and OutL.
- `proposed_queries_*.csv`, `proposed_history_*.csv`, proposed MAT: full search diagnostics.
- `dynin_source_hashes.csv`: exact baseline source snapshot used in this run.
- `figures/comparison.png`: curves for sweeps; individual-run scatter for fixed parameters.

Each timer covers its complete method call, including initialization/classification/
point selection/bookkeeping. File saving, references and plotting are excluded.
Fixed method execution order and MATLAB first-call/JIT effects can influence timing.
This suite does not claim paired seeds make all methods sample identical points.
Trajectory-query counts are not equivalent to RHS counts or actual ODE integrations:
proposed may answer some queries through energy trapping without integrating.
Uncertainty and failure must be considered alongside runtime.

## Validation status

Compared against the user-confirmed Desktop package: all 29 original function-package
files are byte-identical. All 61 copied baseline MATLAB files match the current
Desktop DynIn functions byte-for-byte. New adapter, entry, self-test and reporting
files pass MATLAB Code Analyzer without diagnostics. `ORIGINAL_COMPARISON.md` is
retained as historical documentation of the two-model package; use this README
for the new entry point and four-model settings.

The MATLAB Code Analyzer can check these files, and `selftest_four_models` is supplied
for reference evaluation, frozen routing and the two new classifiers. Local batch
MATLAB startup failed with `File system inconsistency`, so full numerical execution
and achieved Habib accuracy remain **unverified until you run the suite**.
No model constants, budgets or outputs were tuned using unseen test outcomes.

`dynin_original` is a byte-for-byte snapshot of your current Desktop DynIn functions,
including previously added but disabled adaptive branches. It is not falsely labelled
as a newly downloaded pristine upstream release. The old package is not modified.
