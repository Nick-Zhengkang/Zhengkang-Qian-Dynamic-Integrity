# Validation status (2026-10-23)

- MATLAB R2025b static Code Analyzer: no reported errors or warnings.
- Independent Python standard-library audit: 86 checks (40 alpha grid values
  plus three regime checks for each supported model), comparing double precision
  to 60-digit decimal evaluation of the paper's equations. Maximum radius
  difference: 1.22e-15. See reference_math_audit.csv.
- This numerical audit checks the reference mathematics, NOT MATLAB execution
  or the optimizer's ability to find an accurate configuration.
- Attempted MATLAB self-test launch failed before the tests ran: MathWorks
  required-services communication error 5201. See validation_matlab_log.txt.
- MATLAB runtime self-tests and end-to-end pilot remain unverified on this host.
  The entry script runs selftest_multi_alpha_bayes before starting its pilot.
- No DynIn search, training/validation study, or full BO run has been launched
  successfully by this task. Existing experiments were not changed.

## Report aggregation fix

- The user reported a dissimilar-structure assignment error in ma_report during
  the startup self-test, before any BO evaluation.
- Both report branches now collect scalar structs in cells and concatenate only
  after collection, avoiding indexed assignment into an untyped empty struct.
- Added selftest_ma_report for pooled, per-alpha, single-alpha, candidate-only,
  and failed-record cases. It runs first in the main self-test.
- Changed MATLAB files pass Code Analyzer without diagnostics. A new runtime
  attempt was again blocked by MathWorks error 5201 before tests ran; see
  validation_report_fix_log.txt. Runtime success is not claimed.
