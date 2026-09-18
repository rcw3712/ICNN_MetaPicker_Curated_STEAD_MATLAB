# No-training tutorials

Run commands from `source_verified_v2`. Replace output paths as needed.

## 1. Verify the downloaded package

```powershell
python verify_package.py
python verify_numerics.py --output "$env:TEMP/icnn-v2-numerics"
python demonstrate_contracts.py --output "$env:TEMP/icnn-v2-contracts"
```

Expected: all manifest hashes match; 70 prediction sets on 330 records/221 sources; 1260 metric rows with zero discrepancies; five invalid synthetic cases rejected. Synthetic scores are not scientific results. No MATLAB or waveform inputs are required.

## 2. Replay saved networks on original CSVs

In MATLAB, start with a small smoke subset:

```matlab
addpath('PATH_TO_REPOSITORY/source_verified_v2');
waveDir = 'PATH_TO_ORIGINAL_CSVS';
outDir = fullfile(tempdir,'icnn_v2_replay');
replay_v2(waveDir,outDir,'test','Full3C',42,3,'gpu');
replay_v2(waveDir,outDir,'phasenet','Zonly',42,3,'gpu');
replay_v2(waveDir,outDir,'oof','Full3C',42,3,'gpu');
```

Expected: zero pick/status mismatches for the selected test records and matching feature checksums. The OOF smoke covers three original and three augmented tensors. A model hash failure indicates an altered artifact; a waveform hash failure indicates a different export. A feature checksum failure requires inspection of numerical inputs/hardware and must not be silently accepted as a successful reproduction.

For complete replay, use `Inf` and run one group per MATLAB process to release memory between groups. `test` requires both modes and bases 42/43/44. `phasenet` requires both modes once and runs seeds 42/43/44. `oof` requires both modes and bases 42/43/44. Full replay may take hours; the recorded complete receipts are available without rerunning it.

## 3. Inspect a scientific claim without inference

Open `audit/PriorNumericalReference/expanded_summary.csv` and `expanded_paired_bootstrap.csv` for primary results. Inspect `audit/threshold/threshold_paired_bootstrap.csv` for all 27 settings, `audit/station/station_subset_sizes.csv` for seen/unseen-key counts, and `audit/HistoricalRolesAndManual` for prior roles and metadata-status sensitivity. Retain their qualifiers: fixed split, conditional intervals, historical exposure and exploratory multiple comparisons.
