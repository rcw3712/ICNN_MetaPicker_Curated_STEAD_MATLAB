# Documentary provenance of the decoder configuration

The numerical settings are documented in commit `f566a26b3be54f204c28db7090219669ff1a8daa` (Git author date 21 July 2026) and unchanged in the inspected August configuration and September v1.2.0/v1.3.0 configurations: accepted/detected peak boundary 0.30, quality threshold 3 for P and S, and an S search window from 0.1 to 30 seconds after accepted P. The current uncertain boundary is explicitly `0.5 * pickProbThreshold = 0.15` in the current decoder.

The v1.0.0 GitHub release metadata reports publication on 21 July 2026 at 04:34 UTC. Historical commit links and SHA-256 hashes of configuration blobs are in `threshold_history.json`. This documents the existence of these settings before the September experiment extension; Git dates and retained code do not identify all data inspected during their earliest development.

This is **documentary configuration provenance**, not a validation-only calibration study. No retrospective claim is made that test labels never informed the initial choices. The current clean decoder also has implementation-specific domain and gating rules; numerical settings persisting across versions do not prove identical legacy decoder behavior. The September decoder and configuration copies are identified in `function_provenance.json` and the package hash manifest.

No threshold optimization, retraining, or new source split was performed for this software/reproducibility revision. Reusing these fixed settings preserves the published estimand and reported numbers. Synthetic boundary tests exercise uncertain-P gating, rejected-P gating, and the upper S-window endpoint, but do not validate the historical choice of thresholds.

Historical source: https://github.com/rcw3712/ICNN_MetaPicker_Curated_STEAD_MATLAB/blob/f566a26b3be54f204c28db7090219669ff1a8daa/config/config_ICNN_MetaPicker.m
Historical release: https://github.com/rcw3712/ICNN_MetaPicker_Curated_STEAD_MATLAB/releases/tag/v1.0.0
