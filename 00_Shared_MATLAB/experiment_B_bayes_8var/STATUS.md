# Verification status

- New, isolated eight-variable experiment; old experiments remain unchanged.
- MATLAB R2025b mlint passed on all 14 MATLAB source files without diagnostics.
- Tests cover continuous Ts, integer trajectory budgets, exact cache keys,
  unchanged controls, existing feasibility constraints and confirmation metrics.
- SHA-256 comparison confirmed that all 12 reused/source files inspected before
  implementation remain unchanged, including the old six-variable runner.
- Attempted `selftest_bayes8_accuracy(true,true)` through MATLAB -batch with a
  writable preference directory. Startup failed with MathWorks service error
  5201 before any MATLAB tests ran. Dynamic self-tests, native integration,
  optimizer resume and parfor have therefore NOT been runtime-verified here.
- The entry runs fast checks in the user's working MATLAB before optimization.
  No scientific pilot or full search has been started automatically.
