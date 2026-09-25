# Waveform identity and reproducible source-grouped evaluation of seismic phase pickers

**Current manuscript: [Earth Science Informatics revision, 25 September 2026, round 2](source_verified_v2/documents/ESI_20260925_Round2/README.md). Computational results: [source_verified_v2](source_verified_v2/README.md).** This corrected package supersedes the numerical results and source assignments in every earlier dated package and release. Use its models, inputs and commands together.

An exhaustive audit of the local STEAD HDF5 archive uniquely matches all 2,234 retained records to 1,477 sources. The fixed source-disjoint split contains 1,544 training records (1,034 sources), 360 validation records (222 sources), and 330 test records (221 sources). Fresh replay loads all 106 checkpoints and reproduces OOF features and 70 test prediction sets. These checks establish artifact consistency, not independent predictive confirmation.

## Results on this fixed split

| Method | Mode | Accepted P F1 at 100 ms | Accepted S F1 at 100 ms |
|---|---|---:|---:|
| Stacking | Full3C | 0.8268 | 0.5536 |
| Stacking | Z-only | 0.8134 | 0.2686 |
| PhaseNet-style MATLAB baseline | Full3C | 0.9833 | 0.5857 |
| PhaseNet-style MATLAB baseline | Z-only | 0.9833 | 0.2995 |

Conditional source-cluster intervals support the baseline's P advantage. Primary accepted-scoring S method differences remain unresolved; both approaches show an S component-access difference on this fixed split. The stacking difference is 0.2850 (conditional 95% interval 0.2293–0.3418). Manual-status sensitivity uses upstream metadata, not independent manual re-picking. Historical development exposure prevents an independent-confirmation claim. No general station-transfer claim is supported by the 12 unseen-station-key records. The comparator is a MATLAB adaptation, not official or pretrained PhaseNet.

## Start here

- [Installation, dependencies, resources and user guide](source_verified_v2/USER_GUIDE.md)
- [No-training tutorials](source_verified_v2/TUTORIALS.md)
- [Current ESI documents](source_verified_v2/documents/ESI_20260925_Round2) and [separate PNG/PDF figures](source_verified_v2/documents/ESI_20260925_Round2/Figures)
- [Frozen source protocol](source_verified_v2/inputs), [106 checkpoints and outputs](source_verified_v2/results), and [audits](source_verified_v2/audit)
- [Computational contribution and scientific limits](source_verified_v2/COMPUTATIONAL_CONTRIBUTION.md)
- [Historical C&G repository requirement checklist](source_verified_v2/CG_REPOSITORY_CHECKLIST.md)

Code is [MIT licensed](LICENSE). Original STEAD inputs retain their upstream terms and are not bundled. The repository supplies uncompressed source files, models, numeric outputs, provenance, synthetic examples and a byte-hash manifest; it is not a single ZIP distribution. Exact waveform replay requires CSV bytes matching the frozen manifest. The [tested HDF5 reconstruction route](source_verified_v2/documents/ESI_20260925_Round2/Reconstruction/README.md) reproduces every retained CSV hash in the tested local archive. Numerical checks and synthetic demonstrations require no waveform data or MATLAB.

## Historical releases

Root-level MATLAB scripts, root `results`, and all packages dated 15–16 September are **historical**, including `reproducibility_20260916`, `strengthening_20260916`, `submission_20260915`, `presentation_20260916` and `submission_documents_20260916`. Their models and reported metrics must not be mixed with source-verified v2. They remain unchanged for provenance; statements of “current” inside them refer to their historical date.

DOI 10.5281/zenodo.22784226 identifies v1.4.0 only; 10.5281/zenodo.22782746 identifies v1.3.0; 10.5281/zenodo.22760733 identifies v1.2.0. Release source-verified-v2.0.0 at Git commit 8e82c781a1641191b6b56b15688d68e269b24918 is archived at [https://doi.org/10.5281/zenodo.22824997](https://doi.org/10.5281/zenodo.22824997). The archive was downloaded and verified against all 1,241 package-manifest entries and all 2,471 Git blobs, including 106 checkpoints. Current availability wording and documentation were updated after DOI assignment; those later text revisions are not claimed to be inside the immutable archive. Fitted checkpoints and numerical model results are unchanged. The current revision additionally supplies a verified retained-CSV reconstruction utility; that new utility and its receipts are not contents of the existing DOI archive. This synchronization does not submit the manuscript to a journal.

## Manuscript presentation update

The ESI revision foregrounds waveform identity, data lineage and numerical reproducibility. It updates the title, references, declarations and document organization without changing checkpoint, training, input, prediction or evaluation artifacts. The package SHA256_MANIFEST.csv describes the current tree; audit/Archive/ARCHIVED_SHA256_MANIFEST.csv remains the immutable archived-release manifest. The ESI documents are later than the DOI archive and are not claimed to be archived there. CITATION.cff retains the archived software title, version and DOI.

## Retained-input reconstruction check

The round-2 revision adds explicit workflow-contract and reproduction-level tables, a redrawn Fig. 1, literature on validation and provenance, and a shorter primary Results presentation. A no-training HDF5-to-CSV check matched 2,234 source IDs, 2,234 waveform fingerprints and all 2,234 complete CSV byte hashes. Historical filtering/subset-selection decisions remain unresolved. The check does not add predictive evidence or claim cross-device replay.

Article type for the current ESI submission: **Methodology**. The cover letter and manuscript framing describe a case-tested evaluation/provenance methodology. The PhaseNet-style model is a case-study comparator.
