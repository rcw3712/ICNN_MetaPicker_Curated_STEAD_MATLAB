# Verification of release v1.4.0

Verified 16 September 2026.

- Release: https://github.com/rcw3712/ICNN_MetaPicker_Curated_STEAD_MATLAB/releases/tag/v1.4.0
- Published DOI: https://doi.org/10.5281/zenodo.22784226
- Immutable commit: `69bca5ce4e29475ecf590d2ad14a86d6f96b3f90`
- Downloaded ZIP: 155,024,131 bytes; MD5 `c96cce407addeee2266f6310192e06d1`, matching Zenodo metadata.
- All **265** checkpoint/replay package hashes, **51** artwork/source hashes, **5** current document hashes and **367** frozen extension hashes match the downloaded archive.

The release contains all 106 trained checkpoints, portable inference, synthetic examples, threshold provenance, current manuscripts and separate artwork. CPU/GPU model verification is limited to the smoke subsets reported in the manuscripts; exact full waveform replay still requires the identified historical CSV exports. No new training or calibration was performed.

The v1.4.0 manuscript cites the release URL because the Zenodo DOI was assigned after publication. Both identify the same release snapshot. This notice and updated citation metadata are post-release verification; the immutable tag and archived manuscripts are unchanged. Historical archive exclusions below apply to those older versions.

## Historical verification

# Verification of release v1.3.0

Verified 16 September 2026.

- Release: https://github.com/rcw3712/ICNN_MetaPicker_Curated_STEAD_MATLAB/releases/tag/v1.3.0
- DOI: https://doi.org/10.5281/zenodo.22782746
- Zenodo record: https://zenodo.org/records/22782746
- Immutable commit: `e235f749540a56b763eca5903abb9592b9ed02b8`
- Published ZIP: `rcw3712/ICNN_MetaPicker_Curated_STEAD_MATLAB-v1.3.0.zip` (94,601,044 bytes)
- MD5: `e6c190c5c2e1f7b81644ed7ce111c98f`, matching Zenodo metadata.
- All **367 entries** in `strengthening_20260916/SHA256SUMS.csv` passed SHA-256 verification against the downloaded published archive.

The release contains the original experiment and 66-fit extension, including the MATLAB runner, predictions, audit outputs and manuscript snapshot. All 288 recomputed metric rows matched. Raw STEAD waveforms, trained checkpoints and large caches are not included.

The archived manuscript and package README predate DOI assignment. Their statements about an unasserted new DOI record that historical state. Updated availability wording is supplied in `submission_documents_20260916`; numerical results are unchanged. This verification notice and those availability-only document revisions are later than the release and are not claimed to be inside its immutable archive.

## Earlier release

# Verification of the submission archive

Verified on 15 September 2026. The public Zenodo record is published and identifies release v1.2.0:

- DOI: https://doi.org/10.5281/zenodo.22760733
- Release: https://github.com/rcw3712/ICNN_MetaPicker_Curated_STEAD_MATLAB/releases/tag/v1.2.0
- Git commit: `767be754d415d0659b7426c926e87ac26f19eb55`
- Archive: `ICNN_MetaPicker_Curated_STEAD_MATLAB-v1.2.0.zip` (86,827,908 bytes)
- ZIP MD5: `516b62b612d0774f40b409e3d0e11f39`, matching Zenodo metadata.
- All 234 entries in the archived `submission_20260915/SHA256_manifest.json` passed SHA-256 verification.

The frozen package and release have not been changed. Their pre-release statements about an unverified DOI are historical; this notice records the subsequent verification. Current root citation metadata identifies the published software release, rather than an unpublished article with a placeholder DOI. Later documentation commits are not part of the v1.2.0 archive.

The archive contains the public audit package and legacy repository files. This verification does not imply that full trained checkpoints or raw waveform collections are included. See the frozen reproduction documentation for artifact availability and limits.
