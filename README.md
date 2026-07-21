# Leakage-Free I-CNN Meta-Learning Framework for Seismic Phase Picking

[![MATLAB](https://img.shields.io/badge/MATLAB-R2024a-blue.svg)](https://www.mathworks.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Journal](https://img.shields.io/badge/Target-Computers%20%26%20Geosciences-orange.svg)](https://www.sciencedirect.com/journal/computers-and-geosciences)

> Software accompanying the manuscript **"Leakage-Free Temporal Meta-Learning for Seismic Phase Picking: An I-CNN Framework with Source-Level Validation"**, submitted to *Computers & Geosciences*.

---

## 1. Purpose

This repository implements a two-level stacking ensemble (I-CNN MetaPicker) for automatic P- and S-wave phase picking. Four level-1 base pickers (STA/LTA, AIC, a baseline CNN, and a dilated TCN) each produce P/S/Noise probability curves; a level-2 Integrated CNN (I-CNN) meta-learner fuses these, together with conditioned three-component waveform context, into a final pick. A deterministic physics-aware constraint layer is applied afterward as a deployment safeguard only (it does not alter reported test metrics).

## 2. Data

The framework is trained and evaluated on a curated subset of the STanford EArthquake Dataset (STEAD; Mousavi et al., 2019), filtered to:

| Filter | Threshold |
|---|---|
| `trace_category` | local earthquake |
| `source_distance_km` | ≤ 15 |
| `source_magnitude` | ≥ 1.5 |
| `min_snr_db` | ≥ 10 |
| `p_status` / `s_status` | manual |

This yields **2,234 three-component waveform records from 2,114 unique earthquake sources**. Splitting is performed at the `source_id` level (not the trace level) to guarantee zero earthquake-source overlap between Train (1,480 sources / 1,556 records), Validation (317 sources / 343 records), and Test (317 sources / 335 records).

Raw STEAD waveforms are not redistributed in this repository (see [Data availability](#7-data-availability)); the curated metadata table and derived split assignments used to reproduce this study are included under `metadata/` and `results/splits/`.

## 3. Canonical 15-channel meta-feature tensor

The I-CNN meta-learner consumes a canonical tensor `Z_meta ∈ ℝ^(6000×15)`, with channels in this fixed order:

```
1  P_STA        6  Noise_AIC     11 S_TCN
2  S_STA        7  P_CNN         12 Noise_TCN
3  Noise_STA    8  S_CNN         13 E_conditioned
4  P_AIC        9  Noise_CNN     14 N_conditioned
5  S_AIC        10 P_TCN         15 Z_conditioned
```

Channel count and ordering are validated automatically at runtime; execution halts if a mismatch is detected.

## 4. Repository structure

```
ICNN_MetaPicker_Curated_STEAD_MATLAB/
├── main_ICNN_MetaPicker.m           Top-level entry point
├── config/config_ICNN_MetaPicker.m  Central configuration (paths, seed=42, hyperparameters)
├── run_qc_and_metadata_build.m      Step 1: metadata build + QC        <- run first
├── run_experiment_full3C_STEAD.m    Step 2a: Full 3C experiment
├── run_experiment_Zonly_STEAD.m     Step 2b: Z-only experiment
├── run_ablation_study.m             Physics-aware ablation
├── runConventionalF1Audit.m         F1-definition audit (conventional TP/FP/FN vs legacy)
├── runMetaLearnerBenchmark.m        I-CNN benchmark reproducibility check
├── runBenchmarkConsistencyCheck.m   Cross-checks benchmark against locked results
├── run_post_evaluation_diagnostics.m  Percentile / SNR-stratified / failure-case diagnostics
├── run_generate_all_figures.m       Regenerates all publication figures from existing results
├── run_reviewer_modules.m           Additional reviewer-requested diagnostics
├── src/
│   ├── data_loading/    CSV/metadata loading and validation
│   ├── qc/              Waveform quality control
│   ├── splitting/       Source-level train/val/test partitioning
│   ├── preprocessing/   Waveform conditioning
│   ├── labeling/        Gaussian arrival-time probability labels
│   ├── augmentation/    Training-only waveform augmentation
│   ├── base_pickers/    STA/LTA, AIC, CNN, TCN implementations
│   ├── oof_stacking/    Out-of-fold prediction + meta-feature tensor construction
│   ├── meta_learner/    I-CNN training and inference
│   ├── physics_picker/  Physics-aware deployment safeguard
│   ├── evaluation/      Conventional-F1 metrics, detection rate, percentile errors
│   ├── f1_audit/        F1-definition audit routines
│   ├── benchmark/       Meta-learner benchmark + consistency checks
│   ├── diagnostics/     SNR-stratified, failure-case, percentile diagnostics
│   ├── ablation/        Physics-aware ablation study
│   └── visualization/   All Fig. 2-12 / Supplementary Fig. S1 plotting scripts
├── examples/            Minimal usage demos (single CSV, small subset, synthetic waveform)
├── data/csv_stead_filtered/   Place curated STEAD CSV files here (not included; see §7)
├── metadata/             Curated metadata table (included)
├── results/
│   ├── splits/           Source-level train/val/test source_id assignments (included)
│   ├── metrics/, predictions/, diagnostics/, f1_audit/, benchmark/, ablation/  (included)
│   └── figures_publication/   Regenerated 300 dpi PNG/TIFF/PDF figures + captions
├── docs/                 Workflow description, data format, reproducibility notes, method notes
├── PATCH_CHANGELOG.md    Changelog of visualization-script fixes (rendering/data-source bugs)
├── LICENSE               MIT
└── CITATION.cff          Citation metadata
```

## 5. Running the pipeline

```matlab
run_qc_and_metadata_build      % 1. Build/validate metadata, run QC
run_experiment_full3C_STEAD    % 2. Full 3C experiment
run_experiment_Zonly_STEAD     % 3. Z-only experiment
run_ablation_study             % 4. Physics-aware ablation
runConventionalF1Audit         % 5. F1-definition audit
run_post_evaluation_diagnostics % 6. Percentile / SNR-stratified / failure-case diagnostics
run_generate_all_figures       % 7. Regenerate all publication figures + captions
```

All experiments use `config.randomSeed = 42`. Steps 2-6 write their outputs under `results/`; step 7 reads those cached results and does **not** retrain anything, so it can be re-run quickly after any visualization fix.

## 6. Reproducing the published results

`results/f1_audit/f1_conventional_summary.csv` and `results/diagnostics/percentile_metrics/percentile_metrics_{Full3C,Zonly}.csv` contain the exact locked values reported in the manuscript's Tables 4-5 and Supplementary Tables S2/S4. `results/splits/{train,val,test}_source_ids.csv` document the exact source-level partition (zero overlap, verified programmatically).

## 7. Data availability

Raw STEAD waveforms are publicly available from the original authors (Mousavi et al., 2019) and are not redistributed here. The curated metadata table, source-level split assignments, model predictions, and all intermediate results needed to reproduce the manuscript's figures and tables are included in `metadata/` and `results/`.

## 8. License

MIT License — see [LICENSE](LICENSE).

## 9. Citation

See [CITATION.cff](CITATION.cff).
