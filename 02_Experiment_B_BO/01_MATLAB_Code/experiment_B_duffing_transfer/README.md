# Frozen BO transfer to bistable Duffing

Run test_duffing_transfer in MATLAB from this directory. It uses six process
workers (parfor), one computational thread per worker. It does not run BO.

- Pilot (default): alpha = 0.05:0.05:2.00; 10 seeds per alpha and profile;
  800 solver runs plus untimed warm-ups.
- Full: change mode to 'full'; 100 seeds per alpha and profile; 8000 runs.
- Both settings use fresh seeds (110101 onward), shared between the two profiles.
- Put an interrupted output path into resumeDirectory to resume identical
  settings. Each pair is checkpointed. Cached failed runs are retained.

The candidate comes from frozen_candidate.mat in the completed
experiment_B_multi_alpha/outputs_multi_alpha_full_20261023_055518_403 study.
It was trained on the quadratic-cubic model. Full-precision parameters are loaded.
The original source snapshot supplies the native solver and parameter mapping.
Keep that source study directory in place. The transfer-specific analytical
evaluator is duffing_transfer_reference.m; it does not modify the BO snapshot.

| Control | Habib-based transfer | QC-trained BO transfer |
|---|---:|---:|
| Target neighbourhood k | 3 | 11 |
| discr | 701 | 1012 |
| generations | 5 | 7 |
| population | 20 | 20 |
| newcomers | 8 | 12 |
| selected_opt | 3 | 3 |
| number_of_steps | 100 | 171 |
| Ts | 0.05 | 0.0920905251923764 |

Both profiles use xddot + alpha*abs(xdot)*xdot - x + x^3 = 0, target (-1,0),
Euclidean weights, and inherited domain/classification settings. Only the
physical model and target change. No per-alpha adjustment or reselection occurs.

The reference is the lower envelope in Figure 9 of
Escape_and_catchment_in_potentials_with_quadratic_air_drag_V2.pdf, evaluated
from analytical separatrix formulas using numerical root finding. It is not
read from pixels or taken from an upper tangency/turning-radius branch.
Roots are checked at two resolutions, with independent integrating-factor
quadrature checks. Alpha zero is excluded: the conservative system cannot use
the same convergence-to-equilibrium test.

The turning-point root is bracketed down to floating-point resolution, taking
the physically admissible side (velocity squared >= 0). Its residual is checked
before assigning the exact zero endpoint velocity. This fixes the coarse-root
negative residual encountered near alpha=0.805 and 0.820 in the original dense
curve evaluation. The self-test includes these regression cases. Reference code
is hashed in the resume definition. After this fix, leave resumeDirectory empty
and start a new output folder; the earlier reference-stage failure ran no DynIn
jobs. Do not resume that old, incompatible definition.

Pairs run consecutively on the same worker, with randomized order. Worker CPU
and wall-clock time enclose the same native solver call. Warm-up, reference
evaluation, scoring, reporting, plotting and saving are outside both timers.

## Outputs

- transfer_raw.csv: every alpha/seed/profile, including failures.
- comparison_by_alpha.csv: median absolute error, reduction and timing.
- comparison_overall.csv: pooled comparison; also examine individual alphas.
- summary_by_alpha_and_profile.csv: per-alpha distributions.
- paired_comparison.csv: paired differences.
- reference_audit.csv: analytical numerical checks.
- duffing_transfer.png, .pdf, .svg: Python figures.
- curve_summary_python.csv, plot_audit.json: plotted values and checks.

Top panel: analytical envelope, median LIM, Q1-Q3 bands and all successful runs.
Lower panel: median individual relative error, not error of the median estimate.
Incomplete groups have no median/band. Bands represent seed variability, not
confidence intervals. The dense reference includes the switch near alpha=0.68788.
No successful transfer is assumed before inspecting the measured results.

Python plotting runs automatically after MATLAB finishes and checks its medians
against MATLAB. To replot without rerunning the solver:

    python plot_duffing_transfer.py PATH_TO_OUTPUT_DIRECTORY

Dependencies: NumPy and Matplotlib. Existing repository plotting dependencies are
located automatically. MATLAB uses the bundled Python path near the end of the
runner; adjust that path if running on another computer.
