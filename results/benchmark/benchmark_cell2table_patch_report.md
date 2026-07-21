# Benchmark cell2table Patch Report

Generated: 2026-07-16 09:03:01

## 1. Executive Summary

This report documents a report-schema bug fix. The cell2table error
occurred because statRows was a nested cell vector requiring
vertcat(statRows{:}) not vertcat(statRows), AND because waveform-
context rows omitted the ProbabilitySumError field, creating rows
of inconsistent length. Neither error affected the locked Full 3C
or Z-only results. No retraining was required.

## 2. Previous 20-Channel Issue

RESOLVED in previous patch.

## 3. Current 15-Channel Status

VERIFIED PASS.

## 4. cell2table Error

Root cause: statRows{k} for waveform channels had 10 fields
(missing ProbabilitySumError) while probability channels had 11.
Fix: all rows now include ProbabilitySumError field, set to NaN
for waveform-context channels 13-15.

## 5. Schema

| Index | Field | Prob channels | Wave channels |
|---|---|---|---|
|  1 | ChannelIndex | value | ChannelIndex |
|  2 | FeatureName | value | FeatureName |
|  3 | FeatureGroup | value | FeatureGroup |
|  4 | Minimum | value | Minimum |
|  5 | Maximum | value | Maximum |
|  6 | Mean | value | Mean |
|  7 | StdDev | value | StdDev |
|  8 | NaNCount | value | NaNCount |
|  9 | InfCount | value | InfCount |
| 10 | ProbabilitySumError | value | NaN |
| 11 | Status | value | Status |

## 6. Files Modified

- src/benchmark/runMetaLearnerBenchmarkFromOOF.m
- src/benchmark/buildChannelStatisticsTable.m (NEW helper)

## 7. Locked-Result Reproduction

| Metric | Expected | Actual | Status |
|---|---|---|---|
| P F1@100ms | 0.9211 | 0.9211 | PASS |
| S F1@100ms | 0.7453 | 0.7453 | PASS |
| P MAE (ms) | 171.9701 | 171.9701 | PASS |
| S MAE (ms) | 725.4242 | 725.4242 | PASS |

## 8. Finalization Status

FINALIZED. benchmark_summary_final.csv safe for manuscript.

## 9. Retraining

Not required. Not performed.

## 10. Evaluation Definition

The benchmark uses the same evaluation implementation as the locked
Full 3C experiment. Any later revision of the event-matching or F1
definition must be applied consistently to all benchmark methods.
