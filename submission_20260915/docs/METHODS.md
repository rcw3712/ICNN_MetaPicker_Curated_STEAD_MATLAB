# Method and implementation correspondence

## Training membership

Outer training: 1,480 source IDs / 1,556 records. Outer validation: 317 / 343. Test: 317 / 335. Lists in `inputs/results/splits` partition all sources. Records from one source stay together. Source identity is not a station- or region-disjoint design.

Five OOF folds are drawn from outer training. For each held fold, approximately 15% of non-held sources are inner validation; the remainder fits that fold's CNN/TCN. Neither fitting nor checkpoint selection uses held sources. Each held original and its augmented copy is evaluated by the corresponding fold models. Final CNN/TCN weights fit augmented outer training; outer validation chooses checkpoints. These final bases supply meta-validation and test features. Meta fitting uses OOF training features; outer validation again selects the meta checkpoint. Ensemble coefficients also use outer validation. This reuse is documented and is not an independent nested validation estimate. No claim about undocumented historical threshold selection is added: the fixed configuration values, rather than a newly optimized threshold set, define the reported protocol.

## Architecture and loss

`runner/clean/fitClean.m` is authoritative. CNN has two blocks (32/64, kernel 7); TCN uses the first four configured dilations (1/2/4/8), four 32-filter blocks, kernel 3. I-CNN uses four blocks (64/128/64/64, kernel 5, dilations 1/1/2/4). Each block is convolution → batch normalization → ReLU → dropout. The head is 1×1 convolution → softmax. No-dilation uses 1/1/1/1. The generic legacy configuration arrays do not override these explicit shapes.

All neural models use Adam, L2 1e-4, LR drop factor 0.5 every 20 epochs, validation once per epoch, and best-validation-loss output. Base LR/max epochs/patience: 1e-3/30/7. Meta: 5e-4/50/10. Batch size 16. Meta soft targets are weighted P/S/noise 1.5/2.5/0.5 before cross-entropy; base targets have unit weights. Gaussian widths 6/8 samples, truncation ±4σ; noise is 1−max(P,S), without additional target-sum normalization.

## Decoder

`runner/clean/decodeClean.m` selects earliest maximum on ties. P searches the whole record. Accepted P anchors S to 0.1–30 seconds afterward within the record; no accepted P means no S. A peak is detected if probability ≥0.30 and peak/(mean probability in the search domain + 1e-6) ≥3; otherwise uncertain at probability ≥0.15. Primary acceptance includes detected and uncertain. Detected-only is a scoring mask applied after decoding and does not redefine the P gate.

Both time conversion directions are explicit: zero-based sample n → MATLAB n+1; MATLAB index j → (j−1)/100 seconds. True arrival times are read from CSVs. The unconstrained comparison changes both S search and quality domain; it cannot isolate only the P gate.

## Uncertainty and new diagnostics

`analysis/audit_metrics.py` recomputes primary metrics and paired intervals from predictions. Bootstrap uses 317 source clusters, 10,000 multinomial resamples with NumPy default_rng(42), the same resamples for both modes, and averages per-seed F1 in every draw. Models/split are fixed. Ablation intervals are exploratory without multiplicity correction; neither equivalence nor full algorithmic uncertainty is claimed.

`analysis/diagnostics.py` computes detected-only means/SD and conditional S performance. P rejection affects 1/1/1 Full3C and 1/2/1 Z-only cases; no corresponding ungated S is correct at 100 ms. Conditional subsets change denominators and do not replace primary metrics.

`analysis/metadata_coverage.py` parses network code from trace_name and combines it with receiver_code. These are identifiers, not coordinates or verified station epochs. No geographic coverage is invented.

## Assistance and limits

AI tools assisted software changes, execution and checks, and document preparation. Figures are deterministic plots of data/model outputs, not generated-image synthesis. Source assertions, hashes, and independent metric recalculation support verification. Author responsibility and final scientific review remain essential. Full-pipeline multi-seed/multi-split, independent-dataset, and operational continuous-data evaluations have not been added.
