2D FIXED-POINT GUARD: INDEPENDENT 90-CASE PARFOR RETEST
Prepared 2026-10-29. No new numerical results are claimed before MATLAB runs.

PATH FIX (2026-10-29)
The active independent validator now has the unique function name
fpguard_validate_independent. Both callers use it, and engine activation
checks its resolved filename and one-output signature on client/workers.
Each run temporarily uses this package as its current folder, restoring
the previous folder on exit. The legacy diagnostic_validate.m copy is
retained but is no longer called by this package. This avoids old diagnostic
folders shadowing the updated validator. No numerical rules were changed.
Existing failed-run outputs are retained. Re-run the same START script;
it creates a fresh timestamp and repeats preflight before the 90-case run.

RUN
1. Keep the earlier LIM_NoNegativeCache_All90_Parfor folder on the desktop,
   including results/20261028_040701_540. It is a read-only dependency.
2. Open START_FIXEDPOINT_GUARD_PARFOR.m in MATLAB and press Run.
   Use MATLAB R2025b and Parallel Computing Toolbox (local process pool).
   A new pool defaults to four workers; an existing local pool is reused.
   A thread or remote pool is not supported. The script does not clear the
   user's workspace, change prior files, or overwrite earlier results.
3. Outputs go to this package/results/<timestamp>. Send that path after running.

EXPERIMENT
Three models, seeds 1:30, same saved algorithm seeds and settings:
  quadratic_cubic: alpha=0.4
  bistable_duffing: alpha=0.7
  genda_cosine_quadratic_drag: alpha=0.05
Each of 90 parfor tasks first reproduces the old no-negative-cache result,
then runs the repaired search. Thus there are 90 controls + 90 repaired
searches, plus the focused regression and independent validation ODEs.
The unchanged engine is checked against the full saved query sequence,
labels, sample counts, RHS counts, minimum trajectory distances and states.
A failed reproduction stops that case, not silently counts it as success.

THE CHANGE
This is a model-informed repair of the fixed-point classification branch,
not a generic fixed-point detector and not a change to angular/radial search.
The existing repFixPoint=40 counter still nominates a candidate. Residence
in a cell is no longer sufficient to terminate as non-target. Termination
requires a sufficient non-target-well energy certificate:
  E = v^2/2 + U(x); dE/dt = -alpha*abs(v)^3 <= 0.
  Bistable Duffing: x>0 and E < 1/4 - 1e-7, target at (-1,0).
  Cosine: abs(x)>pi and E < 2 - 1e-7, target at (0,0).
  Quadratic-cubic: there is no other stable well; the other equilibrium is
  a saddle. Residence-only non-target termination is rejected, and the
  trajectory continues. Direct domain-exit detection remains available.
These are sufficient well-trapping conditions, not a claim that the state
has already reached a fixed point. A rejected candidate continues the same
ODE integration. It does not fall through to the periodic branch at that
sample. The original if/elseif priority and visit-gap counting are retained.
For the saved cosine domain [-pi,pi], no other well is inside the domain,
so its fixed-point non-target branch is effectively disabled. The direct
domain-exit rule still applies before any fixed-point check.
The certificate does not use an analytical LIM, seed, query number, winning
radius or independent validation result. Reference LIM is used only for
post-search metrics and selection of an additional diagnostic point.

UNCHANGED
Non-target/domain-exit cache READS remain OFF, as in the previous 90 retest.
Target cache reads and all cache writes remain unchanged. Also unchanged:
repPeriodic, direct domain exits, forced non-target at the time horizon,
target neighbourhood, grid, Ts, ODE solver/tolerances/MaxStep, random seeds,
angular/radial logic, search budgets and wall-clock guard. The original
Habib code and original experimental data are not edited.
More integration and logging may hit the existing wall-clock guard; such
cases are explicitly flagged and must not be treated as matched-budget
evidence of a successful repair. No compute-speed claim is intended here.

PREFLIGHT
Unit tests check physical certificates, unchanged counter thresholds,
negative-cache read suppression, target/domain priority, periodic rule,
and the lack of fall-through after a rejected fixed-point decision.
The exact stored pre-query cache from QC seed 30 query 567 is restored.
The old integrator must reproduce its saved trajectory and termination.
The repaired integrator must reject that same fixed-point decision and
continue with the same trajectory prefix. The eventual label is recorded,
not assumed correct. Independent validation of that initial point is run
with ode45 and ode113. Its local validation query index is 1 in preflight.

INDEPENDENT CHECKS
For each repaired search, independently integrate the winning non-target
initial point and the first below-reference non-target query, if present.
No grid labels or recurrence rules are used in this postcheck. The copied
validator uses tighter tolerances, two solvers, longer maximum horizons,
energy/escape conditions, and an energy-monotonicity check. Its numerical
implementation is unchanged; only returning/saving its assessment table
was added to avoid fragile CSV inference.
An unresolved/disagreeing postcheck is NOT a validated non-target point.
These checks do NOT validate every target-cache classification or prove
global accuracy. Remaining periodic, finite-horizon and domain-exit rules
can still fail, and target-label reuse is a separate remaining limitation.

RESULTS TO READ
  summary_by_model.csv: completion, underestimates, independently supported
    or contradicted winning labels, unresolved checks, other rule counts.
  per_case_summary.csv: all 90 statuses, old/new radii, error, final label
    source, fixed-point events, guard hits and validation outcomes.
  preflight/query567_regression_summary.csv: targeted old failure regression.
  <model>_seed_<n>/query_classification_audit.csv: per-query terminal source
    (confirmed non-target well versus periodic recurrence), event counts.
  <model>_seed_<n>/fixed_point_guard.mat: complete query records including
    every fixed-point event in details.query_records{k}.fp_events.
    Columns: sample, time, x, v, cell_id, accepted, energy, barrier_margin.
  <model>_seed_<n>/independent_postcheck/: independent outcomes/trajectories.
  input_integrity_before/after.csv: SHA-256 preservation checks.
  environment.mat and source_snapshot/: exact MATLAB/version/options/code.
  ERROR.txt inside a case: inspect any error; do not count it as a pass.
To rebuild summaries after interruption, run:
  collect_fixedpoint_results('absolute path to the new results timestamp')
Missing or incomplete cases stay visible; this does not resume searches.

PROVENANCE AND AI USE
The control, geometry, model RHS, angular search and native grid utilities
were copied byte-for-byte from the frozen previous-run source snapshot.
Original attribution/license files are preserved. New orchestration,
certificate, logging and tests were implemented with OpenAI Codex under
the author's instructions to repair the diagnosed fixed-point error and
independently retest the same 90 cases using parfor. The model-specific
energy confirmation is newly introduced here and must be disclosed if
these repaired results are reported. Code review/testing and acceptance
of the repaired results remain the author's responsibility.

VALIDATION STATUS AT DELIVERY
MATLAB R2025b static code analysis and source-integrity audits were run.
The MATLAB ODE searches and runtime preflight have NOT been run by Codex.
The user runs this package; no promise that all 90 cases now pass is made.
