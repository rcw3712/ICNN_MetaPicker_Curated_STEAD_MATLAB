# Reproducibility Notes

## Computers & Geosciences Submission

This document describes how to reproduce all results reported in the manuscript.

## Fixed Random Seed

```matlab
config.randomSeed = 42;
rng(config.randomSeed, 'twister');
```

Logged automatically to results/logs/random_seed_log.txt and results/logs/config_used.mat for every run.

## Reproduction Steps

| Result | Script | Output |
|---|---|---|
| Metadata + QC | run_qc_and_metadata_build.m | metadata/metadata_master_final.csv, results/qc/qc_report.csv |
| Full3C benchmark | run_experiment_full3C_STEAD.m | results/metrics/metrics_full3C.csv |
| Z-only (PiGraf sim.) | run_experiment_Zonly_STEAD.m | results/metrics/metrics_Zonly.csv |
| Ablation (8 conditions) | run_ablation_study.m | results/metrics/ablation_results.csv |

## Why source_id/event_id Split Is Mandatory

source_id-based split prevents the same earthquake event from appearing in both train and test. If source_id is missing, event_id is used as a temporary fallback, but original STEAD source_id is preferred — this is logged explicitly and should be reported as a limitation if the fallback is in effect (check results/logs and the console warning emitted by splitBySourceID.m).

## Why OOF Prediction Is Mandatory

OOF prediction is mandatory because I-CNN is a meta-learner. The meta-learner must not be trained on base-model predictions generated from events already seen by those base models. generateOOFPredictions.m implements K-fold cross-validation by the same key used in the outer split.

## Why I-CNN Receives Only the Meta-Feature Tensor

I-CNN's input dimensionality (12 or 15 channels) is fixed by buildMetaFeatureTensor.m's output, never by waveform channel count alone. Verify:
```matlab
size(metaTrainFeatures{1}, 2)   % should be 12 or 15, never 3 or 8
```

## Why Z-only Experiments Use Curated STEAD, Not PiGraf

PiGraf data are not used for quantitative validation at this stage because field acquisition currently records only the Z component reliably. The Z-only experiment isolates the effect of losing horizontal information using a fully-labelled benchmark, avoiding confounding from PiGraf's other acquisition-quality issues. Results should be interpreted as an upper bound on expected PiGraf single-channel performance.

## MATLAB Version Compatibility

| Function | Minimum Version |
|---|---|
| convolution1dLayer with DilationFactor | R2021a |
| trainnet | R2023b |
| minibatchpredict | R2023b |

For R2022b or earlier, replace trainnet/minibatchpredict with trainNetwork/predict.

## Checklist Before Submission

- [ ] config.randomSeed = 42 unchanged
- [ ] run_qc_and_metadata_build.m completes, metadata_master_final.csv produced
- [ ] run_experiment_full3C_STEAD.m completes, metrics_full3C.csv produced
- [ ] run_experiment_Zonly_STEAD.m completes, metrics_Zonly.csv produced
- [ ] run_ablation_study.m completes, ablation_results.csv produced
- [ ] results/logs/random_seed_log.txt and config_used.mat present
- [ ] demo_small_subset.m runs end-to-end without errors
- [ ] Manuscript states whether source_id or event_id fallback was used for splitting
- [ ] Manuscript explicitly states PiGraf was NOT used for quantitative validation
- [ ] Data availability statement references the public STEAD repository and the curation filter version (config.filter.version)
