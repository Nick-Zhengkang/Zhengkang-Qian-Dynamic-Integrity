SEPARABLE 4D: NO LEARNED GRID LABELS, 30-SEED PARFOR RETEST

This is a new independent ablation package. It does not modify any original
experiment or completed diagnostic. It covers only the separable QC + bistable
Duffing model, not the coupled 4D model, BO, or the earlier 2D studies.

WHAT CHANGES
The preceding run (20261030_032124_802) disabled non-target/domain-exit grid
reads. Its upper endpoints all passed independent non-target checks, but 28/30
lower endpoints were false target labels from learned positive-grid reuse.

This package additionally resets the read-only query geometry's cell_c list
to the INITIAL target-neighbourhood cells before each trajectory integration.
cell_d and cell_dout remain empty for reads. Historical cell-label writes are
retained but cannot affect later classifications. The exact added numerical
line is shown in ALGORITHM_CHANGE.diff.

UNCHANGED
Original target neighbourhood and its width; grid; model; weights; initial
search domain; Ts; ODE tolerances/MaxStep; horizon; direct domain-exit rule;
rep_fix_point/rep_periodic; automatic=1 horizon convention; algorithm seeds;
angular/radial search, budgets, direction limits and 3600-second wall guard.
The search's exact-state memoization is retained. It is different from sharing
a learned grid label among different initial states.

No analytical reference enters either classifier or search. References are
used only for reporting and selecting post-search diagnostic points.
The 2D fixed-point guard is NOT silently installed in this 4D experiment.
Any remaining recurrence/domain/target-neighbourhood error must be reported.

RUN
Open START_SEPARABLE4D_ALLCACHE_PARFOR.m from this folder in MATLAB and Run.
MATLAB R2025b and Parallel Computing Toolbox are required; historical runs
recorded R2025b Update 5. No Python or access to the original folders is needed.
Default: all 30 seeds using parfor with four process workers. Thread pools are
rejected. The current folder does not matter. Helpers have unique allcache4d
names to avoid confusing them with the preceding retest package.
Only the START script's seeds/numWorkers may be adjusted without invalidating
the integrity manifest. Full scientific comparison requires all 30 seeds.

PER SEED
1. Load an exact copy of the preceding no-negative-cache search record.
2. Reproduce that baseline, comparing the complete query sequence and result.
   Stop this case if it differs. Other seeds can continue independently.
3. Run the no-learned-cache search with the same inputs and algorithm seed.
   Assert that learned positive and negative grid-cache hit counts are zero.
4. Independently validate the new lower endpoint, upper endpoint and midpoint
   with ode45 and ode113, without learned labels, recurrence or box-exit labels.
5. Revalidate the preceding baseline endpoints. Reclassify its exact lower
   endpoint with the new classifier in a fresh diagnostic instance, and retain
   its sampled trajectory and recurrence trigger. This is separate from the
   search and cannot contaminate its cache or query sequence.
6. Replay the new search prefix through the winning endpoints and any first
   non-target point below reference. Retain trajectories, stop rules and
   independent checks of relevant initial states.

OUTPUT
A fresh results/YYYYMMDD_HHMMSS_SSS folder is created on every invocation.
case_summary.csv and SUMMARY.txt report control agreement, estimates and
endpoint validation, learned-cache hit counts, recurrence/forced-label counts,
previous-lower regression, search stop status, provenance agreement and errors.
seed_XX/control/ is the reproduced PRECEDING no-negative-cache method, not the
original fully cached method. Original midpoint values remain in the summary.
seed_XX/no_learned_cache/ holds the new search and independent validation.
seed_XX/previous_lower_regression/ holds the old exact point's new label and
sampled trajectory. Success here and success on the new endpoints are separate.
source_snapshot/ and before/after SHA-256 manifests retain reproducibility.

VALIDATION AND LIMITS
Independent validation physics/tolerances/horizons match the preceding run:
ode45/ode113; horizons 2400/12000; RelTol 1e-10/1e-12; AbsTol 1e-12/1e-13;
MaxStep 0.2/0.1. Physical certificates after t=200 or safety events can stop
earlier. Both components must support target; one can support non-target.
Unresolved physical tests and solver disagreements remain unresolved.
The midpoint is not a verified non-target radius. Report midpoint, lower and
upper independently. A small error or no below-reference estimate is not enough.
endpoint_checks_pass requires independent target/non-target lower/upper labels,
matched control and replay, no upper below reference, no unresolved search or
wall-time stop, and no contradictions/unresolved selected-chain checks.
previous_lower_agrees is a separate regression test, not hidden in that flag.
No result proves every intermediate label or the globally closest boundary.
A direction/query limit is not convergence, even if endpoint checks pass.
Disabling target reuse may be slower. The time limit is not silently increased.
These diagnostic timings are not a controlled algorithm speed comparison.

AUTHORSHIP / PRESERVATION
New harness and ablation code are AI-assisted under the author's instructions.
Third-party functions in native/ and frozen model/search/integration functions
are unchanged, with the original license retained. The preceding classifier
is copied with only its top-level function renamed to noneg4d_classifier.
This note does not replace the author's AI-use declaration or scientific review.
All full baseline MAT files are included as unchanged copies (~160 MiB); their
original source paths in the manifest are provenance, not runtime dependencies.
During preparation, static checks do not constitute numerical MATLAB execution.

