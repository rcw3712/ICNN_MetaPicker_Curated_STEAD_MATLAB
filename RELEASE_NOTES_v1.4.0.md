# Model replay and executable source-grouped workflow

This release makes the trained models and their inference dependencies available for independent inspection and reuse. It adds all 106 checkpoints, a SHA-256 inventory, portable CPU/GPU MATLAB replay, the PhaseSkipCrop custom layer, grouped synthetic examples, five negative controls, and historical configuration evidence.

All checkpoints load and pass saved source-membership checks. Replay matches archived pick times and statuses for 24 outputs on three test records with GPU and one with CPU. These are smoke checks; a complete 335-record replay is supported but is not reported as performed in this release. Exact waveform replay requires the identified historical curated CSVs, which are not redistributed. Python examples and MATLAB checkpoint/synthetic checks run without external waveforms.

The manuscript now demonstrates reusable computational checks, corrects Table 3 base/meta seed scope and adds Tables S19-S21. Threshold values are documented in July 2026 history; this is not evidence that their original selection used validation data only. No thresholds, models or source partitions were re-optimized. Scientific metrics remain those of v1.3.0, DOI 10.5281/zenodo.22782746.

Current documents and 19 separate figures in PNG/PDF, including stacker-versus-PhaseNetMatched and base-seed variability plots, are included. See reproducibility_20260916/README.md for requirements, commands, expected outputs and limitations. MIT license applies to the software; MATLAB and STEAD retain their own terms.
