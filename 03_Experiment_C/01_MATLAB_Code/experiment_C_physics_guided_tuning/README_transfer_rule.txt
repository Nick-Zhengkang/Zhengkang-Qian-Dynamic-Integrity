Experiment C: staged parameter-transfer study for the original DynIn GA

Start with test_experiment_C_transfer_rule.m. Edit model, caseValue, stage,
seedList and cfg at the top. The runner changes no original DynIn files.
type_x0=1, GA population 20 and five generations stay fixed.

Run stages separately for each model/case:
  1. pilot: Jacobian gives a starting horizon T. Fixed trajectories are
     checked at T and 2T. Read pilot_audit.csv. If pilot_pass is false,
     do not adopt that horizon. Raise cfg.pilot_multiplier (e.g. 2), use
     a new output folder and rerun, or add relevant boundary probes.
     This pilot is not a reference LIM and its cost is logged separately.
  2. grid: compare discr with k=3 fixed. Freeze discr after examining
     stability, classification diagnostic and runtime.
  3. Ts: compare half, equal and double the cfg.Ts starting value with
     grid and horizon fixed. The pilot records a Jacobian-based Ts start;
     this is a candidate only, not a validated sampling rule.
  4. periodic: compare rep_periodic=5,10,30 with all other settings fixed.
  5. diagnostic: replay 24 fixed initial states using the original
     classifier and a longer/tighter forward integration. Escape and
     target labels are conservative; bounded non-target outcomes may
     remain unresolved. This is not a complete ground-truth classifier.
  6. budget: compare N=40/100/200 (4-D) or 100/200/400 (8-D) only after
     the classification settings are frozen.
  7. validate: set 30 new seeds (e.g. 31:60) and the selected frozen
     settings. This stage runs one configuration with no further tuning.

For 4-D, test mu1=0.065,0.075,0.095 separately. For 8-D, start with
lr=2.0 and keep its model-specific target, modal weights and domain.
Record which case was used to select each setting. Treat the 8-D case as
held-out transfer validation, not another tuning target.

Each GA stage writes profiles.csv, randomized_schedule.csv, raw CSV and
summary CSV. Set resumeDir to its existing output folder to resume.
The output's horizon_exhausted_proxy is not an exact unresolved count:
original DynIn automatic mode converts unresolved paths to non-target.
No exact 4-D/8-D LIM reference is assumed, so seed agreement alone does
not establish absolute accuracy.
Important 8-D limitation: original find_index stores the multidimensional
grid ID as a double. With a grid near 1000 cells per coordinate, its ID
exceeds flintmax; distinct cells can therefore share a rounded ID. The
runner warns but does not alter Habib's code. Do not claim strict 8-D
classifier validity or transfer success until this numerical issue is
resolved in a separate, explicitly modified-code study.

MATLAB command-line testing on this host currently fails during MATLAB
startup with "System Error: File system inconsistency". Run the pilot
first in the MATLAB desktop and inspect its audit before the GA sweeps.
