# Verification status

## 30-seed full revision (2026-10-22)

- Full mode now uses common seeds 99101--99130: 29 configurations and 870 runs.
  Pilot (2 seeds) and smoke (1 seed), model, factor levels, diagnostics and parfor
  behavior are unchanged. Existing output folders and snapshots are untouched.
- Updated the full-mode validation, self-tests, entry-script count and README.
  Existing resume checks require a new study for this changed seed list/source.
- MATLAB R2025b standalone mlint passed all four modified MATLAB files without
  diagnostics. Batch self-test could not execute: after using a writable temporary
  preference folder, MATLAB startup failed with MathWorks service error 5201.
  No new native experiment was started. The entry script runs the self-test in
  the user's working MATLAB session before starting the experiment.

## Record filename repair

- Converted string-generated record filenames to character vectors before
  passing them to the shared atomic writer. Its character concatenation had
  produced a two-element string array, which `save` rejects.
- Normalized the public export folder argument for the same reason.
- Added MAT/CSV write-and-read self-tests, run before numerical testing.
- Worker activation clears the job function so an existing process pool can
  reload the repair. Shared BO utilities and the user's full-mode setting
  remain unchanged. Start a new output folder; old source signatures differ.

- New isolated study; old experiment runners, results and thesis sources untouched.
- Same Genda quadratic-damping model, metric, domain and transferred baseline as
  eight-variable BO. Self-test checks equality against `bayes8_problem`.
- Original A's 14 factors, 29 configurations and composition rules retained.
- Reference scoring, separate quadratic-model diagnostic labels, per-job atomic
  checkpoints, source signatures, resume checks and process-parfor implemented.
- MATLAB R2025b standalone mlint checked every new MATLAB source file.
- A real MATLAB batch self-test was attempted with a writable preference folder,
  but MATLAB failed to start: MathWorks service communication error 5201.
  No native integration, diagnostic timing, parfor or resume test has executed
  successfully in this session. No pilot/full scientific results are claimed.
- The entry script runs fast reference/design/path checks in the user's working
  MATLAB session before the requested pilot. Optional
  `selftest_genda_sensitivity(true)` also checks native reference independence.
