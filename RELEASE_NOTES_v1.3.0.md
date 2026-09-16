# Expanded seed evaluation and PhaseNet-style baseline

This release extends the original 40-fit experiment with 66 additional fits and synchronizes the revised manuscript, supplementary material, cover letter and highlights.

- Three base seeds crossed with three meta seeds in Full3C and Z-only modes.
- Six standalone PhaseNet-style MATLAB baseline fits, trained from scratch.
- Independent audit of 288 metric rows from 24 prediction tables; all match.
- Reproducible paired source-cluster intervals with 10,000 draws.
- Main Tables 6–7 and Supplementary Tables S15–S18 distinguish expanded results from original base-42 ablations.

The Full3C–Z-only stacking S difference persists (0.2396; conditional 95% interval 0.1874–0.2905). The PhaseNet-style baseline has higher mean F1 in both modes. The evidence does not support superior stacking performance. Experiments use one fixed source split; baseline data/decoder matching is not compute-budget equivalence.

See strengthening_20260916/README.md for replay instructions and limitations. Original v1.2.0 remains unchanged. Its DOI 10.5281/zenodo.22760733 does not identify this extension. Zenodo archival status will be verified separately; raw waveforms and trained checkpoints are excluded.
