# Benchmark Validation Report

Generated: 2026-07-15 15:10:35  
Framework: I-CNN MetaPicker (Curated STEAD CSV)  
Purpose: Diagnose unrealistic metrics in benchmark_summary.csv  

---

## Consistency Check Results

| Check | Status | Detail |
|---|---|---|
| TestIDs | WARN | ref has 335 records but split has 317 IDs -- possible duplicate source_ids |
| GroundTruthLabels | OK | p_true: 0 NaN of 335; s_true: 0 NaN of 335; p_range=[1.51,12.51]s |
| MetaFeatureTensors | OK | C_model=15, C_config=15 -- consistent |
| Scaling | OK | Meta-features are softmax outputs in [0,1]; no external scaling needed |
| PhysicsAwarePicker | OK | minSPTime=0.10s, sr=100Hz, nSamples=6000 |
| EvaluationFormula | OK | P F1@100ms: saved=0.9211 recomputed=0.9211; S F1@100ms: saved=0.7453 recomputed=0.7453 |

---

## Issues Found

- CHECK 1 WARN: ref has 335 records but split has 317 IDs -- possible duplicate source_ids

## Diagnosis: Root Cause of Unrealistic Metrics

_No specific root cause identified. Manual review recommended._

## Channel Count Verification

| Source | Channel count |
|---|---|
| Saved I-CNN model (numChan) | 15 |
| Current config (nPickers*3+waveformContext) | 15 |

Channel counts are consistent.

## Recommendation

Resolve all FAIL and WARN items above before regenerating `benchmark_summary.csv`.

Do NOT retrain models or regenerate figures to fix these issues.
The fix should be purely in the benchmark evaluation code.
