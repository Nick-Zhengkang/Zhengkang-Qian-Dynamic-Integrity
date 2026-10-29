# v16: fixed-point confirmation and the complete 90-case retest

This folder supplies the later two-dimensional correction reported in v16,
Section 6.3, Table 6.3, Figure 6.2 and the diagnostic appendix.
It adds evidence without replacing the original comparison or the earlier
cache-off experiments. The completed MATLAB run is `20261029_064110_739`.

## Recorded outcome and scope

| Model | Damping alpha | Completed | Below reference | Final points supported by both solvers |
|---|---:|---:|---:|---:|
| Quadratic-cubic | 0.4 | 30 | 0 | 30 |
| Bistable Duffing | 0.7 | 30 | 0 | 30 |
| Cosine potential | 0.05 | 30 | 0 | 30 |
| Total | | 90 | 0 | 90 |

Every case first reproduced its saved cache-off control, then ran the corrected
search. There are 90 controls and 90 corrected searches, plus regression tests
and independent integrations. All 180 final-point solver outcomes (`ode45` and
`ode113`) supported non-target membership. No final validation was unresolved.
No corrected run hit its wall-time guard or terminated through the periodic or
horizon-forced non-target rules. The below-reference flag uses a tolerance of
`1e-10`.

Non-target/domain-exit cache reads remain disabled, as in the earlier ablation.
The additional guard retains the fixed-point counter but requires a sufficient,
model-specific non-target-well energy condition; otherwise integration continues.
It uses neither a reference LIM nor a seed/query identity to classify a state.
Target-cache reads, periodic/domain/horizon rules, seeds, integration settings
and angular-radial search settings are retained.

The earlier cache-off stage had already removed below-reference estimates but
validated only 89/90 final points. The new guard corrects the remaining false
fixed-point label. Only quadratic-cubic seed 30 changes its final radius:
`0.647491455078125` to `0.6490234375`. Its query 567 rejects fixed-point candidates
at times 7.75 and 7.80, continues to a target-cache label at 14.05, and is separately
supported as target by both cache-free solvers. The regression figure uses local
query index 1 for this original query 567.

These checks concern final points and the stated regression case, not every
intermediate label, global search optimality, four-dimensional repairs, or a
corrected BO study. They are not a new speed comparison. Original records remain
unchanged, including earlier failures.

## Complete records and extraction

The [v16 Release](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/tag/v16-fixedpoint-2026-10-29)
contains all 1,585 files from the completed run, split into four independent ZIPs:

- [Common records, regression and exact source snapshot](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v16-fixedpoint-2026-10-29/FixedPointGuard_00_Common.zip)
- [Quadratic-cubic, 30 cases](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v16-fixedpoint-2026-10-29/FixedPointGuard_01_Quadratic_Cubic.zip)
- [Bistable Duffing, 30 cases](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v16-fixedpoint-2026-10-29/FixedPointGuard_02_Bistable_Duffing.zip)
- [Cosine potential, 30 cases](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v16-fixedpoint-2026-10-29/FixedPointGuard_03_Cosine.zip)
- [SHA-256 checksums](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v16-fixedpoint-2026-10-29/SHA256SUMS.txt)

Extract all four ZIPs into the **repository root**, preserving their paths. They
populate `06_Revision_Diagnostics/06_FixedPoint_Guard_90/results/20261029_064110_739/`.
`RECORDS_MANIFEST.json` identifies every record, size, checksum and archive.
`recorded_summaries/` contains unchanged selected CSVs and the regression figure
for browsing; it is not a substitute for full MAT records. The archives preserve
the completed run, not the earlier interrupted preflight attempt.

## Rerun from a fresh download

Use a short writable checkout, for example `C:\lim`. Download the whole repository;
do not flatten it or add all model folders with `genpath`.

1. Download the [earlier cache-off all-90 records](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/diagnostics-2026-10-28/03_Negative_Cache_90_Complete_Records.zip)
   and extract them into the repository root. The required input is
   `06_Revision_Diagnostics/03_Negative_Cache_90/results/20261028_040701_540/`.
2. Open `START_FIXEDPOINT_GUARD_PARFOR.m` in this folder and press Run.
   MATLAB R2025b Update 5, version 25.2.0.3177638, is the recorded runtime.
   Parallel Computing Toolbox and a local process pool are required. The entry
   defaults to four workers and retains `parfor`; an existing local process pool
   is reused. No BO toolbox is needed for this retest.
3. Each rerun creates a new timestamped `results/` folder. It never overwrites the
   original inputs or the archived completed run.

The new Release records are needed to inspect the recorded evidence, not to start
a rerun. The regression fixture is included in `input/`; no separate query-567
Release is needed. The 297 prior inputs and 15 local immutable inputs are checked
before and after a run. Their expected hashes are unchanged.

The published entry uses repository-relative paths instead of the author's desktop.
Only `START_FIXEDPOINT_GUARD_PARFOR.m`, `run_fixedpoint_all90.m` and
`verify_guard_inputs.m` are relocated; numerical engines, models, validator and
all numerical settings match the successful source snapshot byte for byte.
`input/source_manifest.json` and `RECORDED_RUN_README.txt` preserve the historical
paths/instructions. `input/portable_source_manifest.json` maps the same hashes
to download-relative paths. Publication does not replace the historical snapshot.

## Verification without rerunning MATLAB

From this folder:

```text
python check_publication.py
python check_publication.py --require-prior --require-records
```

The first checks source preservation and the browsable result summaries.
The second additionally verifies all prior inputs and all complete Release
records. It independently recounts the 90 outcomes, model summaries and
regression result from recorded CSVs. Python 3.12 standard library is sufficient.
These are download/integrity/statistical checks, not a fresh MATLAB numerical
rerun. `PUBLICATION_CHECKS.json` records the checks actually performed.

Existing source comments and third-party notices are retained without alteration.
