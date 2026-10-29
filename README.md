# Dynamic Integrity: Thesis Code and Experimental Records

MATLAB code, original experimental records, and AI-use documentation accompanying Zhengkang Qian's bachelor's thesis:

**Analytical Benchmarking and Improvement of Numerical Dynamic Integrity Assessment Methods for Nonlinear Mechanical Systems with Quadratic Drag**

## v16: targeted 2D correction and 90-case retest

The [fixed-point-guard package](06_Revision_Diagnostics/06_FixedPoint_Guard_90/README.md)
supplies the code, query-567 regression and complete recorded evidence for v16
Section 6.3, Table 6.3 and Figure 6.2. After non-target cache-read suppression and
model-specific fixed-point confirmation, none of the 90 estimates was below its
reference and all 90 final points were independently supported as non-target.
The earlier 89/90 cache-off stage is preserved separately. This is pointwise
evidence on three 2D models, not universal classification or 4D/BO validation.

[Complete v16 records and checksums](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/tag/v16-fixedpoint-2026-10-29)
are distributed through a new Release. Its four ZIPs extract into the repository
root. Rerunning requires the previous all-90 cache-off Release; the package README
gives exact paths and the `parfor` entry point. No original experiment files or old
Release assets are replaced.

## Download the complete Experiment B data

The complete multi-alpha Bayesian-optimization batch is too large for an ordinary Git repository file. It is supplied as a GitHub Release asset:

- **[Download Experiment B1 complete raw data (254.6 MiB)](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/thesis-experiments-2026-10-27/Complete_Raw_Data_All_MAT_Records.zip)**
- [Release page](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/tag/thesis-experiments-2026-10-27)
- [Download SHA-256 checksum](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/thesis-experiments-2026-10-27/SHA256SUMS.txt)

SHA-256: `3acd8068eedd6b21cca616c987dcdcde907efec85a98d077bcf2198e1612d092`

The ZIP contains all 82,710 files in the recorded batch: 82,200 per-task MAT files, 400 configuration-observation files, and source snapshots/settings/exports. It represents 80,000 training solves, 200 baseline-training solves and 4,000 holdout-validation solves. Each of the 2,000 validation task files contains a baseline/candidate pair. No failed, anomalous or large-error records have been removed.

After downloading, place the unchanged ZIP at:

`02_Experiment_B_BO/02_Raw_Data/B1_Training_Holdout/Complete_Raw_Data_All_MAT_Records.zip`

The adjacent `CSV_Quick_View` and `Runtime_Source_Snapshot` directories are available directly in this repository. Extracting the ZIP produces the original `outputs_multi_alpha_full_20261023_055518_403` directory.

## Experiment map

| Directory | Contents |
|---|---|
| [00_Shared_MATLAB](00_Shared_MATLAB) | Shared adapters, analytical-reference functions and original DynIn dependencies |
| [01_Experiment_A_Sensitivity](01_Experiment_A_Sensitivity) | Parameter sensitivity: 29 configurations, 30 seeds each, 870 runs |
| [02_Experiment_B_BO](02_Experiment_B_BO) | Multi-alpha Bayesian optimization/holdout validation and 800-run bistable Duffing transfer |
| [03_Experiment_C](03_Experiment_C) | Integration-time tests, controlled domain correction, cosine transfer, and separately identified supporting diagnostics |
| [04_Method_Comparison](04_Method_Comparison) | Original DynIn GA versus adaptive angular-radial search: six models and 360 runs |
| [05_Thesis_Result_Sources](05_Thesis_Result_Sources) | Retained thesis chapters, tables and numerical exports used to map results to datasets |
| [06_Revision_Diagnostics](06_Revision_Diagnostics) | Earlier 2D diagnosis, cache ablations and per-alpha statistics, plus the v16 fixed-point correction and 90-case retest |

[THESIS_RESULT_INDEX.csv](THESIS_RESULT_INDEX.csv) maps the reported analyses to entry points and records. [DATASET_MANIFEST.csv](DATASET_MANIFEST.csv) identifies all 11 preserved data batches. Experiment C's time batch includes diagnostic-order studies; the thesis horizon table uses three fixed-grid profiles from that batch. C4 folders contain supporting diagnostics, not additional primary comparison results.

