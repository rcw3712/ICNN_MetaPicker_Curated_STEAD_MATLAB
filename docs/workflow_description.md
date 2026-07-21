# Workflow Description

## Pipeline Overview

```
2,234 filtered STEAD CSV files (data/csv_stead_filtered/)
              |
              v
   buildMetadataFromCSVFolder.m / loadFilteredSTEADCSVFolder.m
   (read or build metadata_master_latest.csv)
              |
              v
   qcSingleCSVWaveform.m -> qcWaveformDataset.m
   (NaN/Inf, flatline, length, sec monotonicity/delta, arrival bounds,
    S-P time, quality_flag assignment, qc_report.csv)
              |
              v
   splitBySourceID.m (fallback: splitByEventID.m)
   (train/val/test split, zero ID overlap guaranteed)
              |
              v
   conditionWaveform.m
   (demean, detrend, bandpass [1,45]Hz, normalize, optional clip)
              |
              v
   buildEnhancedRepresentation.m
   (optional: envelope, short-term energy, STA/LTA characteristic
    function -> 8-channel X)
              |
              v
   generateGaussianMasks.m
   (P_mask, S_mask, Noise_mask from p_arrival_sec / s_arrival_sec)
              |
              +-- (training only) augmentTrainingWaveform.m
              |   (additive noise, scaling, time shift, channel dropout,
              |    polarity flip)
              v
   +------------------------------------------------------------+
   |              LEVEL 1 - BASE PICKERS                         |
   |  runSTALTAPicker.m | runAICPicker.m | trainBaselineCNN...   |
   |                    |                | trainTCNPicker.m      |
   |  Input: conditioned/enhanced waveform X [T x C]              |
   |  Output: probability curves [P, S, Noise] per picker         |
   +------------------------------------------------------------+
              |
              v
   generateOOFPredictions.m
   (K-fold by source_id/event_id; leakage-free meta-feature generation)
              |
              v
   buildMetaFeatureTensor.m
   Z_meta(t) = [P_STA,S_STA,N_STA, P_AIC,S_AIC,N_AIC,
                P_CNN,S_CNN,N_CNN, P_TCN,S_TCN,N_TCN,
                (optional) E_ctx, N_ctx, Z_ctx]
              |
              v
   +------------------------------------------------------------+
   |              LEVEL 2 - I-CNN META-LEARNER                   |
   |  trainICNNMetaLearner.m / predictICNNMetaLearner.m          |
   |  Input: Z_meta(t) [T x C_meta]  <- NEVER waveform alone       |
   |  Output: Y_hat(t) = [P_prob, S_prob, Noise_prob]              |
   +------------------------------------------------------------+
              |
              v
   physicsAwarePicker.m
   (tauP = argmax P_prob; tauS searched only in
    [tauP+minSPTimeSec, tauP+maxSPTimeSec]; quality scores)
              |
              v
   evaluatePickingPerformance.m
   (MAE, RMSE, Bias, SD, Precision/Recall/F1 @ 50/100/200ms,
    separated by: Full3C/Z-only, enhanced/non-enhanced,
    base picker/I-CNN, P/S)
              |
              v
   Outputs: results/{qc,splits,metrics,predictions,figures,models}/
```

## Experiment Modes

| Script | Mode | Purpose |
|---|---|---|
| `run_experiment_full3C_STEAD.m` | Full3C | Primary benchmark, X = [E,N,Z] enhanced |
| `run_experiment_Zonly_STEAD.m` | Z-only | PiGraf-limitation simulation, X = [0,0,Z] |
| `run_ablation_study.m` | All | 8-condition comparison incl. enhanced ablation |

## Key Invariants Enforced

1. **Leakage-free split**: `splitBySourceID.m` raises an error if any split key (source_id or event_id fallback) appears in more than one subset.
2. **OOF-only meta-features for training**: `generateOOFPredictions.m` ensures no training sample's meta-feature was produced by a base model that saw that sample's split-key group during training.
3. **Augmentation confined to training**: `augmentTrainingWaveform.m` is never called on val/test/Z-only-eval data.
4. **I-CNN input is always the meta-feature tensor**: `trainICNNMetaLearner.m` and `predictICNNMetaLearner.m` never accept conditioned waveform as their sole input.
5. **Physics-aware S-wave search window**: `physicsAwarePicker.m` enforces `tauS > tauP` by construction.
