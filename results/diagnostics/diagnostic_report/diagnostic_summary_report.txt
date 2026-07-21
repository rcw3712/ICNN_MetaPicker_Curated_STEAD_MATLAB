# Post-Evaluation Diagnostics Report
Generated: 2026-07-13 09:31:49
Framework: I-CNN MetaPicker (Curated STEAD CSV, v1.0.1)
Experiment: Full3C + Z-only (STEAD simulation)

## 1. Dataset Summary
- Test set records : 335
- Experiments      : Full3C (E+N+Z), Z-only (Z only, PiGraf simulation)
- Data source      : Curated STEAD-derived CSV (dist<=15km, mag>=1.5, SNR>=10dB)
- Split strategy   : Source-level (source_id), 70/15/15%

## 2. Main Performance Summary

| Metric         | Full3C P | Full3C S | Z-only P | Z-only S |
|----------------|----------|----------|----------|----------|
| MAE (ms)       |  171.970 |  725.424 |  206.239 |  947.859 |
| MedAE (ms)     |   20.000 |   70.000 |   20.000 |  220.000 |
| RMSE (ms)      | 1839.293 | 2376.304 | 1970.513 | 2310.174 |
| P90 (ms)       |  140.000 |  755.000 |  140.000 | 3090.000 |
| Outlier>1s (%) |    0.597 |    9.697 |    0.896 |   15.655 |

_Note: Outlier rate shown as percentage._

## 3. Percentile Metrics Interpretation

- P-wave Full3C: MAE=172ms, MedAE=20ms, RMSE=1839ms (RMSE/MAE=10.7)
- S-wave Full3C: MAE=725ms, MedAE=70ms, RMSE=2376ms (RMSE/MAE=3.3)

P-wave RMSE/MAE ratio of 10.7 indicates a heavy-tailed error distribution 
where a small number of large timing outliers substantially inflate the RMSE.
The median absolute error (MedAE) is more representative of typical picking performance.
S-wave RMSE/MAE ratio of 3.3 is consistent with mode-mixing: the I-CNN 
successfully resolves S arrivals for the majority of records, but a minority of
records with ambiguous S-wave onset (long S-P time, low STA/LTA ratio) lead to
large timing residuals that dominate the RMSE.

## 4. Outlier Summary

| Category             | Full3C P | Full3C S | Z-only P | Z-only S |
|----------------------|----------|----------|----------|----------|
| Outlier >500ms (%)   |      2.1 |     14.5 |      2.1 |     29.4 |
| Outlier >1000ms (%)  |      0.6 |      9.7 |      0.9 |     15.7 |
| Outlier >2000ms (%)  |      0.6 |      8.2 |      0.9 |     11.5 |

## 5. SNR-Stratified Summary

Full3C performance by SNR class:
| SNR Class         | N   | MAE P (ms) | F1@100ms P | MAE S (ms) | F1@100ms S |
|-------------------|-----|-----------|------------|-----------|------------|
| Low (10-20 dB)    |  31 |        49 |      0.931 |       471 |      0.760 |
| Medium (20-40 dB) | 163 |       295 |      0.906 |       811 |      0.741 |
| High (>=40 dB)    | 141 |        57 |      0.936 |       684 |      0.747 |

_Note: This dataset is a curated high-quality subset (SNR >= 10 dB);
 SNR-stratified results represent internal performance tiers, not field conditions._

## 6. Full3C vs. Z-only Interpretation

### P-wave
P-wave picking performance is largely preserved under Z-only acquisition
(F1@100ms change < 1%). This is physically consistent with the predominantly
vertical particle motion of compressional waves, which is well captured by the
single vertical seismometer component.

### S-wave
S-wave picking performance degrades substantially under Z-only acquisition
(F1@100ms reduction ~36%; MedAE increase from 70ms to 220ms). This reflects
the transverse particle motion of shear waves, which is optimally recorded on
horizontal components (E and N). The absence of these components forces the
I-CNN meta-learner to rely on secondary S-wave energy recorded on the vertical
component, leading to increased timing uncertainty and a higher rate of missed
or erroneous S-phase picks.

### Implication for PiGraf deployment
PiGraf field data are not used for quantitative validation in this study because
the current field acquisition records only the vertical (Z) component reliably.
The Z-only simulation results indicate that P-wave picking remains reliable under
this constraint, whereas S-wave picking quality is substantially reduced. We
recommend prioritising the restoration of horizontal sensor functionality in the
PiGraf deployment to enable reliable S-wave picking and accurate hypocentre
depth estimation.

## 7. Recommended Manuscript Language

### On percentile metrics:
"Standard mean absolute error (MAE) and RMSE are sensitive to large timing
outliers in phase-picking tasks. We therefore additionally report median
absolute error (MedAE), 90th-percentile absolute error (P90), and outlier rates
at thresholds of 500, 1000, and 2000 ms to provide a more complete picture of
the error distribution."

### On MAE-RMSE gap:
"The substantial gap between RMSE and MAE (ratio > 3) indicates a heavy-tailed
error distribution in which the majority of picks are accurate (MedAE ~ 10-20 ms)
but a small number of outlier picks (< 10%) involve large timing residuals attributable
to coda misidentification and pre-event noise detection."

### On Z-only:
"Ablating the horizontal components (E and N) resulted in a substantial
reduction in S-wave F1@100ms (from 0.745 to 0.477, a 35.9% relative decrease),
while P-wave performance remained nearly unchanged (F1@100ms: 0.921 to 0.930),
confirming the physical interpretation that P-wave energy is predominantly
recorded on the vertical component while S-wave identification relies critically
on horizontal motion."

---
_This report was auto-generated by exportDiagnosticReport.m (I-CNN MetaPicker v1.0.1)._
_No model retraining was performed. All diagnostics are based on saved prediction results._
