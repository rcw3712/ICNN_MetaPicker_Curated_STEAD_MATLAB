# Computational contribution and scope

The reusable software connects four inspectable stages: waveform-to-source identity recovery; source-disjoint outer/OOF/inner-validation membership; feature order and augmentation lineage contracts; and hash-linked checkpoints, inference receipts and dependency-aware summaries. These are established techniques assembled to expose specific failures in a seismic picking workflow, not a new hashing, grouping or stacking algorithm.

The geoscientific use case asks how horizontal-component access changes phase-picking performance under explicit source grouping. Both stacking and the PhaseNet-style comparator show an S component-access difference on this fixed split. The baseline performs better on P. Primary accepted-scoring S method intervals include zero. No claim of best overall picker or independent confirmation is made.

Concrete evidence includes 2,234 uniquely matched records within the exhaustive local HDF5 archive audit; exclusion checks on 106 checkpoints; fresh replay of 18,528 OOF and 1,980 test tensors; and reproduction of 70 prediction sets and 1,260 metric rows. Synthetic negative controls illustrate rejected source overlap, changed augmentation parent, OOF contamination, feature-order changes and changed bytes. They demonstrate contracts, not predictive accuracy.

Transfer to another geoscientific workflow requires a scientifically appropriate grouping identity and valid reference data. Historical development exposure, shared validation, a single split, annotation-status limitations and a small unseen-station stratum constrain the present interpretation. Repository completeness cannot guarantee editorial acceptance or establish methodological novelty by itself.

## Retained-input reconstruction added in ESI round 2

The [companion utility](documents/ESI_20260925_Round2/Reconstruction/README.md) regenerated all 2,234 retained CSV byte hashes from their mapped traces in the tested local STEAD HDF5, with matching source IDs and numerical waveform fingerprints. This is a verified path to the selected inputs, not recovery of the historical filtering/subset-selection procedure. It adds no training or predictive-confirmation evidence. Contracts and reproduction levels in the current manuscript distinguish synthetic checks, actual membership audits, saved-model replay and this input reconstruction.
