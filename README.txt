THESIS EXPERIMENT CODE AND RAW DATA
Prepared from the locally retained thesis sources, not the author's later submission edits.

00_Shared_MATLAB: shared adapters, reference functions and original DynIn.
01_Experiment_A_Sensitivity: 29 configurations x 30 seeds = 870 runs.
02_Experiment_B_BO: B1 contains 80,000 training solves, 200 baseline solves and 4,000 holdout solves. B2 contains 800 Duffing transfer runs.
03_Experiment_C: C1 time/diagnostic-order study; C2 180 domain-correction runs; C3 60 cosine runs; C4 supporting diagnostics.
04_Method_Comparison: 360 paired-model/method runs.
05_Thesis_Result_Sources: retained chapters, tables and numeric exports used to identify the datasets.
06_Revision_Diagnostics: 2D diagnostics and corrections, per-alpha analysis, plus v17 separable-4D diagnosis and both 30-seed cache-read retests.

V17 SUPPLEMENT
Code and direct raw-record downloads are indexed in README.md and the three
package READMEs under 06_Revision_Diagnostics/07_*, 08_* and 09_*.
Release: https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/tag/v17-separable4d-2026-10-30
Extract Runtime_Inputs and Records ZIPs into the repository root, preserving
their prefixes. All 1817 completed-run files are retained. Recorded runtime:
MATLAB R2025b Update 5 / 25.2.0.3177638, PCWIN64, Parallel Computing Toolbox.
Entry scripts retain parfor and create new timestamped results.
The final separable-4D retest supports both endpoints in 30/30 runs and has
no below-reference estimates. It does not repair the coupled model or BO.
Download/hash checks do not constitute a new MATLAB numerical rerun.
AI declarations and registers have not been changed for this supplement.

AI_USE_DECLARATION.md contains the author-approved contribution statement.
AI_CODE_REGISTER.csv distinguishes annotated working code, preserved upstream code, and immutable snapshots/libraries.
AI_ASSISTANCE_PRESERVED_CODE.m provides external comment documentation for preserved experimental code.
Historical prompts are not fabricated; the code register is not a complete prompt log.

Only attribution comments were added to working MATLAB/Python sources. Original DynIn, raw results, MAT files, archived source snapshots and ZIP bytes remain unchanged. Fixed-checksum libraries remain unchanged so their freeze checks still work. Original authorship and licenses are retained.
SOURCE_MANIFEST_SHA256.csv includes original and current source hashes and relocated file paths. ANNOTATION_VALIDATION_REPORT.json records the checks performed. PATH_RENAME_MAP.csv maps old names to English names.

This is a review archive, not a tested one-click installation. Existing historical paths were not changed inside algorithms or data. See each experiment README before any rerun. Adding comments changes source signatures and must not be mixed with resuming an old recorded batch.
The old combined C plotting script also contains superseded A/B sections: only its C portions map to the current thesis.

GITHUB RELEASE DOWNLOAD
https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/thesis-experiments-2026-10-27/Complete_Raw_Data_All_MAT_Records.zip
Release page: https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/tag/thesis-experiments-2026-10-27
SHA-256: 3acd8068eedd6b21cca616c987dcdcde907efec85a98d077bcf2198e1612d092
Place the downloaded ZIP at 02_Experiment_B_BO/02_Raw_Data/B1_Training_Holdout/Complete_Raw_Data_All_MAT_Records.zip.
The ZIP is distributed separately as a Release asset, not as an ordinary Git file.
See README.md for links, documentation and provenance.
Raw records retain historical machine paths and are otherwise unchanged.
