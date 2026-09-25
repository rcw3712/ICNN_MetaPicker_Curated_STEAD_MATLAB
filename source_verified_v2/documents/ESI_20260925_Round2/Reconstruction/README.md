# Verified retained-CSV reconstruction

This optional no-training utility reconstructs the retained exports from the supplied STEAD HDF5 trace mapping. It does not reconstruct historical filtering or subset selection. Original waveform CSV contents are not used as reconstruction inputs. Raw waveforms and HDF5 are not distributed here.

## Tested environment

Python 3.12.14, NumPy 2.5.3, pandas 3.0.1, h5py 3.16.0. Install the optional dependencies in a dedicated environment:

```powershell
python -m pip install -r requirements-regeneration.txt
```

From this Reconstruction directory, set the actual HDF5 path and a NEW output directory outside the package. The following local path is an example, not a required drive layout:

```powershell
python regenerate_retained_csv.py --hdf5 "D:\STEAD_identity_recovery\merge.hdf5" --package . --output "D:\STEAD_regeneration_audit_new"
```

This checks the complete retained collection in memory, record by record, and writes receipts only. Add `--write-csv` with a different new output directory to materialize hash-matching CSVs:

```powershell
python regenerate_retained_csv.py --hdf5 "D:\STEAD_identity_recovery\merge.hdf5" --package . --output "D:\STEAD_regenerated_csv_new" --write-csv
```

`--limit 2` is a smoke check, never evidence of complete reconstruction. An existing output directory is rejected. A source, waveform or CSV mismatch prevents that file from being written and results in nonzero exit status. Successful files can remain in a partial output directory after a mismatch; inspect all receipts before using a collection. Do not change expected hashes to make another export pass.

## Verified result and serialization

All 2,234 retained source identifiers, numerical waveforms and complete CSV byte hashes matched, with zero errors, in 145.3 seconds on the author workstation. Full verification did not write the complete CSV collection. A separate two-record write check passed, and a deliberately altered expected hash was rejected without writing the mismatched record. This is a data-reconstruction check, not a training-cost benchmark or a newly executed model replay.

The profile uses float32 E/N/Z; float64 `arange(6000)*0.01`; `00:00:ss.mmm` time strings; `int(arrival_sample)*0.01`; pandas default floating-point serialization; UTF-8 and CRLF. Waveform fingerprints use little-endian float32 in column-major E/N/Z order. Complete-file SHA-256 checks protect time-grid, labels and serialization as well as waveforms. Merely dividing the sample index by 100 can change floating-point serialization.

The utility consumes `inputs/partition_membership.csv` and `inputs/waveform_hashes.csv`. In the full Git package it can be invoked with `--package source_verified_v2`; in this self-contained companion use the Reconstruction directory. The output CSVs can supply the existing `replay_v2` interface after all hashes pass. No models, thresholds, labels, split or fold membership are changed.

Receipts apply to the tested local archive and software environment. They do not establish another archive version, cross-device inference equivalence, or independent predictive confirmation. Historical selection decisions remain unresolved. This utility and its receipts postdate DOI 10.5281/zenodo.22824997 and are not asserted to exist inside that immutable archive. STEAD inputs retain upstream distribution terms; software is MIT licensed as in the repository.
