# C&G repository requirements and evidence

Checked against the official [Computers & Geosciences description and repository requirements](https://shop.elsevier.com/journals/computers-and-geosciences/0098-3004) and [Elsevier Highlights guidance](https://www.elsevier.com/researcher/author/tools-and-resources/highlights), accessed 18 September 2026. The full ScienceDirect Guide for Authors returned HTTP 403 in this environment; this checklist does not assert verification of every submission-system requirement.

| Requirement | Material in this package |
|---|---|
| Public repository linked in manuscript | Repository URL in Code availability; corrected package is `source_verified_v2` |
| Clear license | Root and package MIT LICENSE; upstream data terms distinguished |
| English README and installation | README and USER_GUIDE |
| Dependencies and computational requirements | USER_GUIDE and requirements.txt |
| Reproduction material or explicit data limits plus test example | 106 checkpoints, frozen inputs, 70 prediction sets, numeric verifier, replay interface, explicit original-CSV requirement and synthetic examples |
| Typical-use tutorials | TUTORIALS with no-training commands and expected outputs |
| Inputs, outputs, options and behavior | USER_GUIDE argument table and failure behavior |
| Individual files rather than a sole compressed archive | Code, models, predictions, documents and figures are browsable separately |
| English comments in active implementation | Public v2 source comments cleaned; reversible provenance patch retained; historical folders remain archival |
| Highlights | Five real Word bullets, each at most 85 characters including spaces |
| Claims match evidence | Fixed split and conditional intervals; no independent-confirmation or best-model claim |

Full waveform replay requires original hash-matching CSV exports, not merely the numeric tables. Earlier DOIs are historical. Corrected v2 is archived at https://doi.org/10.5281/zenodo.22824997 (release source-verified-v2.0.0); subsequent availability-only revisions are documented separately. These limits are disclosed in the manuscript and repository. Scientific scope and novelty remain editorial judgments; this checklist is not an acceptance guarantee.
