# Validation status (2026-10-21)

- MATLAB R2025b Code Analyzer (`mlint -id`): all nine `.m` files checked;
  no messages after correcting the unnecessary parfor structure-field access.
- Installed R2025b surrogateopt source checked for integer/linear constraint
  syntax, native checkpoint resume, and output callback fields.
- Full synthetic smoke test attempted with `selftest_surrogate_accuracy(true)`.
  MATLAB failed before executing the test: its batch process could not contact
  the required MathWorks service (error 5201). The initial launch also required
  a writable preference folder; using a workspace preference folder got past
  that error but not the service error.
- Therefore neither the MATLAB unit tests nor the surrogateopt/parallel runtime
  tests are claimed as passed here. No real pilot or full experiment was run.

The entry script first runs the lightweight contract tests in the user's MATLAB
session. For an inexpensive end-to-end solver check before the real pilot:

```matlab
selftest_surrogate_accuracy(true)
```

This smoke test uses fake DynIn observations, serial execution, two real
surrogateopt restarts, and a completed-study resume. To check actual parfor
execution on synthetic observations as well:

```matlab
o = surrogate_accuracy_options('selftest');
o.useParallel = true;
syntheticDirectory = run_surrogate_accuracy(o, '');
```

Synthetic output folders are explicitly marked and must not be used as
scientific results.
