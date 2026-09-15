# Source-grouped evaluation of temporal stacking for seismic phase picking

This repository accompanies **Source-Grouped Evaluation of Temporal Stacking for Seismic Phase Picking with Three-Component Data** (submission revision 15 September 2026).

## Current manuscript version

Use **[submission_20260915](submission_20260915/README.md)**. It contains the current 40-fit MATLAB runner, frozen record-level predictions, fixed source partitions, metadata, portable Python analyses, and an output-to-script reproduction map.

**Root-level scripts, results, and older documentation are legacy material and do not reproduce the current manuscript.** They remain for provenance. In particular, the current analysis does not use the historical two-SD significance rule or treat the S-after-P constraint as an inactive deployment-only safeguard.

## Current results and scope

On 335 test records from 317 held-out earthquake sources, mean F1 at ±100 ms over three meta-learner seeds is:

| Mode | P | S |
|---|---:|---:|
| Full3C | 0.8680 | 0.5737 |
| Z-only | 0.8664 | 0.3296 |

The Full3C minus Z-only S difference is 0.2441 (conditional paired source-cluster interval 0.1892–0.2979). CNN/TCN bases use seed 42; neural meta-learners use 42, 43, and 44. Intervals and seed SD do not include base-training or partition uncertainty. Final base selection, meta early stopping, and ensemble weighting reuse outer validation; this limitation is explicit. Test sources enter neither weight fitting nor checkpoint selection.

The strongest TCN approaches the stacker. Ablations do not establish essential nonlinearity, waveform-context necessity, or a dilation benefit. The S search is part of evaluation: removing its 0.1–30 s window and P gate changes a small number of predictions and changes the quality-score domain. It is not an independently learned physical law.

## Reproduction and access

- [Installation and commands](submission_20260915/README.md)
- [Methods and validation roles](submission_20260915/docs/METHODS.md)
- [Figure/table mapping and large-file requirements](submission_20260915/docs/REPRODUCTION.md)
- [Frozen result tables](submission_20260915/frozen)
- [Package hash manifest](submission_20260915/SHA256_manifest.json)

The lightweight bundle checks reported metrics without waveform access or retraining. Raw STEAD waveforms, full probability curves, all meta caches, and trained checkpoints are not bundled here. Full training instructions and data identification are provided; exact historical checkpoint recovery is distinct from rerunning the protocol on different hardware. Release v1.2.0 archives Git commit `767be754d415d0659b7426c926e87ac26f19eb55` at [DOI 10.5281/zenodo.22760733](https://doi.org/10.5281/zenodo.22760733). All 234 package files were checked against the archived SHA-256 manifest on 15 September 2026 and passed. The archive predates this documentation update; its README statements that no DOI had yet been verified describe the pre-release state. See [archive verification](ARCHIVE_VERIFICATION.md).

Code is MIT licensed. Original STEAD data remain subject to their own distribution terms. This repository has not been uploaded to a journal by the revision process.
