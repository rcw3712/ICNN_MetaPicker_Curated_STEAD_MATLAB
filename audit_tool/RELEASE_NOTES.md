# seismic-eval-audit 0.1.1

Python audit package for supplied source memberships, lineage, OOF exclusions, feature order, artifact hashes and historical roles. This version adds real STEAD artifact checks and an ETHZ station-key audit. No training or inference was performed.

- 27 local tests and 27 installed-wheel tests pass.
- The actual recovered historical split fails: 151/335 test records share training sources, 168/335 training or validation sources.
- Corrected source memberships pass; history reports 196/221 test sources with prior development roles.
- 30 OOF configuration/fold checks, 106 checkpoint hashes and 93 public-code hashes pass.
- 9,264 receipt-derived augmentation links pass within their stated reconstructed-lineage scope.
- ETHZ supplied split is source-disjoint but shares 180 network.station keys between train and test.

Core runtime: Python 3.10+, standard library only. MIT software license; original dataset terms remain applicable. Standalone wheel and source package are attached. The full historical model archive remains available under the older DOI 10.5281/zenodo.22824997. That DOI does not identify this new tool. No new Zenodo DOI is asserted.

Feature-schema tests are synthetic; no new real-tensor schema validation or independent predictive confirmation is claimed. See case_studies/results and manuscript for evidence boundaries.
