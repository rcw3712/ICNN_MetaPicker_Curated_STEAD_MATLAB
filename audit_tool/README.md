# Seismic evaluation audit

A small Python tool for checking supplied earthquake identifiers across data splits. It does not train or recommend a picker. Python 3.10+; core checks use only the standard library. MIT software license. Version 0.1.1. Versioned source and assets: https://github.com/rcw3712/ICNN_MetaPicker_Curated_STEAD_MATLAB/releases/tag/seismic-eval-audit-v0.1.1

## Five-minute start

From this audit_tool directory:

```powershell
python -m unittest discover -s tests -v
python -m seismic_eval_audit examples/metadata.csv --output NEW_REPORT
```

Or install with `python -m pip install .` and use `seismic-eval-audit` from any directory. Existing output directories are never overwritten. Exit codes: 0 for PASS or WARNING, 1 for detected overlap, 2 for invalid input or I/O failure. Read the report status; exit zero is not a general certification.

Your CSV must have unique record_id, source_id and split text columns. Existing column names can be selected:

```powershell
python -m seismic_eval_audit YOUR_METADATA.csv --record trace_name --group source_id --split split --output NEW_REPORT
```

IDs remain text, including leading zeros. Missing IDs, duplicate record IDs, null-like IDs and surrounding whitespace are rejected. A one-split file produces WARNING. Dev and val are not silently merged; harmonize documented split labels before use.

## Python API

```python
from seismic_eval_audit import read_csv, audit_split, assign_split, write_report
rows = read_csv('examples/metadata.csv')
report = audit_split(rows)
print(report['status'], report['pairs'])
new_rows = assign_split(rows, grouped=True, seed=42)
assert audit_split(new_rows)['shared_sources'] == 0
write_report(report, 'NEW_REPORT')
```

Additional APIs: check_lineage(parents, children), check_oof(held, fit, inner_validation), check_schema(actual, expected), check_artifacts(root, entries), audit_history(current, history). See tests for executable schemas and positive/negative examples. The CLI runs the split check only; no other check is implied. For dataframe users, pass `df.to_dict('records')` after preserving text identifiers. No dependency on SeisBench or MATLAB is needed.

The grouped splitter sorts IDs, uses Python random.Random(seed), allocates floor(0.7*N) and floor(0.15*N) groups to train/dev, and assigns remaining groups to test. Fractions are by group, not by record; no stratification or optimal balancing is claimed. Its output changes the evaluation population and is not a fair before/after performance comparison.

## ETHZ reproduction

Download only metadata with `python fetch_ethz.py --output NEW_METADATA.csv`. The expected SHA256 identifies the tested version; the downloader rejects changed bytes. Then run:

```powershell
python run_ethz.py --metadata NEW_METADATA.csv --output NEW_ETHZ_RESULTS
```

The three conditions are the supplied split, an intentionally created random record split, and a grouped split. Reported overlap in the random control is not a claim about the supplied SeisBench split. Actual run receipts accompany this package. No waveform, neural inference, model accuracy or source catalogue truth is checked.

## Interpretation

FAIL means the declared exclusion rule is violated under supplied IDs. PASS does not establish physical correctness of IDs, absence of near duplicates, independent development history, or station/region transfer. All history reports remain WARNING: recorded roles do not certify independence. Hash agreement establishes identity with a reference, not correctness of that reference. No fuzzy event grouping is provided. The separate legacy HDF5 reconstruction utility belongs to the retained STEAD case study and is not required by this tool.

The metadata retain their original upstream terms; the MIT license applies to software only. The older DOI identifies the historical model/result archive, not this new package. The new version is identified by its Git release tag; no new Zenodo DOI is asserted.

## Real artifact demonstration

27 automated tests pass. `audit_history` now separates prior train/val, prior-test-only, unknown and other documented roles and counts both sources and records. Role labels are explicit and configurable. `--strict` maps CLI warnings to exit 1 for CI; invalid input remains exit 2.

```powershell
python -m seismic_eval_audit examples/historical_stead.csv --output NEW_REPORT
python audit_case_studies.py --stead-root ../source_verified_v2 --ethz NEW_METADATA.csv --output NEW_CASE_RESULTS
```

The first command intentionally returns exit 1: the recovered historical split has 283 sources spanning subsets; 151/335 test records share training sources, or 168/335 training/validation sources. This is a real historical failure, not an injected control. The corrected split passes. Current test history reports 196 sources/304 records with prior development roles, and 25 sources/26 records with prior-test-only roles.

Six saved OOF tables (five folds each) pass 30 configuration/fold checks against the actual inner-fold tables. Actual bytes of 106 checkpoints and 93 public code files match their existing manifests. All checks read artifacts only; no MATLAB, inference or training is invoked.

Lineage evidence is narrower: 9,264 child audit keys and training labels are reconstructed from existing OOF replay receipts; their source/fold linkage agrees with frozen parents. This is not an original training-time augmentation manifest and does not audit child waveform bytes. Feature-schema behavior remains demonstrated by synthetic controls only.

For ETHZ, 180 network.station keys are shared by training and testing (9,637/10,485 test records), although the supplied split has no shared source IDs. The generic report retains legacy JSON keys `sources` and `shared_sources`; for station audits these count station keys, as specified by `group_column=station_key`. This fails an unseen-station exclusion contract, not the intended source-disjoint contract. The key does not distinguish deployment epochs.

`case_studies/results` provides reports; `case_studies/results/input_hashes.csv` identifies the frozen inputs. Raw ETHZ metadata and waveforms are not redistributed. Tests for additional APIs are executable usage examples.
