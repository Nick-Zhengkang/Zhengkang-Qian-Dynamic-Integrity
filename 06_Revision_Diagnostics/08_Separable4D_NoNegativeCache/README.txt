SEPARABLE FOUR-DIMENSIONAL TARGETED REPAIR AND 30-SEED RETEST

Scope
  Only the separable quadratic-cubic + bistable Duffing model is included.
  This does not repair the coupled four-dimensional model or BO experiments.
  This is an attempted repair, not a claim that its future results will pass.

Diagnostic basis
  In the completed diagnostic 20261029_053219_578, all 30 winning upper-label
  chains began with left_computational_domain. Both independent solvers
  supported non-target for those 30 first-writer initial states. However,
  29 of the 30 winning upper endpoints were independently target. Thus the
  observed first-writer trajectories were not themselves false non-targets;
  transfer of a cell-wide label to a different trajectory is the main issue.
  Leaving a finite computational box is not a general basin-escape proof,
  but changing that rule is not justified by the first-writer evidence here.

Exact numerical change
  retest4d_classifier.m is a private copy of the frozen classifier.
  Before EACH integration it passes a geometry copy with cell_d and
  cell_dout empty. It does not read learned non-target/domain-exit labels.
  Negative-label WRITES are retained, but never read in the repaired branch.
  Target-label reuse, direct domain exit, recurrence, automatic=1 horizon
  convention, model, grid, target width, ODE tolerances, Ts, horizon, search
  settings and random seeds are unchanged. Exact-state memoization in the
  search is retained; this is distinct from cross-state grid-label reuse.
  No reference radius is supplied to the search or classifier. The saved
  reference is read only to summarize and select post-search audit points.
  All original MATLAB functions in engine/, native/ and model/ are unchanged.

Run
  Use MATLAB R2025b (original completed diagnostics: R2025b Update 5).
  Parallel Computing Toolbox is required. No Python is needed to run.
  Open START_SEPARABLE4D_RETEST_PARFOR.m from THIS folder and click Run.
  Alternatively run the full path to that script. Current folder is irrelevant.
  Default: 30 seeds, four process workers; the main loop uses parfor.
  A pre-existing process pool is reused with at most four workers.
  A thread pool is rejected. No original path outside this package is needed.
  Do not edit numerical files: integrity checks intentionally reject changes.
  numWorkers and seeds in the START script may be changed; the default is all 30.

For each seed
  1. Run the frozen original search with the saved algorithm_seed and controls.
  2. Compare all query states, labels, reasons, sample counts, endpoints and
     the final result against the saved run. Abort this case on mismatch.
     RHS-count agreement is reported separately from the matching gate.
  3. Run the no-negative-cache search, still with the same seed and settings.
  4. Independently integrate lower endpoint, upper endpoint and midpoint with
     ode45 and ode113, without grid reuse, recurrence or box-exit labels.
     Repeat those checks on the control endpoints for a paired baseline.
  5. Replay the repaired query prefix and trace the winning upper, lower and
     first below-reference non-target query. Validate relevant initial states,
     cache-hit states and first-writer states independently.

Validation
  Independent checks use the same component physics as the earlier diagnostic:
  QC target well: x<1 and energy<1/6; QC escape: x>1 and outward velocity;
  Duffing target/other well: energy<1/4 and x<0 / x>0. Strict margins apply.
  Both components are needed for target; either component can prove non-target.
  Horizons: 2400 and 12000; RelTol 1e-10 and 1e-12; AbsTol 1e-12 and 1e-13;
  MaxStep 0.2 and 0.1. Sufficient physical events after t=200 can stop early.
  Safety limit 50 and sampled component-energy checks guard solver failures.
  This is endpoint/selected-point numerical verification, not a proof of every
  learned cell label or of finding the globally closest basin boundary.
  Existing periodic, fixed-point and horizon rules are NOT silently repaired.
  Remaining contradictions or unresolved checks are retained and reported.

Output
  A NEW results/YYYYMMDD_HHMMSS_SSS folder is created every time.
  case_summary.csv: original/corrected radii; midpoint vs upper underestimation;
    independent lower/upper/midpoint outcomes; rule counts; control/provenance
    agreement; chain contradictions/unresolved; errors and search stop status.
  SUMMARY.txt: counts, including how many cases really produced valid evidence.
  seed_XX/control/: complete reproduced search, query comparison, validation.
  seed_XX/no_negative_cache/: complete corrected search, queries, reason counts,
    separate endpoint summary, independent trajectories and label provenance.
  source_snapshot/ and SHA-256 checks preserve the exact code and inputs used.
  Errors are retained in per-seed ERROR.txt; other seeds continue running.
  The midpoint is NOT renamed as a verified non-target upper endpoint.
  endpoint_checks_pass requires matched control/provenance, independently
    supported lower and upper labels, no upper below-reference estimate,
    no unresolved search labels or wall-time stop, and no contradicted or
    unresolved selected label-chain points. Midpoint alone is not this test.
  A finite run that hits a direction/query limit is not automatically called
    converged: inspect stop_status even when endpoint checks pass.
  Runtime includes different diagnostic overheads and is not a fair speed test.

Provenance / AI
  The new orchestration, ablation and diagnostics are AI-assisted code created
  under the author's experimental instructions. Third-party frozen code is
  retained unchanged with its original license. This note is not a substitute
  for the author's final AI-use declaration or scientific review.
  Input source paths in manifests are provenance only, not runtime dependencies.
  Only this package and its results are written; original experiments are not.
  No full MATLAB numerical rerun was performed when preparing this package.

