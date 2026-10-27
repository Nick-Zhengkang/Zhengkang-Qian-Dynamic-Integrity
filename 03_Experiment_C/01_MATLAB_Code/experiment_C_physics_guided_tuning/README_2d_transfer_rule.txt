2-D DynIn GA transfer-rule experiment

Open test_experiment_C_2d_rule.m in MATLAB. Edit model, alpha, stage and
the cfg block. The original DynIn compute_LIM_FP and GA type_x0=1 are
called without modification. The model equations are in
transfer_2d_model/sistema.m.

Stages, in order:
  pilot: inspect target-label stability at T and 2T. The pilot uses no
         analytical LIM. Its runtime is recorded in pilot_audit.csv.
         Pilot rule version 2 does not call left-domain exit an escape in
         quadratic-cubic: a left excursion can return to the target.
  grid: compare three grid densities, recomputing k so the physical
        target belt stays approximately constant.
  belt: compare three energy-belt fractions at a fixed grid density.
  Ts: compare half, equal and twice the physics-based sampling interval.
  periodic: compare rep_periodic=5,10,30 separately.
  budget: compare 50,100,200 outer GA iterations with classifier frozen.
  validate: run the frozen physical rule with >=30 new seeds. Use a new
            model and parameter values not used to select the constants.

After pilot, set cfg.pilotConfirmed=true and cfg.tfinal to a checked
horizon (recommended_tfinal in pilot_audit.csv if it passed). The pilot
is a necessary screen, not proof that every trajectory
near the basin boundary has resolved. Grid/belt/time/periodic stages each
vary one factor family; do not choose their values from the held-out
model's analytical LIM. Record the chosen beta, eta, sampling density,
time-pilot protocol, rep_periodic and budget before validation.
The grid summary reports achieved_eta and the sampling summary reports
achieved_samples_per_period; copy the selected dimensionless constants
back into cfg.eta and cfg.samplesPerPeriod for the next model.

The GA output has wall time, LIM error against the analytical expression,
and 1% success. A separate fixed-point classifier diagnostic uses long,
tight integration and records target/non-target/unresolved counts. Its
standalone classifier has no accumulated GA cell history, so its error
rates are a diagnostic, not an exact audit of the full evolving classifier.
Analytical LIM enters only GA scoring after each run, never point
selection, profile construction or the pilot. Pilot and diagnostic costs
are stored separately from GA runtime.

All stages write incremental CSV output and can resume with resumeDir.
For validation use fresh seeds such as 31:60. A run configuration saved
in the output folder prevents resuming with a different model or cfg.
