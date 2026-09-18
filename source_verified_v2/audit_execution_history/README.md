# Local execution scripts

These files preserve the scripts used in the local audit. They are not a standalone distribution of the training project or input data. No model fitting is called by the replay harness.

To rerun on another computer, configure the project, result, prepared metadata and waveform CSV roots near the top of the MATLAB/Python scripts. Install MATLAB R2024a with the project dependencies, NumPy, matplotlib and python-docx as relevant. The MATLAB PhaseSkipCrop class is required from strengthening/clean. The recorded replay used an RTX 3060 Laptop GPU. Start with one MATLAB process if memory is limited.

The scripts use their parent directory as an audit workspace. For that original layout, place audit outputs in sibling directories named audit_replay_threshold_station_20260918, audit_no_training_20260918 and audit_full_20260918. This delivery organizes those files under Audit for review; restore the layout or update the paths before execution. PriorNumericalReference and HistoricalRolesAndManual provide comparison tables; document-authoring scripts also require the preceding source DOCX package. Raw waveforms, training code, model checkpoints and the full HDF5 fingerprint database are not duplicated here.

Typical inference order is prepare_replay_audit.py, run_replay_audit.py, audit_threshold_v2.py, audit_station_v2.py, finalize_replay_audit.py. Preparation creates a new protocol timestamp: preserve the supplied frozen protocol rather than overwriting it if only reviewing this audit. run_replay_audit.py starts a fresh complete replay; resume_oof_replay.py and finish_oof_parallel.py record the interrupted/resumed local execution history and assume their stated starting counts. They are not generic resume utilities.

The first eight test stages used the execution-history harness. OOF replay uses equivalent 128-record cache blocks to avoid repeated MAT-file indexing overhead. Full3C seeds 42/43 ran sequentially; the remaining four groups ran in two processes. Every completed group has a full receipt. Logs from incomplete exploratory or deliberately interrupted audit attempts are not presented as completed receipts.

Document authoring order was integrate_replay_docs.py, compact_replay_main.py, polish_replay_main.py and polish_replay_supp.py, followed by content verification and Word/PyMuPDF visual checks. Rendering PDFs are internal QA artifacts.

No repository push, release publication, threshold selection or training is performed by this package operation.
