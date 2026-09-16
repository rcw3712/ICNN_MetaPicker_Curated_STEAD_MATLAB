# Model replay and source-grouped workflow contracts

This public-source package closes the model-access gap for the C&G manuscript. It supplies **all 106 trained checkpoints (75,935,748 bytes)**, explicit inference dependencies, checkpoint hashes, frozen reference predictions, provenance evidence, synthetic examples and verification receipts. No training is needed to load the models or run the synthetic demonstrations.

Verify the downloaded package first with `python verify_package.py`. The manifest covers checkpoints, source, input identifiers and verification receipts.

## 1. Run a self-contained example

Python 3.11+ is sufficient; the demonstration uses only the standard library:

```sh
python demonstrate_contracts.py
```

Expected result: five deliberately invalid cases are rejected, augmented records keep their source identity, grouped OOF checks pass, and all 24 published prediction sets have the same 335 records/317 sources. Output: `verification/contract_demo.json`. This is a workflow demonstration, not a performance experiment.

## 2. Load checkpoints and test the actual MATLAB functions

Requirements: MATLAB R2024a, Deep Learning Toolbox and Signal Processing Toolbox. GPU inference additionally needs Parallel Computing Toolbox and a supported GPU. CPU is supported and was tested. The custom `PhaseSkipCrop` layer is supplied. In a fresh MATLAB session, change Current Folder to this package and run:

```matlab
demonstrate_matlab(fullfile(pwd,'verification_local'));
```

Expected result: 106 checkpoints load with matching job IDs; no saved fit/validation source overlaps the held-out test sources; conditioning and decoder boundary checks pass. Checkpoint/source receipts are written to the chosen directory. Use a clean MATLAB path so legacy implementations cannot shadow packaged functions.

## 3. Replay predictions from the saved networks

Set `waveformDir` to the directory containing the identified curated STEAD CSVs. This is the only external input path; no author-specific project folder or private dependency is required.

```matlab
waveformDir = fullfile('YOUR_DATA_DIRECTORY','csv_stead_filtered');
replay_models(waveformDir,fullfile(pwd,'replay_smoke'),3,'cpu');
% Full 335-record replay, without fitting:
replay_models(waveformDir,fullfile(pwd,'replay_all'),Inf,'cpu');
% Replace 'cpu' with 'gpu' if available.
```

The command covers 18 stacker output sets (two modes, three base seeds, three meta seeds) and six PhaseNetMatched output sets. Each stacker rebuilds classical/CNN/TCN features from the waveform, then predicts with its saved meta network. Raw labels are used for scoring and input identity checks, not to generate neural features or select checkpoints. Processing is per record; large training/OOF caches are unnecessary.

Every loaded checkpoint and waveform is SHA-256 checked. Pick times must match to 1e-7 seconds; statuses must match exactly. Quality-score differences are reported separately because floating-point backend changes can alter them. The tested GPU subset is three records per output and CPU subset one; `verification/` contains receipts. Full 335-record model replay has not been claimed as already executed by this revision. All 335-record prediction-table metrics were independently audited previously.

## External data and exactness

Raw waveforms are not redistributed. Obtain the original STEAD data under its distribution terms: https://github.com/smousavi05/STEAD. `inputs/training_inputs/metadata/metadata_master_2234_final.xlsx` maps each curated `event_id` to original `trace_name` and `source_id`. Fixed source assignments are under `inputs/training_inputs/results/splits/`.

Each curated `<event_id>.csv` has 6,000 rows sampled at 100 Hz, with `sec,E,N,Z,p_arrival,s_arrival` (optional `time` is ignored). `sec` is 0:0.01:59.99; arrival columns repeat the authoritative arrival seconds. Horizontal order is E,N followed by Z. The inference functions perform the documented conditioning; do not normalize or filter the input a second time.

`inputs/waveform_hashes.csv` identifies exact historical CSV bytes. The code deliberately stops on mismatched bytes rather than presenting a re-export as exact reproduction. STEAD trace identifiers establish the data source, but byte-identical CSV serialization is not guaranteed by downloading STEAD. Exact replay requires the matching curated exports; synthetic demonstrations and checkpoint access are available without them. This remaining input-distribution limitation is explicit.

## Full training versus saved-model replay

The complete public training implementations remain in `../submission_20260915/runner` and `../strengthening_20260916/runner`. Original source IDs and metadata are supplied here. Place the matching CSVs under `sourceRoot/data/csv_stead_filtered`, and the supplied metadata and split directories under the same `sourceRoot`. Pass all paths explicitly; do not use author-local defaults. In MATLAB:

```matlab
repoRoot = fileparts(pwd);
sourceRoot = fullfile(pwd,'inputs','training_inputs');
addpath(fullfile(repoRoot,'strengthening_20260916','runner'));
run_seed_repeat('plan',sourceRoot,fullfile(pwd,'new_training'),'cpu',43,'Full3C');
% Explicit training, only if wanted:
% run_seed_repeat('train',sourceRoot,fullfile(pwd,'new_training'),'cpu',43,'Full3C');
```

Use fresh output directories and unchanged manifests for resume. This revision performs no new fit. Checkpoints include original ablations and OOF models as well as the final expanded models; the supplied replay entry point targets the 24 expanded output sets, not every original ablation.

## Interpretation and provenance

See `THRESHOLD_PROVENANCE.md` for documentary evidence and its limits, and `COMPUTATIONAL_CONTRIBUTION.md` for reusable interfaces and demonstrated failure cases. Established grouped OOF is not claimed as a new algorithm. No new split, calibration experiment, official-PhaseNet benchmark or superior stacking performance is claimed. The code is MIT licensed; MATLAB and STEAD retain their own licensing terms.
