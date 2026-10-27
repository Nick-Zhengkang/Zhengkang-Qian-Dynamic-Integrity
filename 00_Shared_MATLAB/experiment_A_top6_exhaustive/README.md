# Experiment A six-factor exhaustive screening

Run `test_experiment_A_top6_exhaustive.m` as a whole file in MATLAB.
Default: full, 3240 configurations x 3 paired seeds (4101:4103) = 9720 runs.
Baseline is one of the 3240 configurations, not an additional configuration.
No random parameter sampling and no early elimination of grid combinations.
Execution order alone is random, across all configuration/seed pairs.

## Full Cartesian design

| Parameter | Values |
| --- | --- |
| target neighbourhood k | 1, 3, 5, 7, 9, 11 |
| discr | 351, 551, 701, 901, 1051 |
| num_gen | 2, 3, 5, 10 |
| requested newcomer ratio | 0.2, 0.4, 0.6 |
| population size | 10, 15, 20 |
| selected_opt | 2, 3, 5 |

Newcomers = round(population * requested ratio).
Crossover = population - 1 - newcomers - clones.
These derived counts necessarily change when population or ratio changes.
They are not additional independent factors. Original GA implementation and
its nominal population-composition semantics are retained without correction.

Fixed at Experiment A baseline: N=100, divR=40, clones=2, rep_fix_point=40,
Ts=0.05, tfinal=2000, RelTol=AbsTol=1e-8, rep_periodic=10, type_x0=1.
All remaining model/domain/weight/classification settings come from the same
adapter as the previous optimization. No original numerical files are edited.
Local adapter and summary helper are unchanged copies of the previous study.

Benchmark: Habib unforced double-well Duffing oscillator with linear damping,
zeta=0.05, a=b=1, target [-1,0], weights [4,1]. Reference LIM=0.7683 is a
published numerical value, not exact analytical truth. This is reference-
assisted optimization on ONE model, not reference-free model transfer.

## Ranking

Against the same-seed baseline, require no observed worsening of median error,
nearest-rank P95 error, fraction within 1%, mean false-safe or false-unsafe
rate; all runs and diagnostics must complete, with no unresolved labels.
Among configurations passing these checks and not needing timing review,
rank by median main-run wall time. If none beats the baseline, retain baseline.
All results, including failed configurations and long times, remain in exports.
The diagnostic helper uses learned grid labels plus further integration for
unknown cells. Diagnostic, setup, warm-up and export time are separate from
the main-run wall-time objective. Fixed diagnostic points use reference-radius
information. Zero observed diagnostic errors do not prove perfect classification.

Three seeds are SCREENING ONLY. P95 with the inherited nearest-rank definition
equals the maximum of three errors. The selected row is never labelled confirmed
or recommended. No automatic 30-seed stage is launched. Confirm shortlisted
settings on independent seeds before reporting stable speed/accuracy gains.

## Progress and resume

Each run prints START, integration completion, diagnostic completion and saved
progress. Each completed run gets an atomic MAT file in records/. Raw CSV is
refreshed every 25 completions and at normal termination. Resume uses MAT files,
not potentially lagging CSV files. An interrupted unsaved run is repeated;
completed failures are not selectively retried. Only one MATLAB writer should
use an output directory at a time.

To resume, put the previous output folder into `resumeDirectory` in the entry
script and run the whole file. It loads the original options automatically.
Changes to numerical source files are detected and rejected during resume.
The runner temporarily changes to its own directory so an old current folder
cannot shadow the local adapter or statistics helper. It restores the caller's
folder, path and RNG state on exit. Source-location checks remain enabled and
report both expected and actual paths if a conflict is detected.

Do not let the machine sleep during a timed run. Stop between runs before a
long break. Main-run times longer than 120 s are retained and marked for review,
not automatically interpreted as algorithm cost. Such configurations cannot
be selected for a speed claim; a flagged baseline blocks speed selection.
This threshold is only a warning rule, not a reliable sleep detector. Smaller
timing disturbances can still occur. Diagnostics have a separate timing flag.

## Outputs

- configurations.csv: all actual input combinations, including derived counts.
- randomized_schedule.csv: frozen execution schedule.
- raw_data_all_runs.csv: measured results, diagnostics and session identifiers.
- summary_by_configuration.csv: all configurations, accuracy gates and ranking.
- top20_screening_candidates.csv: first 20 rows, inspect eligibility columns.
- best_screening_parameters.csv: observed best eligible configuration, or an
  empty table when no reliable ranking is possible; always unconfirmed.
- timing_review_runs.csv: unusually long main or diagnostic timings.
- decision.json: scope, status and limitations.
- study_definition.mat, records/, source_snapshot/: restart and provenance.

## Checks

The entry script first runs `selftest_top6_exhaustive` for design/count/ranking
tests without integration. A failed self-test prevents the full study starting.
Use mode='smoke' for two real runs (baseline and one changed configuration).
Smoke mode is not research evidence. Full mode is never started by self-tests.
Alternatively, `selftest_top6_smoke_resume` runs these two integrations and then
checks that resuming the completed study preserves both saved records. It
deliberately starts in the previous optimizer directory to test same-name
helper isolation and restoration of the original working folder.

Authoring verification: MATLAB Code Analyzer was run on the new files, and an
independent enumeration checked 3240 unique valid combinations. MATLAB runtime
self-tests could not be executed in the authoring environment because MATLAB's
preferences directory was not writable; this is not an integration-test pass.
