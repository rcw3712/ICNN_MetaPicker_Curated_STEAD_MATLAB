# Source-grouped evaluation of temporal stacking for seismic phase picking

This repository accompanies **Source-Grouped Evaluation of Temporal Stacking for Seismic Phase Picking with Three-Component Data** (revision 16 September 2026).

## Executable workflow and saved models

Use **[reproducibility_20260916](reproducibility_20260916/README.md)** for all 106 saved checkpoints (about 76 MB), portable MATLAB model replay, source/feature contracts, synthetic demonstrations and documented threshold history. The five negative-control cases are rejected, all 106 checkpoints load, and pick/status replay matches on the stated CPU/GPU smoke subsets. The contribution is inspectable software integration and reusable checks; grouped OOF itself is an established method. Exact waveform replay still requires the identified curated CSV exports; that limitation and the data-independent demonstrations are documented.

Release **[v1.4.0](https://github.com/rcw3712/ICNN_MetaPicker_Curated_STEAD_MATLAB/releases/tag/v1.4.0)** packages this software, [current manuscripts](submission_documents_20260916) and [separate artwork](presentation_20260916). It introduces no new fits, split, calibration or predictive result. The published archive is **[DOI 10.5281/zenodo.22784226](https://doi.org/10.5281/zenodo.22784226)**. Its ZIP checksum and all 265 model/replay, 51 artwork, 5 document and 367 extension-manifest hashes were verified after download. See [archive verification](ARCHIVE_VERIFICATION.md) for the immutable commit and exact scope.

## Scientific results

Use **[strengthening_20260916](strengthening_20260916/README.md)** for the frozen expanded experiment and numerical audit. Its manuscript snapshot predates the current software revision. It extends the original **[submission_20260915](submission_20260915/README.md)** package with 66 fits (106 overall): two additional CNN/TCN base seeds in both modes, crossed with three meta seeds, plus six standalone PhaseNet-style baseline fits.

| Method | Mode | P F1 at Ã‚Â±100 ms | S F1 at Ã‚Â±100 ms |
|---|---|---:|---:|
| Stacking | Full3C | 0.8694 | 0.5780 |
| Stacking | Z-only | 0.8723 | 0.3384 |
| PhaseNetMatched | Full3C | 0.9661 | 0.6267 |
| PhaseNetMatched | Z-only | 0.9637 | 0.3689 |

The stacking S Full3C minus Z-only difference is 0.2396 (conditional 95% interval 0.1874Ã¢â‚¬â€œ0.2905). The baseline has higher mean F1 in both modes; the Z-only S advantage is not resolved by its interval. The contribution is an inspectable evaluation workflow and evidence about component access, not superior stacking performance. Findings condition on one curated source split; meta fits sharing a base are not independent pipelines, and source-cluster intervals exclude training/split uncertainty. PhaseNetMatched is a MATLAB adaptation trained from scratch, not official or pretrained PhaseNet.

## Reproduction and archives

- [Expanded audit and commands](strengthening_20260916/README.md)
- [Current manuscript documents with verified DOI](submission_documents_20260916)
- [Original 40-fit protocol and frozen evidence](submission_20260915/README.md)
- [Archive verification and version scope](ARCHIVE_VERIFICATION.md)

Release v1.3.0 archives the expanded audit package and manuscript snapshot at **[DOI 10.5281/zenodo.22782746](https://doi.org/10.5281/zenodo.22782746)**, commit `e235f749540a56b763eca5903abb9592b9ed02b8`. All 367 extension-manifest hashes were verified against the published ZIP. DOI 10.5281/zenodo.22760733 identifies v1.2.0 only. Current manuscript documents include the v1.4.0 software demonstration and Table 3 correction; their numerical results match the archived snapshot. See the archive-verification notice for exact scope.

Root-level MATLAB scripts, results and older documentation are legacy material. The dated packages define the evidence and software interfaces. Raw STEAD waveforms, full probability curves and large caches are excluded. All 106 trained checkpoints are supplied in reproducibility_20260916; numerical checks and synthetic demonstrations can run without external waveforms. Code is MIT licensed; STEAD inputs retain their original distribution terms. No journal submission has been made by this synchronization.
