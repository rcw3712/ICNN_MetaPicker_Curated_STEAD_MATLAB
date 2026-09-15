# Submission package 2026-09-15

Companion to **Source-Grouped Evaluation of Temporal Stacking for Seismic Phase Picking with Three-Component Data**. Frozen outputs derive from `submission40_v5_oofstream`. No models were retrained for this revision.

## Quick numeric and figure reproduction

Requires Python 3.11 or newer. Install packages listed in `requirements.txt` into a virtual environment, then run from this directory:

```sh
python -m pip install -r requirements.txt
python analysis/reproduce.py --verify
```

The script verifies package hashes, recomputes accepted/strict/unconstrained metrics and 10,000-draw source-cluster intervals, reports station-key overlap, and exports tables and figures to `regenerated/`. It checks 1,389 numerical/population conditions. Inspect the printed failure count; the recorded successful run has zero failures. Figure 12 needs external waveform CSVs; the other figures use supplied metadata and derived receipts. Configuration tables are documented settings, not inferred statistics. Table S1 is supplied as a full-cache statistics receipt, with an optional independent recomputation script described in the reproduction map.

To generate Figure 12 as well, set `ICNN_WAVEFORM_DIR` to the directory containing the 2,234 curated waveform CSVs before running. Use the data layout below. The small example tensor is a derived final-base feature array for `stead_event_00001`, not raw waveform data.

## Full MATLAB protocol

Requires MATLAB R2024a with Deep Learning Toolbox and Signal Processing Toolbox. GPU execution also requires Parallel Computing Toolbox and a compatible GPU. The implementation uses `trainnet`. CPU is supported, but hardware changes may change the learned weights. Memory use depends on platform; provision ample RAM and disk for waveform loading and feature caches. Streaming removes full duplicated training arrays but does not make the workflow memory-free. The original task experienced out-of-memory failures before these streaming changes.

Prepare `inputs/data/csv_stead_filtered/` with exactly 2,234 waveform files. Original STEAD `trace_name`, source IDs, and event-ID mapping are in `inputs/metadata/metadata_master_2234_final.xlsx`. The metadata and fixed split lists are already included. Each file is named `<event_id>.csv`, with 6,000 rows and columns `time,sec,E,N,Z,p_arrival,s_arrival`; sec is 0:0.01:59.99, and the P/S arrival columns repeat the authoritative seconds from the original curated export. The textual time column is ignored. Raw waveforms are obtained separately under STEAD's terms. Curated waveform hashes are in `docs/input_waveform_hashes.csv`; exact historical byte reproduction requires matching the original CSV export, not merely the same trace name.

In MATLAB, set Current Folder to `runner`, then:

```matlab
run_submission40('plan');                 % no fitting
run_submission40('train', ...
    fullfile(pwd,'..','inputs'), ...
    fullfile(pwd,'results_clean','new_run'), ...
    'gpu');                              % use 'cpu' when appropriate
```

Use a **new output directory**. Packaging changes translate comments and remove user-specific defaults, so old run manifests must not be bypassed. Resume only with identical code, paths, configuration, and data for that new run. The runner validates file hashes and model identities before reuse. Do not add legacy root scripts to the same MATLAB path.

Forty jobs comprise 20 OOF base fits, four final bases, six Full15 fits (two modes × three seeds), nine Full3C ablation fits, and one two-head logistic fit. Base seed is 42; meta seeds are 42–44. Mode-specific bases are refitted. `runner/clean/trainingPlan40.m` and the frozen ledger give exact IDs. The 2,000-draw per-seed MATLAB exports are historical diagnostics; manuscript confidence intervals are recomputed by the Python 10,000-draw analysis.

## Limits and provenance

The runner retains the trained protocol rather than redesigning validation after observing test results. Outer validation is reused by final base selection, meta early stopping, and ensemble weighting. It is not a fully nested model-selection scheme. The experiment measures unseen earthquake sources in a curated high-SNR population; 30 of 37 test network–receiver keys also occur in training. Base and split variability are outside the reported intervals.

The hash manifest covers the files in this package, excluding regenerated outputs and the manifest itself. The frozen model ledger and historical input hashes are receipts; they do not imply that large checkpoints are publicly downloadable. See `docs/REPRODUCTION.md` for exactly which outputs require these larger artifacts or a new training run. No current Zenodo version has been verified as identical to this package.
