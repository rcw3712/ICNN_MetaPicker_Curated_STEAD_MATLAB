# Computational contribution and demonstrated reuse

The contribution is an inspectable implementation of source-identity and artifact contracts across a hierarchical seismic picking pipeline. Grouped cross-validation, stacking, hashes and bootstrap are established techniques. No novelty is claimed for those algorithms individually, nor for a new best-performing picker.

| Reusable component | Failure made observable | Executable evidence |
|---|---|---|
| Source identity carried through split, augmentation and OOF stages | A source re-enters fit/validation/test through another record or augmented copy | `pipeline_contracts.py`; `demonstrate_contracts.py`; all-checkpoint source audit |
| Canonical 15-channel interface | A probability stream is substituted in the wrong model/phase position | `validate_features`; shipped MATLAB `makeMeta` and `assertRepresentation` |
| Model/record/decoder provenance | Wrong checkpoint, altered waveform or changed settings silently changes predictions | checkpoint SHA-256; waveform hash checks; immutable threshold evidence; prediction comparison |
| Dependency-aware reporting | Meta fits sharing bases are treated as independent full pipelines | `summarize_crossed_seed`; expanded audit's meta-within-base summaries |
| Two levels of replay | Agreement with a printed metric is mistaken for model-level reproduction | prediction audit versus `replay_models.m` using saved networks |

The portable Python example uses 60 synthetic records from 20 sources, three OOF folds and augmented copies. It rejects five deliberately invalid cases and verifies identities across all 24 real published prediction sets. It does not demonstrate a performance gain from leakage prevention. The MATLAB checks load all 106 saved fits and verify fitting/validation/test source separation. They also test actual decoder/conditioning functions using synthetic arrays.

GPU replay used the first three test event IDs in lexical order for each of 24 model output sets; CPU replay used the first one. Pick times and statuses matched frozen references. These are deterministic smoke subsets, not a rerun of all 335 test records. Full replay is available with `maxRecords=Inf`. The new demonstration is an audit interface around the retained experiment, not evidence that every check existed before model development.

Transfer to another geoscientific pipeline requires a meaningful group identifier, record lineage and an explicit feature schema. The current MATLAB architecture is specific to seismic picking, whereas the small Python contract functions are domain-independent. No claim of cross-domain predictive generalization follows from this software reuse.
