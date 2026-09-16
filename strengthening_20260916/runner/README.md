# Fixed-split seed repeats and a matched PhaseNet-style baseline

New experiment package, separate from frozen submission40 / v1.2.0.
Defaults: **66 additional fits**, sequential, fresh MATLAB process for each
base-seed/mode pipeline and each baseline fit. No full training starts by opening files.

PowerShell, from this folder:
```
.\run_strengthening.ps1 -Action Plan
.\run_strengthening.ps1 -Action Smoke
.\run_strengthening.ps1 -Action Train
.\run_strengthening.ps1 -Action Summarize
```
MATLAB smoke alternative: `smoke_strengthening('gpu')`.
Requires MATLAB R2024a, Deep Learning Toolbox, existing project data/toolboxes.
GPU execution also requires the existing supported GPU setup.

## Seed experiment
Two new CNN/TCN base seeds, 43 and 44. For each, both modes, five OOF
CNN/TCN pairs, one final CNN/TCN pair, then full15ch meta seeds 42/43/44.
15 fits per base/mode = 60 fits. Original base42 results remain in their
frozen directory and are included read-only by the summary script.
No old base42 OOF predictions are reused. Each output root is seed/mode-specific;
the code/data/config manifest is checked before checkpoint reuse.
Outer source split, OOF seed42, inner split seeds101:105, fold augmentation
seeds1001:1005, final/OOF augmentation seed4242 remain fixed. This estimates
initialization variability conditional on one source split, not split robustness.
CNN and TCN share the specified base seed by design; meta seeds form a crossed
3-seed factor, independent of the base-seed choice. Do not treat all meta fits
sharing a base as independent full-pipeline replicates.
No ablation reruns are included.

## Modern baseline: PhaseNetMatched
This is a **PhaseNet-style MATLAB adaptation**, trained from scratch, not the
official PhaseNet implementation and not pretrained PhaseNet performance.
Architecture reference: SeisBench PhaseNet (accessed 2026-09-15):
https://github.com/seisbench/seisbench/blob/main/seisbench/models/phasenet.py
Zhu & Beroza (2019), https://doi.org/10.1093/gji/ggy423.
Five encoder levels, filters8/16/32/64/128, kernel7, stride4, BN(eps1e-3),
ReLU, transposed convolution and skip concatenation. MATLAB same padding and
center-cropped skips support full 6000-sample records; these differ from the
reference implementation's explicit asymmetric padding. MATLAB default
initialization, convolution biases and BN momentum also differ. No dropout.
Use the exact label above when reporting; a reviewer may still request the
official implementation or another stronger comparator.

Three seeds42:44 per mode = six fits. Input is conditioned E/N/Z waveform,
the same values as meta channels13:15, without a second normalization;
Zonly zeros E/N. Same frozen records, Gaussian labels, training augmentation,
weighted soft-target cross entropy, outer validation checkpoint selection,
and original MATLAB decoder/evaluation. Input features differ by design:
the standalone network receives three waveforms, not base-score meta inputs.
Adam, 50 epochs maximum, lr5e-4, batch2, patience10, LRhalf every20epochs,
L2=1e-4. Small batch reduces memory; optimizer-step budget and BN statistics
therefore differ from batch16 stacking. This is data/protocol matching, not
compute-budget or architecture equivalence. No test-set tuning is allowed.

## Memory and provenance
Baseline datastore casts observations to single per batch. Training data and
augmentation still reside in CPU RAM; smoke success is not a guarantee of
whole-dataset memory capacity. Baseline test data is parked on disk until
training finishes. Repeats retain the proven record-streamed OOF implementation.
Stop on error, close the failed MATLAB process, inspect the log, then resume
the same command. Saved models are verified; interrupted fits restart from
scratch. Never edit code/config inside a partially completed experiment:
manifest mismatch deliberately requires a new output directory.

The summary exports per-fit metrics and paired source-cluster intervals for
Full3C minus Zonly. It reports missing evaluations rather than manufacturing
complete tables. Analyze the retained meta-within-base
dependence before revising manuscript claims. Fixed-split repetitions do not
establish geographic, station, dataset or source-split generalization.

## Validation completed on 2026-09-15
MATLAB R2024a / RTX 3060 Laptop GPU: synthetic one-batch training, prediction,
6000-sample output, probability sums, checkpoint save/load passed in both modes.
Two real training records plus their augmented copies also passed preprocessing,
augmentation, one-epoch training and the unchanged decoder in both modes.
These are functional smoke tests, not scientific results or full-run RAM tests.

Summary automatically reads the existing base42 evaluation CSVs read-only from
`C:\Drive E\ICNN_submission_results\submission40_v5_oofstream` and hashes the
metric inputs. An alternative frozen root can be passed as a second argument
of `summarize_strengthening`. It reports the 3x3 base/meta grid, per-base meta
averages, paired mode intervals, and stack-minus-baseline intervals for each
base/meta combination. These intervals do not correct for multiple comparisons
and do not incorporate training variability. Do not select favorable seeds.