## AI assistance and authorship

- [Author-approved AI-use declaration](AI_USE_DECLARATION.md)
- [File-level code register](AI_CODE_REGISTER.csv)
- [Comment documentation for preserved historical/frozen code](AI_ASSISTANCE_PRESERVED_CODE.m)
- [Annotation and preservation audit](ANNOTATION_VALIDATION_REPORT.json)

English attribution comments were added to 147 working MATLAB files and 12 Python analysis scripts. Experimental concepts, methodological direction, code review and iterative revision requests are attributed to the author as stated in the approved declaration; AI-assisted implementation is disclosed explicitly. This statement does not certify mathematical or numerical correctness. The register is not a reconstructed historical prompt log.

Original DynIn code, archived runtime source snapshots, frozen libraries and raw numerical data remain unchanged. Frozen/historical experimental code is documented externally to preserve its checksums. [SOURCE_MANIFEST_SHA256.csv](SOURCE_MANIFEST_SHA256.csv) records original/current hashes and archive-member provenance.

## Inspecting or rerunning the code

**New v13 diagnostics:** see the [download and run instructions](06_Revision_Diagnostics/README.md), [complete diagnostic records](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/tag/diagnostics-2026-10-28), and [verification scope](06_Revision_Diagnostics/PUBLICATION_CHECKS.json). The new MATLAB records and original six-model comparison identify **MATLAB R2025b Update 5, version 25.2.0.3177638**, as the actual runtime. The 90-case retest requires Parallel Computing Toolbox and retains `parfor`. Python reproduction was checked with Python 3.12.14 / NumPy 2.3.5. This statement does not infer every historical batch's runtime.

On Windows, clone to a short writable path with `git -c core.longpaths=true clone https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity.git C:\lim` (adjust destination). Deep extraction paths can prevent files from being accessed. New diagnostic entry points resolve repository-relative paths; archived records retain historical paths. MATLAB numerical reruns were not performed during publication because startup reported license-service error 5201.

The archive preserves the reviewed grouping rather than providing a tested one-click installation. Consult the README inside each experiment. Place the experiment's code directories and shared dependencies under one common repository root, preserving their internal relative layout. Check historical paths and dataset inputs before running. Do not add all model directories with `genpath`, because model functions share names.

MATLAB and the relevant toolboxes are required; Bayesian optimization uses Statistics and Machine Learning Toolbox and parallel execution uses Parallel Computing Toolbox. Analysis/plotting scripts additionally use Python packages such as NumPy and Matplotlib. This upload does not rerun the experiments or certify their numerical results.

Use the preserved runtime snapshots when auditing an old batch. Comment insertion changes source signatures even though executable statements are unchanged; do not resume old frozen batches using differently hashed working files. Existing experiment limitations and anomalous results are retained. The earlier combined C plotting script also includes superseded A/B sections; only its C sections map to the current thesis.

## Original DynIn and licensing

Original project: [GlobalDynamicsRG/DynIn](https://github.com/GlobalDynamicsRG/DynIn).

The included upstream checkout is DynIn v1.1.0, commit `d109020db87b98ee2b3bb8aeacc5f29ac3f6ef41`. Its original authorship, source notices and [GPL-3.0 license](00_Shared_MATLAB/work/DynIn/LICENSE) are preserved. AI-assisted interpretation of this code does not confer authorship of the original method. This archive does not replace applicable third-party or derivative-code license obligations.

## Provenance

The original archive was prepared from locally retained thesis sources on 27 October 2026; the author's later manually edited submission was not used for that mapping. The v16 supplement adds explicit mappings for its new Section 6.3 and appendix evidence; the retained chapter files under `05_Thesis_Result_Sources` remain historical sources, not the complete v16 manuscript. Raw records retain historical machine paths where originally saved. No numerical data were redacted or regenerated for publication.
