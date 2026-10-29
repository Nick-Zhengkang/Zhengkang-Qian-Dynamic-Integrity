# 09_Separable4D_NoLearnedCache: v17 separable four-dimensional evidence

Completed run: `20261030_040059_619`. Thesis: Section 6.4, Table 6.5 and the separable-4D diagnostic appendix.

All learned-cell reads disabled: 0/30 below-reference midpoints or upper endpoints; 30/30 endpoint pairs pass independent tests. Median midpoint error 0.0743364%, maximum 1.1785055%, 29/30 within 1%. Seven searches reach the direction limit; 236 intermediate fixed-point terminations were not all independently validated.

## Downloads and execution

- [09_Separable4D_NoLearnedCache_Runtime_Inputs.zip](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v17-separable4d-2026-10-30/09_Separable4D_NoLearnedCache_Runtime_Inputs.zip)
- [09_Separable4D_NoLearnedCache_Records_Common.zip](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v17-separable4d-2026-10-30/09_Separable4D_NoLearnedCache_Records_Common.zip)
- [09_Separable4D_NoLearnedCache_Records_Seeds_01_10.zip](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v17-separable4d-2026-10-30/09_Separable4D_NoLearnedCache_Records_Seeds_01_10.zip)
- [09_Separable4D_NoLearnedCache_Records_Seeds_11_20.zip](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v17-separable4d-2026-10-30/09_Separable4D_NoLearnedCache_Records_Seeds_11_20.zip)
- [09_Separable4D_NoLearnedCache_Records_Seeds_21_30.zip](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/v17-separable4d-2026-10-30/09_Separable4D_NoLearnedCache_Records_Seeds_21_30.zip)

Extract the **Runtime_Inputs** ZIP into the repository root to run this package.
It supplies the exact code and all copied inputs; no other diagnostic download
or original desktop path is required. The four Records ZIPs supply every file
of the completed run, without filtering failures, MAT trajectories or logs.
Extract those into the same repository root to inspect the complete old output.
The ZIP prefixes already contain `06_Revision_Diagnostics/09_Separable4D_NoLearnedCache/`.

Open `START_SEPARABLE4D_ALLCACHE_PARFOR.m` in this folder in MATLAB and press Run. Alternatively, from the
repository root, use:

```matlab
run(fullfile(pwd,'06_Revision_Diagnostics','09_Separable4D_NoLearnedCache','START_SEPARABLE4D_ALLCACHE_PARFOR.m'))
```

The recorded runtime is **25.2.0.3177638 (R2025b) Update 5**, release **2025b**,
on `PCWIN64`. Parallel Computing Toolbox is required. Defaults use
`parfor`, all 30 seeds, and up to four process workers. Each run creates a new
timestamped `results` directory; it does not overwrite these completed records.
Do not add all model folders using `genpath`: different models share function names.

## Verification and scope

`PUBLICATION_MANIFEST.json` gives every runtime/input and completed-record hash.
`recorded_summaries/` is a compact, unchanged browsing copy, not the full raw data.
`README.txt` is the preserved preparation-time document; the completed results above
supersede its pre-run status wording. Archived source paths are provenance only;
execution resolves paths within this package. Existing AI comments are retained;
the repository AI-use declaration and registers are not modified by this upload.

From the repository root, run `python 06_Revision_Diagnostics/check_v17_download.py`
after extracting all three runtime archives. Add `--require-records` after extracting
all twelve record archives. Checks are hashes, paths and saved-result consistency,
not a fresh MATLAB numerical rerun. No original experiment algorithm or data is changed.
The checks establish selected pointwise outcomes, not universal classifier correctness,
global nearest-boundary accuracy, corrected BO results or a coupled-4D repair.
