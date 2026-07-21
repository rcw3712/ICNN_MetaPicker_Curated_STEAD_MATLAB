# Data Format Specification (Curated STEAD CSV)

## 1. Per-File CSV Format

Each of the 2,234 curated CSV files represents ONE waveform record (one event-station pair) and contains 6,000 rows (60 s @ 100 Hz). Required columns:

| Column | Type | Description |
|---|---|---|
| `sec` | float | Time axis, seconds, monotonically increasing, 0 to 60, delta ~ 0.01 |
| `E` | float | East component amplitude |
| `N` | float | North component amplitude |
| `Z` | float | Vertical component amplitude |
| `p_arrival` | float | P-wave arrival time, seconds, repeated identically on every row |
| `s_arrival` | float | S-wave arrival time, seconds, repeated identically on every row |

### Example

```
sec,E,N,Z,p_arrival,s_arrival
0.00,0.00231,-0.00142,0.00189,12.4500,18.7300
0.01,0.00198,-0.00118,0.00211,12.4500,18.7300
0.02,0.00176,-0.00099,0.00195,12.4500,18.7300
...
```

## 2. Metadata Master CSV (metadata_master_latest.csv)

One row per curated CSV file. Full column list:

| Column | Type | Description |
|---|---|---|
| `file_name` | string | CSV file name |
| `file_path` | string | Full path to the CSV file |
| `event_id` | string | Identifier derived from file name |
| `source_id` | string | Earthquake source identifier (== event_id if fallback) |
| `trace_name` | string | Trace identifier |
| `trace_category` | string | e.g. earthquake_local |
| `source_distance_km` | float | Epicentral distance |
| `source_magnitude` | float | Earthquake magnitude |
| `min_snr_db` | float | Minimum SNR across channels, dB |
| `p_status` | string | e.g. manual |
| `s_status` | string | e.g. manual |
| `sampling_rate_hz` | float | 100 |
| `n_samples` | int | 6000 |
| `duration_sec` | float | 60 |
| `channel_order` | string | "E,N,Z" |
| `p_arrival_sec` | float | P arrival, seconds |
| `s_arrival_sec` | float | S arrival, seconds |
| `p_arrival_sample_0based` | int | round(p_arrival_sec * samplingRate) |
| `s_arrival_sample_0based` | int | round(s_arrival_sec * samplingRate) |
| `p_arrival_sample_1based` | int | 0-based + 1 |
| `s_arrival_sample_1based` | int | 0-based + 1 |
| `qc_nan_inf` | string | true/false, set by QC |
| `qc_flatline` | string | true/false, set by QC |
| `qc_length` | string | true/false, set by QC |
| `qc_arrival_order` | string | true/false, set by QC |
| `qc_status` | string | pass/warning/fail, set by QC |
| `quality_flag` | string | good/moderate/poor/rejected, set by QC |
| `split_group` | string | train/val/test, set by splitting |
| `experiment_mode` | string | full3C/Zonly/etc., set by run scripts |
| `filter_version` | string | Provenance tag |

See `metadata/metadata_master_latest_template.csv` for an example file, and `metadata/metadata_master_latest_data_dictionary.csv` for a machine-readable column dictionary.

## 3. Sample-Index vs. Second-Based Arrivals

All arrivals are stored in SECONDS in the CSV (p_arrival, s_arrival) and metadata master (p_arrival_sec, s_arrival_sec). Sample-index fields are DERIVED at load time as round(arrival_sec * samplingRate). generateGaussianMasks.m internally converts the configured Gaussian sigma (samples) to seconds before applying it to the sec-based time vector.

## 4. Recovering a Genuine STEAD source_id

The curated CSV files may not retain STEAD's original source_id (which groups multiple stations recording the same earthquake). If you have an auxiliary mapping file:

```matlab
sourceMap = readtable('auxiliary_source_id_mapping.csv');
[tf, loc] = ismember(metadata.event_id, sourceMap.trace_name);
metadata.source_id(tf) = sourceMap.source_id(loc(tf));
```

Re-save metadata_master_latest.csv with the corrected source_id column before running splitBySourceID.m.

Without this step, splitBySourceID.m detects that source_id == event_id for all records and falls back to event-level splitting, emitting an explicit warning.

## 5. Adapting to a Different CSV Naming Convention

If your curated CSV files are named with a compound pattern that encodes the true source_id (e.g. source_id_receiverCode_traceName.csv), modify the event_id extraction logic in loadSingleSTEADCSV.m (see "ADAPTATION NOTES" at the end of that file) to parse out the genuine source_id from the file name.
