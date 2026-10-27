# Revision diagnostics and per-damping statistics

This directory accompanies v13. It adds evidence without replacing the original algorithms or numerical results in directories 00--05. These are diagnostic experiments, not a corrected classifier or a new fair-speed comparison.

## Recorded environment

The completed diagnostics used **MATLAB 25.2.0.3177638 (R2025b) Update 5 on Windows**, read from saved `diagnostic_settings.mat` / `environment.mat` records. The original six-model comparison's `study_definition.mat` records the same version. This does not infer the runtime of every other historical batch.

- The 90-case experiment requires **Parallel Computing Toolbox** and a local **process** pool. It retains `parfor` over model/seed cases; each search and its cache remains sequential and isolated.
- Replays use MATLAB's `ode45`, `ode113`, tables and Java hashing. No BO is performed in these diagnostics.
- Original BO training additionally requires **Statistics and Machine Learning Toolbox**, but the Python statistics do not.
- Portable B statistics were checked with **Python 3.12.14 and NumPy 2.3.5**. Install `05_B_PerAlpha/requirements.txt` in your Python environment. Other versions have not been tested.

## Download and paths

Download the **whole repository**, not this folder alone. On Windows use a short writable destination and enable Git long paths at clone time:

```text
git -c core.longpaths=true clone https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity.git C:\lim
```

Replace the destination as necessary. Git long paths do not remove MATLAB/Windows path-length restrictions. Deep Desktop/OneDrive extraction paths can fail. Do not flatten archived directories or add all model folders with `genpath`.

The original 360-run input batch is already in the repository at:

`04_Method_Comparison/02_Raw_Data/Six_Models_360_Runs/outputs_sampled_forward_full_20261018_204956_915`

The four `START_*.m` entry points locate it relative to their own files. Only path wiring changed for publication; numerical functions and settings did not. MAT records and logs retain historical paths as provenance; entry points override necessary runtime model/input paths.

## Entry points and evidence

| Folder | Entry point | Recorded run | Purpose |
|---|---|---|---|
| `01_Label_Provenance` | `START_DIAGNOSTICS.m` | `20261028_023202_960` | Inventory 90 runs; replay nine representative cases and independently reintegrate decisive/provenance states |
| `02_Negative_Cache_9` | `START_RETEST.m` | `20261028_033020_151` | Nine original-control / no-negative-cache pairs |
| `03_Negative_Cache_90` | `START_ALL90_PARFOR.m` | `20261028_040701_540` | Three models, seeds 1:30; 90 control/ablation pairs (180 searches), using parfor |
| `04_Query567` | `START_QUERY567_DIAGNOSTIC.m` | `20261028_044710_303` | QC seed 30, query 567 replay; no rule correction |
| `05_B_PerAlpha` | `analyze_existing_data.py` | `recorded/` | Baseline/candidate median, P95, max and error >50% fraction from 4,800 run rows |

Open a MATLAB entry file and press Run. Defaults preserve recorded numerical settings. Outputs use a **new timestamped** `results/` subdirectory, never the original batch. The 90-case entry uses the existing local process pool or profile default; set `options.numWorkers` before creating a new pool to choose a worker count. It does not close an existing pool automatically.

From the repository root, run:

```text
python 06_Revision_Diagnostics/05_B_PerAlpha/analyze_existing_data.py
```

Outputs go to `05_B_PerAlpha/reproduced_results`. An existing destination causes refusal rather than overwrite; use `--output <new-folder>` to choose another. Inputs are the four CSV exports under `05_Thesis_Result_Sources/source_data/experiment_B_multi_alpha`. This calculation needs no MATLAB, ODE integration or B1 Release download.

## Complete diagnostic records

All MAT/CSV/log files and source snapshots are in the [diagnostics Release](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/tag/diagnostics-2026-10-28). `recorded_summaries/` contains unchanged CSV/text/log evidence for browsing, not a substitute for full MAT records.

- [Label-provenance records](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/diagnostics-2026-10-28/01_Label_Provenance_Complete_Records.zip)
- [Nine-case ablation records](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/diagnostics-2026-10-28/02_Negative_Cache_9_Complete_Records.zip)
- [All-90 parfor records](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/diagnostics-2026-10-28/03_Negative_Cache_90_Complete_Records.zip)
- [Query 567 records](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/diagnostics-2026-10-28/04_Query567_Complete_Records.zip)
- [SHA-256 checksums](https://github.com/Nick-Zhengkang/Zhengkang-Qian-Dynamic-Integrity/releases/download/diagnostics-2026-10-28/SHA256SUMS.txt)

Extract ZIPs into the **repository root**; each has a `06_Revision_Diagnostics/.../results/<timestamp>/` prefix. Query 567 requires extracted all-90 records at `03_Negative_Cache_90/results/20261028_040701_540`, including its source snapshot and seed-30 MAT files. Other MATLAB entries can start from the original comparison batch without diagnostic Releases. B's older raw-data Release remains unchanged.

## Verification and limits

From the repository root:

```text
python 06_Revision_Diagnostics/check_download.py
python 06_Revision_Diagnostics/check_download.py --require-records
```

The first checks portable entries, 90 original MAT files, models/dependencies, engine identities, the exact two-line ablation and B input hashes. The second also requires all four Releases extracted and verifies every record against `PRESERVED_FILES_SHA256.csv`. The manifest holds original bytes; four path-relocated drivers are explicitly excluded from original-byte equality.

`PREFLIGHT_MATLAB.m` provides a MATLAB-side path/source check without ODE integration. The publication session could not execute it because MATLAB startup reported MathWorks license-service error **5201**. Path checks and Python reproduction are **not** a fresh MATLAB numerical rerun. See `PUBLICATION_CHECKS.json` for verification scope.

All failures are retained: no ablation estimate fell below the reference in these 90 runs, but only 89/90 final defining points were independently supported as non-target. QC seed 30 remained a false fixed-point classification. This is not complete classification validation and does not diagnose Experiment B or four-dimensional failures.

## Provenance and AI assistance

Diagnostic implementation was AI-assisted under the author's direction; attribution comments are retained. Original Habib code and frozen engines retain their authorship and bytes. New portability/check scripts are AI-assisted infrastructure, not classification changes. `05_B_PerAlpha/recorded/analyze_existing_data.py` is the exact original script; its portable sibling changes input/output routing and integrity-check scope, not statistics. The author executed the recorded MATLAB runs; publication generates no replacement experimental data.
