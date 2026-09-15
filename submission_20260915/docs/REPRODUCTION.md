# Output reproduction map

Run `python analysis/reproduce.py --verify` from the package directory. Generated tables are CSVs in `regenerated/Tables`; plots are PDF vectors and 600-dpi PNGs in `regenerated/Figures`. Figure generator aliases `mainN` and `suppN` correspond to manuscript Figure N and Supplementary Figure SN. Supplementary Figure S5 reuses main4. The table files preserve numeric precision; the manuscript rounds and arranges them for reading.

| Manuscript output | Generator | Inputs |
|---|---|---|
| Table 1 | tables.py | curated metadata; fixed record format |
| Table 2 | tables.py | metadata + three fixed source lists |
| Table 3 | tables.py | configuration_table.csv; cross-checked against runner/config and fitClean |
| Table 4 | audit_metrics.py → tables.py | six Full15 prediction tables; three-seed means and sample SD |
| Table 5 | audit_metrics.py → tables.py | paired Full3C/Z-only predictions; 10,000 source resamples |
| Table S1 | recompute_tensor_stats.py (optional) → tables.py | all Full3C final-base test tensors; supplied tensor_stats.csv receipt |
| Table S2 | figures.py → tables.py | six predictions; bootstrap at 50/100/200 ms |
| Table S3 | figures.py → tables.py | seed-42 accepted prediction errors |
| Table S4 | tables.py | workflow_settings.csv; configuration and provenance descriptions |
| Table S5 | audit_metrics.py → tables.py | Full3C standalone/ensemble predictions plus Full15 seed means |
| Table S6 | audit_metrics.py → tables.py | all Full3C meta variants; paired intervals only at 100 ms |
| Table S7 | audit_metrics.py → tables.py | seed-42 TP/FP/FN counts |
| Table S8 | tables.py | data_roles.csv; runner stage-by-stage code inspection |
| Table S9 | tables.py | frozen training_plan_40.csv; aggregate mode/kind fit counts |
| Table S10 | diagnostics.py → tables.py | detected-only masks on all six Full15 prediction tables |
| Table S11 | diagnostics.py → tables.py | P-defined subsets and paired unconstrained predictions |
| Table S12 | metadata_coverage.py → tables.py | trace_name, receiver_code, source assignments |
| Figure 1 | workflow_figure.py | explicit workflow schematic; no fitted data |
| Figure 2 | metadata_figures.py | metadata histograms, 30 bins |
| Figure 3 | metadata_figures.py | example_test_tensor.csv conditioned Z; Gaussian targets |
| Figure 4 / S5 | figures.py | example_test_tensor.csv, held-out stead_event_00001 |
| Figure 5 / S3 | figures.py | Full15 mean and sample SD at three tolerances |
| Figures 6, 10, 11 | figures.py | accepted prediction residuals and percentiles |
| Figures 7, 8, 9 | figures.py | predictions joined to metadata by event_id |
| Figure 12 | figures.py | selected prediction errors + external waveform CSVs |
| Figure S1 | figures.py | training_history.csv / validation_history.csv exported from final Full3C seed-42 checkpoint |
| Figure S2 | metadata_figures.py | metadata and source-list intersections |
| Figure S4 | figures.py | largest 20 seed-42 P/S accepted errors |

## What is independently recomputed

The prediction-based route independently recomputes TP/FP/FN, F1, accepted and strict coverage, error statistics, three-seed summaries, and paired intervals. It does not refit the networks. Configuration tables describe explicit parameters and data roles and are not estimated from prediction values.

Table S1's full-cache summary and Figure S1's training histories are supplied derived receipts from the verified local cache/checkpoint. They can be plotted or checked numerically without those large files, but independent recovery of the receipts requires the full cache/checkpoint or a fresh training run. `analysis/recompute_tensor_stats.py <meta_cache.mat>` regenerates S1 and the example tensor from a MATLAB v7.3 cache. `runner/export_training_history.m` exports the final checkpoint histories. A new run on different hardware is not promised to yield bit-identical weights or histories.

Raw STEAD waveforms are external. Figure 12 regeneration was tested against the local curated CSVs but requires those files for other users. Metadata identify the original traces, and `docs/input_waveform_hashes.csv` identifies the exact local CSV exports used. No unsupported claim that the lightweight bundle contains all raw inputs or checkpoints is made.

## Version identity

`SHA256_manifest.json` covers the current public package. `docs/original_code_hashes.csv` preserves original run source hashes separately, because translated comments and portable paths change package hashes without changing fitted results. Historical 2,000-draw per-seed exports are not the manuscript confidence intervals. Do not substitute root legacy output files or an unverified Zenodo version.

The scientific figures use deterministic plotting code. No raster image synthesis or generative editing produced the submitted scientific plots.
