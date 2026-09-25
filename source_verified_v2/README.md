# Corrected source-verified v2

This is the current evidence package for *Waveform Identity and Reproducible Source-Grouped Evaluation of Seismic Phase Pickers*. The [ESI manuscript round-2 revision of 25 September 2026](documents/ESI_20260925_Round2/README.md) updates presentation and literature; the computational results are unchanged. Begin with [USER_GUIDE.md](USER_GUIDE.md) and [TUTORIALS.md](TUTORIALS.md). No command in the no-training tutorials fits a model.

The package contains the recovered identity mapping and frozen split/folds; 106 fitted checkpoints; 70 final prediction sets with constrained/unconstrained decoding; conditional summaries; manual-status, historical-role, threshold and station diagnostics; fresh replay receipts; and the revised manuscript documents and 21 figures in PNG/PDF. The models are the corrected run, not models relabelled from earlier releases.

Fresh GPU replay on the recorded machine reproduced 18,528 OOF tensors and 1,980 test meta tensors exactly, and all 70 prediction sets without pick/status mismatches. The public replay entry point replaces large cache files with feature checksums and accepts explicit input/output paths. Its smoke tests are recorded separately from the exhaustive original replay. Training is complete: 40 main/ablation fits, 60 additional base/meta fits and six PhaseNet-style fits.

The computational contribution is an inspectable integration of identity recovery, grouped feature generation, checkpoint provenance and dependency-aware evaluation. It does not claim a new grouped-OOF algorithm or best-performing picker. On this fixed split, conditional intervals support the baseline's P advantage; primary accepted-scoring S method differences remain unresolved. Component-access differences occur in both approaches. Historical development exposure prevents an independent-confirmation claim.

See [COMPUTATIONAL_CONTRIBUTION.md](COMPUTATIONAL_CONTRIBUTION.md) for scope and [CG_REPOSITORY_CHECKLIST.md](CG_REPOSITORY_CHECKLIST.md) for historical C&G repository requirements. Release source-verified-v2.0.0 at Git commit 8e82c781a1641191b6b56b15688d68e269b24918 is archived at [https://doi.org/10.5281/zenodo.22824997](https://doi.org/10.5281/zenodo.22824997). The archive was downloaded and verified against all 1,241 package-manifest entries and all 2,471 Git blobs, including 106 checkpoints. Current availability wording and documentation were updated after DOI assignment; those later text revisions are not claimed to be inside the immutable archive. Fitted checkpoints and numerical model results are unchanged. The current revision additionally supplies a verified retained-CSV reconstruction utility; that new utility and its receipts are not contents of the existing DOI archive.

## Document and archive versions

Use [documents/ESI_20260925_Round2](documents/ESI_20260925_Round2/README.md) for the current manuscript, cover letter, optional highlights and Online Resource 1 PDF. Earlier CG documents remain in documents/ for provenance. The 25 September ESI revision is not inside the existing Zenodo archive. Its title differs from the archived software title, which remains correctly recorded in CITATION.cff. No release tag, DOI record, checkpoint, frozen input or model-result artifact was changed; the new reconstruction companion is a separate addition.

## Verified HDF5-to-CSV route

See the [reconstruction companion](documents/ESI_20260925_Round2/Reconstruction/README.md). All 2,234 retained exports matched frozen complete-file hashes in the tested local HDF5; no original CSV contents were used to generate the outputs. A separate write smoke check and tampered-hash rejection passed. This recovers the selected exports, not the historical subset-selection procedure. No training or new inference was performed. Current manuscript figure numbering follows the round-2 document folder; the original `figures` folder remains unchanged for provenance.

Article type for the current ESI submission: **Methodology**. The cover letter and manuscript framing describe a case-tested evaluation/provenance methodology. The PhaseNet-style model is a case-study comparator.
