# User guide

## Installation and requirements

Clone the repository normally. The active package is `source_verified_v2`; do not add the historical root `src` to the MATLAB path.

- Python 3.10 or later, standard library only: package verification, numeric recomputation and synthetic contracts.
- NumPy and h5py: optional waveform inspection; see `requirements.txt`.
- MATLAB R2024a, Deep Learning Toolbox and Signal Processing Toolbox: model loading, waveform conditioning and replay. GPU execution additionally requires Parallel Computing Toolbox and a supported CUDA GPU. The custom `PhaseSkipCrop` layer is included under `training/strengthening/clean`.
- The recorded replay used an RTX 3060 Laptop GPU with 6 GiB VRAM. The author's machine had 32 GiB system RAM and an enabled pagefile. These are a reference configuration, not measured minimum requirements. Use one MATLAB process at a time. No claim of bitwise portability across hardware or MATLAB versions is made.

## Inputs and outputs

`inputs/partition_membership.csv` maps ordinal local event filenames to original STEAD trace names and source IDs. Read source IDs as text. `inputs/metadata/metadata_verified.csv` retains upstream annotation status and station keys. Labels remain historical CSV labels, floor(upstream arrival sample)/100; neither manual status nor this recovered mapping establishes independent manual re-picking.

The fixed split has train/validation/test record counts 1544/360/330 and source counts 1034/222/221. Five OOF folds hold out complete training sources; inner-validation memberships are frozen in `inputs/folds`. Modes and seeds share this partition. The 106 fits comprise 40 main/ablation, 60 additional base/meta and six PhaseNet-style fits.

Original waveform CSVs are not bundled. Exact replay requires all selected CSV bytes from `inputs/waveform_hashes.csv`; columns are `time,sec,E,N,Z,p_arrival,s_arrival`, 6000 rows at 100 Hz. For a smoke test only the selected records are needed. Upstream data are available from [STEAD](https://github.com/smousavi05/STEAD) under its distribution terms. The mapping identifies retained waveforms; the historical extraction notebook/selection recipe is unavailable. A newly formatted CSV can represent the same float32 waveform but differ in parsed double precision or time-grid rounding, so the exact replay command rejects changed file hashes. Do not claim that an arbitrary re-export reproduces these artifacts. The published outputs support numerical review without external waveforms; synthetic tests support software inspection without STEAD.

`model_manifest.csv` identifies every checkpoint by mode, kind, base/meta seed and fold, with SHA-256. `test_jobs.csv` identifies each of the 70 output sets. `results` contains their original predictions and metrics. `feature_hashes` contains column-major little-endian float32 SHA-256 values from existing OOF/test caches. `audit/Replay` preserves original receipts and hash checks; paths in historical receipts describe the author's machine and are not executable configuration.

## No-training commands

Run `python verify_package.py` for byte integrity, `python verify_numerics.py --output OUT` for the 1260 metric rows, and `python demonstrate_contracts.py --output OUT` for synthetic failure cases. See the tutorial for explicit examples and expected outcomes. Use an output folder outside the package.

In MATLAB, call `replay_v2(waveDir,outDir,stage,mode,base,maxRecords,device)`. Arguments:

| Argument | Values and meaning |
|---|---|
| waveDir | Folder of original, hash-matching waveform CSVs |
| outDir | New writable folder outside the published package |
| stage | `test`, `phasenet`, or `oof`; never training |
| mode | `Full3C` or `Zonly` |
| base | 42, 43 or 44; use 42 for the phasenet group, which loads all three baseline seeds |
| maxRecords | Positive integer for smoke checks; `Inf` for the complete group |
| device | `gpu` (default) or `cpu`; cross-device equivalence is not guaranteed |

Six `test` groups and two `phasenet` groups cover all 70 test outputs. Six `oof` groups cover 18,528 tensors, regenerating augmentation with seed 4242 and the stored record order. The replay uses the saved validation ensemble weights without refitting. It never chooses thresholds, checkpoints or network weights. Pick tolerance is 1e-7 s. Feature hashes require exact bytes and are stricter than the original 1e-6 numerical-tolerance audit; a hash mismatch alone is not a measurement of numerical error. Stop and inspect a mismatch instead of changing the expected hashes.

Outputs include record-level predictions, decoder status/pick comparison receipts, model loading records and feature checks. The original complete replay remains in `audit`; portable smoke checks are separate in `verification`.

## Optional training on a new output root

No training is needed to inspect the supplied results. To intentionally retrain, first run `python prepare_runtime.py --waveforms WAVE_DIR --output NEW_PROTOCOL_DIR`. It verifies all original waveform hashes, copies the frozen inputs and records the path relocation without changing split/fold membership. Then call `training/run_verified.ps1 -Action TrainMain -SourceRoot NEW_PROTOCOL_DIR -ResultsRoot NEW_RESULTS_DIR`, followed by `TrainStrengthening` using the same arguments. The default action is `Plan`; `Validate` checks the protocol without fitting.

Use separate new output directories. The published source differs from the execution source only in cleaned comments for eight configuration/loader files; `provenance/code_copy_manifest.csv` and the reversible comment patch record that change. Statements and parameter values are retained. Code signatures therefore differ, so the published runner must not resume or overwrite the original author's training directory. Path relocation also changes the signature. New fits are new runs; no retraining determinism is claimed.

Legacy `config.filter` values are inert descriptive fields (`reapplyAtLoad=false`) and do not describe the recovered population. The verified entry point uses the frozen membership and preserves CSV labels. Use the recovered metadata and manuscript Table 1, not those legacy values, to describe selection. Configuration defaults for the old spreadsheet are overridden by the verified runner.

## Interpretation and limits

All intervals are conditional on fixed fits and this fixed split; source bootstrap intervals exclude training/split uncertainty and are not multiplicity-adjusted. Manual-status sensitivity is a metadata stratum. Historical development exposure prevents an independent-confirmation claim. Station keys combine network and receiver codes, not station epochs; 12 unseen-key records do not establish transfer.

The primary decoder uses peak 0.30, quality 3 and maximum S–P window 30 s. Documentary continuity does not prove validation-only initial calibration. The 27-setting sensitivity grid did not select a new threshold. Under accepted scoring, quality settings are redundant and leave nine peak/window combinations. Strict Z-only S intervals favour the baseline in 18/27 settings, so the unresolved primary S comparison must not be generalized to every scoring policy.

## License and archive scope

Software is MIT licensed. Upstream STEAD metadata/waveforms retain upstream terms. Manuscript/artwork are accompanying research materials. No existing release DOI is asserted for corrected v2. Use the Git commit and package manifest until a corrected archival release is published.
