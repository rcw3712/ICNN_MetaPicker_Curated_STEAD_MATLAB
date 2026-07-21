# F1 Evaluation Audit Report
Generated: 2026-07-16 10:10:01

---

## 1. Executive Summary

This report audits the F1 evaluation definition used in the locked Full 3C and Z-only experiments.
The key question is whether out-of-tolerance predictions are counted as FP only (current)
or as both FP and FN (conventional event-matching, Case B).
MAE is unchanged: it is always computed over detected picks only.
No retraining was performed. No locked predictions were modified.

## 2. Files Used

- predictions_full3C.csv: 335 records
- predictions_Zonly.csv: 335 records
- Source: results/predictions/ (locked, not regenerated)

## 3. Record-Alignment Validation

- 335 test waveform records from 317 unique earthquake sources.
- 335 > 317 reflects expected source-to-trace multiplicity, not leakage.
- Alignment key: event_id (or fallback to file_name / source_id+index).
- All 335 records aligned successfully.

## 4. Existing Locked F1 Definition

Source file: src\evaluation\computeDetectionMetrics.m
Outside-tolerance handling: **FP_ONLY (FN counts only missing predictions, not out-of-tolerance)**
FN denominator: UNKNOWN -- inspect source manually

## 5. Conventional Event-Matching Definition

For each test record and phase independently:

| Case | Condition | TP | FP | FN |
|---|---|---|---|---|
| 1 | Detected AND |error| <= tol | 1 | 0 | 0 |
| 2 | Detected AND |error| >  tol | 0 | 1 | 1 |
| 3 | Not detected                | 0 | 0 | 1 |
| 4 | No ground truth (invalid)   | -- | -- | -- |

Precision = TP / (TP + FP)
Recall    = TP / (TP + FN)  where TP + FN = N_total
F1        = 2 * P * R / (P + R)

## 6. Full3C Results

### P-wave

| Tolerance | Conventional F1 | Current F1 | Delta | TP | FP | FN |
|---|---|---|---|---|---|---|
| 50 ms | 0.7046 | 0.8246 | -0.1199 | 235 | 97 | 100 |
| 100 ms | 0.8546 | 0.9194 | -0.0648 | 285 | 47 | 50 |
| 200 ms | 0.9295 | 0.9612 | -0.0317 | 310 | 22 | 25 |

### S-wave

| Tolerance | Conventional F1 | Current F1 | Delta | TP | FP | FN |
|---|---|---|---|---|---|---|
| 50 ms | 0.4060 | 0.5745 | -0.1685 | 135 | 195 | 200 |
| 100 ms | 0.5985 | 0.7453 | -0.1468 | 199 | 131 | 136 |
| 200 ms | 0.7188 | 0.8328 | -0.1140 | 239 | 91 | 96 |

## 7. Zonly Results

### P-wave

| Tolerance | Conventional F1 | Current F1 | Delta | TP | FP | FN |
|---|---|---|---|---|---|---|
| 50 ms | 0.7226 | 0.8368 | -0.1142 | 241 | 91 | 94 |
| 100 ms | 0.8696 | 0.9280 | -0.0584 | 290 | 42 | 45 |
| 200 ms | 0.9355 | 0.9645 | -0.0289 | 312 | 20 | 23 |

### S-wave

| Tolerance | Conventional F1 | Current F1 | Delta | TP | FP | FN |
|---|---|---|---|---|---|---|
| 50 ms | 0.1759 | 0.2908 | -0.1149 | 57 | 256 | 278 |
| 100 ms | 0.3241 | 0.4773 | -0.1532 | 105 | 208 | 230 |
| 200 ms | 0.4660 | 0.6214 | -0.1553 | 151 | 162 | 184 |

## 10. Current versus Conventional F1 Comparison

**RESULT: Differences detected between current and conventional F1.**
See DeltaF1 column in f1_conventional_summary.csv for per-row differences.

## 11. MAE Denominator Explanation

MAE is computed exclusively over detected picks and is independent of tolerance.
Missing predictions (not_detected) do not enter the MAE calculation.
This is unchanged by the F1 definition audit.

| Phase | Full3C MAE (ms) | Z-only MAE (ms) |
|---|---|---|
| P | 72.7 | 69.1 |
| S | 725.4 | 947.9 |

## 12. Bootstrap Confidence Intervals

| Experiment | Phase | Tolerance | F1 | 95% CI |
|---|---|---|---|---|
| Full3C | P | 50 ms | 0.7046 | [0.6547, 0.7549] |
| Full3C | P | 100 ms | 0.8546 | [0.8165, 0.8896] |
| Full3C | P | 200 ms | 0.9295 | [0.9012, 0.9549] |
| Full3C | S | 50 ms | 0.4060 | [0.3489, 0.4565] |
| Full3C | S | 100 ms | 0.5985 | [0.5467, 0.6502] |
| Full3C | S | 200 ms | 0.7188 | [0.6672, 0.7658] |
| Zonly | P | 50 ms | 0.7226 | [0.6766, 0.7699] |
| Zonly | P | 100 ms | 0.8696 | [0.8311, 0.9038] |
| Zonly | P | 200 ms | 0.9355 | [0.9084, 0.9611] |
| Zonly | S | 50 ms | 0.1759 | [0.1339, 0.2178] |
| Zonly | S | 100 ms | 0.3241 | [0.2747, 0.3730] |
| Zonly | S | 200 ms | 0.4660 | [0.4114, 0.5178] |

## 13. Paired Full 3C versus Z-only Comparison

| Phase | Tol (ms) | Both correct | Full3C only | Zonly only | Neither |
|---|---|---|---|---|---|
| P | 50 | 225 | 10 | 16 | 84 |
| P | 100 | 281 | 4 | 9 | 41 |
| P | 200 | 306 | 4 | 6 | 19 |
| S | 50 | 40 | 95 | 17 | 183 |
| S | 100 | 86 | 113 | 19 | 117 |
| S | 200 | 136 | 103 | 15 | 81 |

## 14. Recommendation for Manuscript

**RECOMMENDATION A: Use conventional F1 throughout the manuscript.**
The current and conventional F1 values differ (see DeltaF1 column).
Update Tables 4 and 5 in the manuscript with conventional F1 values.
Update abstract, highlights, and conclusion with revised values.

## 15. Retraining

Not required. Not performed.

## 16. Manuscript Sections Requiring Update

If conventional F1 differs from current:
- Abstract: F1 values for P and S at 100 ms
- Highlights: F1 values
- Table 4 (Full 3C): F1 @50/100/200 ms for P and S
- Table 5 (Z-only comparison): F1 columns
- Section 5.1 (Full 3C results): narrative F1 values
- Section 5.2 (Z-only): narrative F1 values
- Section 7 (Conclusions): F1 claims
- Benchmark comparison (when finalized): F1 for all methods

---
*Audit generated by runConventionalF1Audit.m. No predictions were modified.*
