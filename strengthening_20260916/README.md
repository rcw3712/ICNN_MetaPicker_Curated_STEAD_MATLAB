# Additional seed experiments and PhaseNet-style comparator

This package accompanies release **v1.3.0** and the 16 September 2026 manuscript revision. It extends the original 40-fit experiment in [submission_20260915](../submission_20260915) with 60 additional stacking fits and six standalone PhaseNet-style fits: **106 fits overall**.

## Main findings

Mean accepted-pick F1 at ±100 ms:

| Method | Mode | P F1 | S F1 |
|---|---|---:|---:|
| Stacking | Full3C | 0.8694 | 0.5780 |
| Stacking | Z-only | 0.8723 | 0.3384 |
| PhaseNetMatched | Full3C | 0.9661 | 0.6267 |
| PhaseNetMatched | Z-only | 0.9637 | 0.3689 |

Stacking averages three meta seeds within each of three base seeds. Its Full3C minus Z-only S difference is 0.2396 (conditional paired source-cluster 95% interval 0.1874–0.2905). The standalone baseline has higher mean F1 in both modes. Conditional intervals support its P advantage in both modes and S advantage in Full3C; the Z-only S interval includes zero. These results support a component-access difference, not superior stacking performance.

All results condition on one fixed source split. Meta fits sharing a base are not independent pipelines. Bootstrap intervals condition on fitted models and omit training/split uncertainty; no multiplicity control is claimed. The baseline is a PhaseNet-style MATLAB adaptation, not the official implementation or a pretrained benchmark. Data and decoder are matched, but feature inputs, batch size and compute budgets differ. See the manuscript and runner documentation for details.

## Reproduce the numerical audit

Install Python 3.11+ and NumPy, then run from this directory:

```sh
python replay_prediction_audit.py
```

Outputs are written to `recomputed/`. The portable replay recomputes 288 metric rows from 24 prediction tables and 10,000-draw paired source-cluster intervals. It has been tested against the supplied CSV outputs. It does not verify unavailable external waveform hashes or replay checkpoints. The original local audit verified 22,830 manifest entries representing 2,283 unique files; see `audit.json`. `audit_numbers_original_paths.py` records that local audit, including its original paths.

- `runner/`: additional MATLAB experiment implementation and configuration; start with [runner/README.md](runner/README.md).
- `results/`: additional compact result CSVs and input manifests.
- `original_base42/`: the original six stacking prediction sets needed for the expanded comparison.
- `manuscript/`: revised main text, supplementary material, cover letter and highlights.
- `recomputed_metrics.csv`, `summary.csv`, `paired_intervals.csv`: independently recomputed evidence.
- `SHA256SUMS.csv`: file hashes for this package, excluding the manifest itself.

Training requires the existing project dependencies and identified STEAD inputs; adapt the runner's local paths as described in its README. Raw waveforms, checkpoints and large probability caches are not bundled. Historical runner and audit manifests retain the local execution paths for provenance.

## Archival status

The original v1.2.0 DOI 10.5281/zenodo.22760733 covers the original experiment only. This extension is identified by GitHub release v1.3.0 and its immutable tag. Zenodo archival verification, when available, is recorded in the repository-level ARCHIVE_VERIFICATION.md; no unverified new DOI is asserted in this release snapshot.
