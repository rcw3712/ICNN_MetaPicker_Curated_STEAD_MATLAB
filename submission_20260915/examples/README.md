# Synthetic protocol checks

In MATLAB, with `runner/tests` on the path, run `test_clean_protocol`. It uses synthetic records, performs no network training, and tests source isolation, augmentation identity, sample-to-time conversion, P-gated S decoding, accepted versus detected-only metrics, source-paired intervals, and ensemble channel selection. Expected final output begins `PASS: 40-job plan`.

For a waveform-free numeric example, run `python analysis/reproduce.py --verify` from the package directory. It uses published derived predictions. No waveform download, AI service, or GPU is required for that route.
