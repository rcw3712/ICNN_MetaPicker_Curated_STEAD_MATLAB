# Patch Changelog — Symbol/Layout Fix Pass (Claude, 2026-07-20)

## Root cause
Across many `src/visualization/*.m` files (and the static `results/figures_publication/figure_captions.txt`),
every non-ASCII character originally used for math notation or typographic dashes had been silently
stripped to blank space at some earlier point (a lossy save/encoding conversion, not a MATLAB rendering
issue). This produced strings like `'S   P Time (s)'` instead of `'S-P Time (s)'`, and
`'exp(   (t     _P)  /2  _P  )'` instead of a valid Gaussian formula.

## Fix strategy
- For strings MATLAB actually renders (title, xlabel, ylabel, text, legend DisplayName, sgtitle,
  annotation) → replaced with **TeX mnemonics** (`\sigma`, `\mu`, `\rho`, `\times`, `\pm`, `^2`), since
  MATLAB's default `Interpreter='tex'` renders these correctly and they are plain ASCII, immune to any
  future encoding mishap.
- For `caption = sprintf(...)` strings (plain prose destined for the manuscript, not rendered by MATLAB)
  → replaced with the actual Unicode characters (σ, ρ, ×, ±, ²), since these are just text for a Word
  document.
- Dashes (en-dash separators, "S-P", "Freedman-Diaconis") → standardized to plain ASCII hyphens
  everywhere, in both figures and captions, to eliminate any residual encoding risk.

## Files changed

| File | Fix |
|---|---|
| `plotDatasetCharacteristics.m` (Fig 2) | S-P Time labels/title; `\mu=` mean-line label; caption S-P and Freedman-Diaconis |
| `plotDatasetStatistics.m` | Trimmed stray leading spaces before existing `\mu=` label |
| `plotGaussianLabel.m` (Fig 3b) | Reconstructed both Gaussian formula strings (`\mu`, `\sigma`, `^2`); caption σ_P/σ_S |
| `plotMetaFeatureTensor.m` (Fig 4) | `\times` in sgtitle, split into two lines to stop title overlap with "Base Picker Outputs"; added `'HandleVisibility','off'` to the two reference `xline()` calls that were leaking into the legend as "data1"/"data2"; tidied legend spacing; caption `[T × %d]` |
| `plotArrivalScatter.m` (Fig 7) | `R^2` in stats box; `\pm50/100/200 ms` in tolerance-band legend entries; caption `±` and `R²` |
| `plotResidualAttributes.m` (Fig 8) | `\rho=` for Spearman coefficient (was unlabeled); S-P Time xlabel; caption ρ and ± |
| `plotResidualDistribution.m` (Fig 6) | sgtitle separator dash; `\mu=` mean-line label; caption ± and "quantile-quantile" |
| `plotPercentileMetrics.m` (Fig 10) | sgtitle separator dash |
| `plotSNRPerformance.m` (Fig 9) | **Layout fix**: raised `ylim` ceiling from 1.05 to 1.30 on F1 and Detection-Rate panels so the auto-placed legend no longer covers the "High" SNR bars; caption dB ranges |
| `plotOutlierAnalysis.m` (Fig 11) | **Layout fix**: widened figure from 22 cm to 30 cm to stop the 8 subplot titles running into each other |
| `plotFailureWaveforms.m` (Fig 12 / Supp S5, not yet generated) | Cleaned `P_pred=`/`S_pred=` label spacing; added `:` separator in case title |

## Not changed
- No numeric results, data-processing logic, or statistics computation were touched — only string
  literals used for display text, plus two purely cosmetic `ylim`/figure-width layout values.
- `plotGaussianLabelExample.m`, `plotMetaFeatureExample.m`, `plotPickingResult.m`, `plotErrorHistogram.m`,
  `plotFull3CvsZonly.m`, `plotAblationResults.m`, `plotResidualVsAttribute.m` were scanned and already
  used correct TeX mnemonics (`\mu`, `\Delta`) — no changes needed.

## Recommended next step
Re-run the MATLAB pipeline's figure-generation stage to regenerate Fig. 2, 3, 4, 6, 7, 8, 9, 10, 11, and
Supp. Fig. S1 from these corrected scripts.

## Second patch pass (after first re-run test) — 2026-07-21

| File | Fix |
|---|---|
| `plotPerformanceComparison.m` (Fig 5) | **Root cause found and fixed, two separate bugs**: (1) `buildMetricList` used a MATLAB anonymous-function closure (`add = @(...) [metrics, ...]`) that captures `metrics` **by value at definition time** — every call silently discarded all earlier accumulated metrics, so only the *last* `add()` call ever survived. Replaced with a proper nested function (`addMetric`) that mutates `metrics` correctly. (2) The function was reading F1/Precision/Recall/DetectionRate from `metrics_full3C.csv`/`metrics_Zonly.csv`, which still hold the **pre-audit** F1 definition (e.g. Full3C P F1@100ms=0.921) — inconsistent with Table 4/5 and the rest of the manuscript, which use the corrected conventional-F1 numbers. Rewired to source F1/Precision/Recall/DetectionRate from `results/f1_audit/f1_conventional_summary.csv` instead (confirmed to match Table 4/5 exactly). `run_generate_all_figures.m` updated to load this file and pass it in. |
| `plotMetaFeatureTensor.m` (Fig 4) | Increased figure height (`nPickers*3+4` → `nPickers*3.7+4`, min 9 cm) so the four per-picker row labels ("Baseline CNN", "Dilated TCN", ...) no longer visually run into each other. |
| `plotResidualAttributes.m` (Fig 8) | Widened figure 22→30 cm to stop the 4-column panel titles colliding (same fix class as Fig 11 in the first pass). |
| `plotOutlierAnalysis.m` (Fig 11) | Fixed a MATLAB graphics race condition (`colorbar`/`colormap` ordering) that threw "Attempt to modify the tree during an update traversal" during export — reordered `colormap()` before `colorbar()` and added `drawnow` calls so the SNR colorbar label sets reliably. |

## Known remaining item
`metrics_full3C.csv` / `metrics_Zonly.csv` in `results/metrics/` are stale (pre-audit F1). They are no longer read by Fig 5, but if any other script still reads them directly, treat their F1/DetectionRate columns as outdated — use `results/f1_audit/f1_conventional_summary.csv` instead.
