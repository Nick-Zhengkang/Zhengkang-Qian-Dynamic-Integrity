SEPARABLE FOUR-DIMENSIONAL LIM DIAGNOSTIC
Prepared 29 October 2026

PURPOSE
Inspect the 30 archived Proposed runs for midpoint versus upper-endpoint
underestimation, then trace the frozen grid-label learning history.
This package does not rerun the angular search, tune settings or fix labels.
Original experiment directories are never written to.

CURRENT FINDINGS (STATIC RECORD CHECK ONLY)
Reference: 0.6474801597003329, min of the QC and BD component references.
QC alpha = 0.4; BD alpha = 0.7; target = [0,0,-1,0]; weights = [1,1,1,1].
24/30 reported midpoints are below reference.
The corresponding 24/30 winning upper endpoints are ALSO below reference.
No underestimated midpoint has a winning upper endpoint at/above reference.
Upper-endpoint deficits: 0.219605% to 2.480994% of the reference.
The midpoint-to-upper shift accounts for only 0.246755% to 2.809500% of
the original deficit. Replacing midpoint by upper does not remove low bias.
All 30 winning upper queries (including the 24 low ones) have numeric cache
kind 3 / native kind 3, corresponding to known_domain_exit_grid_cell.
All stop at the first checked sample, t=0.05 (sample_count=2 including t=0).
This is a cached domain-exit label, NOT a direct domain exit of that query.

These fields do not identify the original label writer or prove whether its
trajectory truly escaped. Cache-source causation and independent outcomes
require the MATLAB replay and reintegration below. No new integration has
been executed during preparation of this package.

RUN IN MATLAB
CSV import fix: manifests and endpoint tables use explicit column schemas,
not automatic header/type detection. TEST_INPUT_READING.m is an optional
short check without integration or parallel pool startup.
1. Open START_SEPARABLE4D_DIAGNOSTIC.m from this folder and press Run.
2. Default: all 30 seeds with parfor, up to 4 process workers.
   Parallel Computing Toolbox is required. A thread pool is not supported.
   Set options.numWorkers before starting a new pool to choose another size.
   An existing process pool is retained; at most numWorkers are used.
3. Outputs are written to a NEW results/yyyyMMdd_HHmmss_SSS directory.
4. Send that result directory back for interpretation.

The archived comparison used MATLAB 25.2.0.3177638 (R2025b) Update 5.
The new scripts passed the installed R2025b static code analyzer, but have
NOT been executed in MATLAB here. They record your actual runtime/version.
No Statistics and Machine Learning Toolbox is needed for this diagnostic.

WHAT THE SCRIPT DOES
- Verify SHA-256 of all 39 copied input/source/license files.
- Use only the included input copies, model and frozen numerical routines.
- Replay saved query initial states in original order, through the latest
  query needed for the winning bracket and first below-reference label.
  This is a prefix replay, NOT a full new adaptive search.
- Compare saved labels, raw kinds, cache kinds, sample counts, end times,
  minimum radii and minimum states. Stop a case on any mismatch.
- Preserve the exact original stable-unique cache update and priority.
  Track the FIRST writer in each label class, donor state/sample and hit state.
- Trace the winning upper label and first below-reference label backwards
  through their writer queries, to a direct classification root.
- Identify rep_fix_point versus rep_periodic if a replayed recurrence occurs.
- Independently integrate the winning lower/upper/midpoint, and all initial,
  cache-hit and donor states along the two traced chains, using ode45/ode113.
- Independent checks use no learned grid, recurrence rule or domain-exit label.
  Both component systems must support target; either component can support
  non-target. Unknown outcomes stay unresolved, even if both solvers agree
  that they are unresolved. Both agreeing is supporting numerical evidence,
  not a rigorous basin-boundary proof.
- Verify frozen input hashes again after completion.

INDEPENDENT SETTINGS
ode45:  horizon 2400, RelTol 1e-10, AbsTol 1e-12, MaxStep 0.2.
ode113: horizon 12000, RelTol 1e-12, AbsTol 1e-13, MaxStep 0.1.
Sufficient physical tests can stop integration from t=200 onwards.
A safety state limit of 50 stops extreme trajectories; it is not itself a
non-target classification. The component physical tests still decide the label.
Both component energies are checked for sampled monotonicity.
The reference LIM is NOT used by these independent outcome tests.

RESULTS TO INSPECT
static_audit/all30_endpoint_audit.csv : one row per original run
static_audit/all_ray_brackets.csv : all saved direction brackets
static_audit/all_query_numeric_labels.csv : every original query
static_audit/saved_reason_counts.csv : full ORIGINAL-run reason counts
static_audit/audit_summary.json : current static findings

results/<timestamp>/case_summary.csv : all replay/validation statuses
seed_XX/query_provenance.csv : replayed query and donor details
seed_XX/winning_upper_label_chain.csv : final upper endpoint ancestry
seed_XX/first_below_reference_label_chain.csv : first low non-target ancestry
seed_XX/replayed_prefix_reason_counts.csv : PREFIX counts, not whole-run counts
seed_XX/independent_assessment.csv : two-solver assessment and contradictions
seed_XX/independent_validation.csv : detailed numerical checks
seed_XX/independent_trajectories.mat : sampled trajectories/energies/outcomes
seed_XX/replay_details.mat : replay records and selected native trajectories
seed_XX/ERROR.txt : present only when that case raises an error

PRESERVATION AND AI USE
input/, engine/, native/ and model/ contain byte-identical frozen copies.
input_manifest.csv gives original paths and SHA-256 hashes. Do not edit these.
Native DynIn utilities retain their source text and GPL-3.0 license.
The new diagnostic orchestration, observers and independent validation code
were AI-assisted under the author's requested investigation. They require
review and runtime verification and do not certify the original algorithm.

Python inspection is optional and not needed for MATLAB execution.
inspect_saved_records.py requires NumPy and SciPy and refuses an existing
output directory. prepare_inputs.py is an archival packaging helper tied to
the original local archive, not a MATLAB runtime dependency.
