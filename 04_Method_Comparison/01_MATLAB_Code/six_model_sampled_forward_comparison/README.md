# Single-Call, Sampled Forward-Reuse Comparison

## Launch

Run `test_sampled_forward_comparison.m` in MATLAB.

```
mode="pilot";
benchmark="all";
resumeDirectory="";
```

Pilot: 6 models x 2 methods x 3 seeds = 36 randomized runs.
Full: change mode to "full" for 30 seeds, 360 runs.
One model can be selected by its ID in the launcher. A string array selects a subset.
For cosine plus separable 4D only:

```
benchmark=["genda_cosine_quadratic_drag","separable_qc_bd_4d"];
```

That subset has 12 pilot runs. "smoke" is a short implementation check, not evidence.
Keep this folder beside the existing original and angular-search packages.
Do not run another experiment simultaneously when evaluating runtime.

## Controlled Change

Original DynIn v1.1.0 remains unchanged, type_x0=1. It still calls ode45 once per
Ts segment. Proposed retains its existing adaptive angular/radial search, but calls
ode45 ONCE per integrated initial state, with requested output at 0:Ts:tfinal.
Its OutputFcn processes samples in time order and stops on the first classification.
Only samples through that first classification can teach grid labels. Later samples
from the same callback batch are discarded. Initial states are not classified at t=0;
the first check is at Ts, matching the native routine.

Both use Ts=0.05. This version deliberately keeps the effective native maximum
internal step of Ts/10=0.005. RelTol=AbsTol=1e-8. Removing solver restarts is NOT also
a silent relaxation of integration accuracy settings. Speed improvement is measured,
not guaranteed. Relaxing MaxStep would be a separate future experiment.

No energy classification. No backward integration. No continuous Events classifier.
No extra retry. No conflict detection. Forward sampled paths propagate labels using
the native stable-unique/final-entry-exclusion convention and native label priority.
Grid construction, native snapped target cells, strict sampled domain checks,
rep_fix_point=40, rep_periodic=10 and check_min_periodic=0 remain shared.
Grid-label reuse is distinct from using trajectory points/minima as search candidates.
Proposed uses the former, not the latter; the manifest records these separately as
grid_label_reuse=true and trajectory_candidate_reuse=false.
Automatic=1 is retained: an unclassified trajectory at the COMPLETE horizon becomes
non-target and is recorded in forced_non_target_count. An incomplete/failed solve
does not use this convention and cannot teach labels.

The same sampled classification rules do not guarantee identical numerical samples
or labels: one continuous solve and repeated restarts follow different numerical paths.
This is a full-method comparison, not an isolated proof of angular-search speedup.

## Lower Grid Resolutions

The 2D refinement factor is now 1 for BOTH methods; 4D remains factor 1.
Target neighbourhood physical widths remain approximately those of the matched
fine-grid version, with native grid snapping retained.

| Model ID | discr | effective k | tfinal |
|---|---:|---:|---:|
| quadratic_cubic | 401 | 11 | 1200 |
| bistable_duffing | 401 | 11 | 1200 |
| habib_unforced_duffing | 701 | 3 | 2000 |
| genda_cosine_quadratic_drag | 501 | 11 | 1200 |
| habib_vdp_tmd_4d | 701 | 3 | 2000 |
| separable_qc_bd_4d | 801 | 7 | 1200 |

The historical requested k=12 is effectively k=11 in Habib's native implementation.
Both methods explicitly use that same effective value here. These settings are
experimental shared controls, not a claim that every value reproduces the paper.
The domains, distance weights, outer/search budgets and angular controls are inherited
from the matched-forward version. Reducing the grid and changing the integrator in
2D means a comparison with the earlier fine-grid version does not isolate either cause.

## Checks Before Running

1. Verify equal grid, target, domain, horizon, tolerances and sampled-rule parameters.
2. Verify model and shared solver paths, including the coupled model's local duplicate.
3. Replay native sampled trajectories through the new rules and require identical
   classifications and cell IDs on those SAME samples.
4. Compare continuous/segmented short probe labels and stopping samples. Differences
   are reported, not silently relabelled. These are short implementation probes,
   not independent basin-boundary validation.
5. Test multi-sample callbacks, first-hit stopping, horizon completion, native label
   precedence, recurrence thresholds, learned-cell propagation and per-run cache reset.
6. Verify a rejected wall-budget query performs no ODE call and teaches no labels.

Results are saved in classifier_implementation_checks.csv. Columns reporting
continuous_kind_differences or continuous_stop_differences must be inspected. A pass
of the rule tests does not mean that the two integrators agree on every state.

## Cost Interpretation

The randomized pilot records LIM, reference deviation where supported, convergence,
core and wrapper runtime, query_count, trajectory_count, ode_solver_calls,
sample_check_count, reuse hits and forced horizon labels. Proposed also records actual
RHS evaluations; original RHS evaluations remain NaN because its code is not instrumented.
Original ode_solver_calls counts short segments; Proposed counts continuous solves.
These counts are not equivalent units of numerical work. Compare runtime alongside
sample checks and trajectory/query counts; never call their ratio a speedup factor.

Proposed core time includes its grid initialization, search, integration and label
maintenance. Self-tests, export and file snapshots are outside core timing.
The per-query wall guard does not interrupt an ODE already in progress.
Review flags are expected whenever learned labels, recurrence or domain exits are
used. Finite output and convergence status do not prove a physically correct boundary.
The 4D post-search audit is disabled and explicitly recorded as not_run_disabled.

The coupled four-dimensional model has no verified reference LIM: error fields are
NaN. Do not use 0.57370 as its true reference. The Habib unforced Duffing reference
is a published numerical estimate, not an analytical truth.

## Outputs and Resume

Outputs are written to a NEW outputs_sampled_forward_<mode>_<timestamp> directory.
The prior grid-reuse, matched-forward and bidirectional files are not overwritten.
Each completed run is saved separately, followed by raw/summary/paired CSV updates.
The manifest, randomized schedule, source hashes, settings and source snapshots are saved.
Resume by setting resumeDirectory to THIS version's output folder, with all numerical
options and sources unchanged. Completed successful runs are skipped.

The package includes runtime checks but must first be executed in the user's MATLAB.
Static validation alone is not a successful pilot.
