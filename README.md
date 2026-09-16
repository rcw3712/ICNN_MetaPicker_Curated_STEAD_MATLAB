# Source-grouped evaluation of temporal stacking for seismic phase picking

This repository accompanies **Source-Grouped Evaluation of Temporal Stacking for Seismic Phase Picking with Three-Component Data** (revision 16 September 2026).

## Current manuscript and results

Use **[strengthening_20260916](strengthening_20260916/README.md)** for the expanded experiment, numerical audit and revised manuscripts. It extends the original **[submission_20260915](submission_20260915/README.md)** package with 66 fits (106 overall): two additional CNN/TCN base seeds in both modes, crossed with three meta seeds, plus six standalone PhaseNet-style baseline fits.

| Method | Mode | P F1 at Â±100 ms | S F1 at Â±100 ms |
|---|---|---:|---:|
| Stacking | Full3C | 0.8694 | 0.5780 |
| Stacking | Z-only | 0.8723 | 0.3384 |
| PhaseNetMatched | Full3C | 0.9661 | 0.6267 |
| PhaseNetMatched | Z-only | 0.9637 | 0.3689 |

The stacking S Full3C minus Z-only difference is 0.2396 (conditional 95% interval 0.1874â€“0.2905). The baseline has higher mean F1 in both modes; the Z-only S advantage is not resolved by its interval. The contribution is an inspectable evaluation workflow and evidence about component access, not superior stacking performance. Findings condition on one curated source split; meta fits sharing a base are not independent pipelines, and source-cluster intervals exclude training/split uncertainty. PhaseNetMatched is a MATLAB adaptation trained from scratch, not official or pretrained PhaseNet.

## Reproduction and archives

- [Expanded audit and commands](strengthening_20260916/README.md)
- [Current manuscript documents with verified DOI](submission_documents_20260916)
- [Original 40-fit protocol and frozen evidence](submission_20260915/README.md)
- [Archive verification and version scope](ARCHIVE_VERIFICATION.md)

Release v1.3.0 archives the expanded audit package and manuscript snapshot at **[DOI 10.5281/zenodo.22782746](https://doi.org/10.5281/zenodo.22782746)**, commit `e235f749540a56b763eca5903abb9592b9ed02b8`. All 367 extension-manifest hashes were verified against the published ZIP. DOI 10.5281/zenodo.22760733 identifies v1.2.0 only. Current manuscript documents update availability wording after DOI assignment; their numerical results match the archived snapshot. See the archive-verification notice for exact scope.

Root-level MATLAB scripts, results and older documentation are legacy material. The two dated packages define the current evidence. Raw STEAD waveforms, full probability curves and trained checkpoints are excluded; numerical checks can be replayed without them. Code is MIT licensed; STEAD inputs retain their original distribution terms. No journal submission has been made by this synchronization.
