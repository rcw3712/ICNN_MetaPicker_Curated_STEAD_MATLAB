# Ablation scripts — standalone route (no patching of src/)

## Why this route

`run_export_oof_meta_features.m` (v1) called `generateOOFPredictions`, whose archived
version has a broken line 174:

```matlab
[metaTrainFeatures, metaTrainLabels] = buildMetaFeatureTensor(oofPreds, trainValData, config);
```

`buildMetaFeatureTensor` is a **single-record** function, so this raises
`Unsupported basePredictions format: cell`. Patching that file in place proved fragile —
MATLAB kept resolving an unpatched copy even when the folder appeared to contain only one.

**These scripts therefore never call `generateOOFPredictions` at all.** Nothing inside
`src/` needs to be edited, renamed, or backed up. Just put the three root-level scripts in
the project root and run them.

---

## Run order

```matlab
run_recover_oof_from_fold_models    % rebuild OOF from saved fold models (no retraining)
run_export_oof_meta_features_v2     % assemble the meta-feature cache
run_metalearner_ablations           % produces the CSV to send back
```

### Step 1 — `run_recover_oof_from_fold_models`

Reuses `results/models/trained_base_models/fold01..05_models.mat`, already written by your
earlier runs, and performs **inference only**. It recomputes the fold assignment and
verifies the fold sizes against `EXPECTED_FOLD_SIZES`, currently:

```matlab
EXPECTED_FOLD_SIZES = [614 640 628 602 628];
```

Both of your runs produced exactly these sizes, confirming the assignment is deterministic.
If they ever fail to match, the script aborts rather than pairing fold models with a
different fold assignment, which would silently break the leakage-free guarantee.

Writes `oof_predictions_checkpoint.mat` (now including `trainKeys` for order verification).

### Step 2 — `run_export_oof_meta_features_v2`

Loads that checkpoint plus `base_models_final.mat`, assembles the 15-channel training
tensors itself in canonical channel order, and builds validation/test tensors via
`buildMetaFeatureFromModels`. Verifies both record **count** and record **order** against
the checkpoint before proceeding.

Writes `results/predictions/oof_meta_features.mat`.

### Step 3 — `run_metalearner_ablations`

The only step that produces reportable numbers:

```
results/ablation_metalearner/ablation_metalearner_f1.csv
```

| Variant | Input | Question it answers |
|---|---|---|
| `probonly_12ch` | channels 1–12 | Do the conditioned E/N/Z context channels contribute? |
| `waveonly_3ch` | channels 13–15 | Is the meta-learner fusing base-picker output, or re-learning to pick from the waveform? |
| `nodilation` | channels 1–15, dilations `[1 1 1]` | Does the multi-scale dilated structure matter? (single-scale CNN control, RF 21 vs 33 samples) |
| `logistic` | channels 1–15 | Does a *linear* stacker suffice? |
| `weighted_ens_INSAMPLE` | base-picker probabilities | Diagnostic only — weights fitted in-sample, see below |

F1 uses `src/f1_audit/evaluateConventionalEventF1.m`, the same conventional definition as
Table 4 and Supplementary Table S2, so the numbers drop straight into a comparison table.

---

## Runtime — why the earlier runs were slow, and what changed

The bottleneck was never neural-network training. It is the per-record work every route
repeats:

- `runAICPicker` recomputes `var(trace(1:k))` and `var(trace(k+1:N))` **from scratch**
  inside a 1,000-iteration loop, twice per record. Each iteration also *copies* a slice of
  roughly 5,500 doubles, so a single fold moves billions of elements.
- `runSTALTAPicker` calls `mean()` inside a ~5,900-iteration loop, twice per record.
- `predictBaselineCNNPicker` / `predictTCNPicker` call `minibatchpredict` **one record at a
  time** rather than in batches.

Steps 1 and 2 now use local **fast pickers** that express exactly the same formulas with
prefix sums — O(N) instead of O(N × window). They are defined as local functions inside the
scripts, so nothing in `src/` is modified.

### Correctness of the fast pickers

They were checked against the originals on 30 synthetic 6,000-sample traces: maximum value
difference `6e-11` (AIC) and `1e-12` (STA/LTA), with **zero** differences in the picked
index. On top of that, each script calls `verifyFastPickers` on **your first real record**
before doing any work and **aborts** if any peak index moves. If you would rather not use
them, set `USE_FAST_PICKERS = false` at the top of either script.

### Timing output

Step 1 now prints elapsed time per phase and a summary:

```
[Timing] STA/LTA + AIC :   ... s
[Timing] CNN inference :   ... s
[Timing] TCN inference :   ... s
```

If the picker line is now small and inference dominates, the next fix is batching
`minibatchpredict` instead of calling it once per record — send the timing summary and that
can be done next.

---

## Pre-existing bugs documented (not silently worked around)

1. **`generateOOFPredictions.m` line 174** — batch call to a single-record function; also
   mis-assigns the 2nd output (`featureNames`) to `metaTrainLabels`, and its struct branch
   expects fields `staLta/aic/cnn/tcn` while `oofPreds` uses flat fields (`P_stalta`, …).
   `run_experiment_full3C_STEAD.m` calls it the same way, so **the archived code cannot
   reproduce the locked results as-is** — the locked numbers predate the rewrite of
   `buildMetaFeatureTensor` from a batch to a single-record function. The locked results
   are not numerically invalidated, but this is worth a release note.

2. **`runMetaLearnerBenchmarkFromOOF.m`** contains `picks2=picks1;`, making its
   "Weighted Mean" row a verbatim copy of the unweighted mean ensemble — which is why those
   two rows are byte-identical in `benchmark_summary_final.csv`.

3. **`runWeightedEnsemble`** fits weights on the same set it evaluates and never returns
   them, so running it on test is optimistically biased. Hence the `INSAMPLE` label. The
   publishable weighted-ensemble number is the out-of-sample one already in Supplementary
   Table S6.

---

## Sanity checks

1. `exportInfo` should show train/val/test = **3112 / 343 / 335** and `C_meta = 15`.
2. Step 2 verifies record count *and* order against the checkpoint.
3. Step 3 re-seeds with `config.randomSeed` before each variant, so variants differ only in
   inputs and dilation setting, not weight initialization.
