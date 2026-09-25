# Earth Science Informatics - targeted revision, round 2

Use [README_UPLOAD_ESI.md](README_UPLOAD_ESI.md) for the individual upload files and [REVISION_REPORT.md](REVISION_REPORT.md) for changes and verification. The four current Word files and Online Resource 1 PDF are in [Documents](Documents); revised numbering and the new workflow figure are in [Figures](Figures).

The [retained-input reconstruction companion](Reconstruction/README.md) contains the no-training utility, two input mapping/hash files, tested environment and receipts. It regenerated all 2,234 retained CSV byte hashes in the tested local HDF5 archive; the historical subset-selection procedure remains unresolved.

This presentation and the new utility postdate DOI 10.5281/zenodo.22824997. Fitted checkpoints, performance values, frozen splits and old archive are unchanged. The previous ESI and CG documents are preserved in their original folders. No new training, model replay, release or journal submission was performed in this revision.

Article type for the current ESI submission: **Methodology**. The cover letter and manuscript framing describe a case-tested evaluation/provenance methodology. The PhaseNet-style model is a case-study comparator.

The minor pre-upload revision adds checkpoint-derived parameter counts and successful-fit timings (Supplementary Table S31). The 106 fits sum to 16.73 h, excluding pipeline overhead and interrupted attempts. Complete replay wall-clock time is unavailable; the retained partial timer is explicitly scoped. No training or inference was performed for this update.
