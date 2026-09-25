# Targeted pre-submission revision - 25 September 2026, round 2

## Scope and decision

Completed the requested focused revision without training, new model inference, threshold tuning or changes to performance values. The package is prepared for author review and upload to Earth Science Informatics. It is not a submission or an assurance of editorial acceptance.

## Changes

- Main Table 3 states workflow contracts, enforcement stages, evidence types and limitations. Synthetic negative controls are distinguished from audits of actual membership and actual replay.
- Main Table 4 specifies the feature interface; Table 5 distinguishes synthetic/numerical inspection, frozen-model replay, retained-input reconstruction and unsupported full historical reconstruction/independent confirmation.
- Figure 1 was redrawn as computational flow plus its verification layer. The separate deliverables include a 600 dpi PNG and vector PDF. All other plotted data are unchanged; file numbering follows the revised captions.
- Introduction adds explicit research questions and substantive positioning against dependence-aware validation, model selection, leakage, PROV-DM and FAIR. Five references were verified: Cawley and Talbot (2010), Roberts et al. (2017), Kapoor and Narayanan (2023), Moreau and Missier (2013), Wilkinson et al. (2016).
- Expanded base/meta-seed results lead the Results. Results and Discussion are separated. Base-42 tables and diagnostic graphics are moved to Online Resource 1. All 34 original numerical table contents and all 23 Word equation objects are retained; three new explanatory tables were added. Main: 7 tables and 7 figures. Supplement: 30 tables and 14 figures.
- Clarified the 70-output/1,260-metric accounting, lack of noise-only false-alarm testing, validation tensors not included in fresh replay, and hardware/version limits.
- Abstract, conclusion, availability statements, cover letter and optional highlights now include the tested reconstruction route with its proper scope. Historical development exposure and conditional fixed-split interpretation remain explicit.

## New no-training verification

The regeneration utility reads the HDF5 and trace mapping, reconstructs each CSV byte stream, and compares frozen hashes. Results: 2,234/2,234 source matches; 2,234/2,234 numerical waveform matches; 2,234/2,234 complete CSV byte matches; zero errors. The complete check took 145.3 s without writing the entire CSV collection. A two-record write smoke test and deliberately corrupted hash negative control passed. Receipts and exact environment accompany the utility.

This closes the tested retained-input reconstruction gap. It does NOT recover the historical filtering/subset-selection procedure, perform new training, establish a different archive version, or remove historical development exposure. No new predictive-confirmation claim is made.

## Numbering map

Old main Tables 3/4/5 are Supplementary Tables S28/S29/S30. Old main Tables 6/7 retain their numbers. New main Tables 3/4/5 are contracts, feature interface and reproduction levels.

Old main Figs. 2/3/4 retain their numbers; old 11/12/14 become main 5/6/7. Old main 5/6/7/8/9/10/13 become supplementary S8/S9/S10/S11/S12/S13/S14. Original S1-S7 remain. Only Fig. 1 was redrawn.

## Validation and preserved state

All four DOCX files were rendered with Microsoft Word; all pages were visually inspected and checked for out-of-page text. Main text: 37 pages; Online Resource 1: 37 pages; cover letter: one page; optional highlights: one page. The supplemental PDF is the Word export of the final DOCX. Cross-reference/caption checks and table/equation preservation are recorded in Audit.

The previous ESI document set, fitted checkpoints, frozen input/results artifacts and DOI archive remain preserved. The current companion utility and document presentation are later additions, not contents asserted to be in the existing DOI archive.

## Article-type alignment

The author selected Methodology, a category explicitly supported by the ESI author guidelines. The cover letter, abstract, Introduction and submission metadata were aligned accordingly. This does not assert a new stacking algorithm or superior picker performance; the contribution remains a case-tested evaluation/provenance methodology. https://link.springer.com/journal/12145/submission-guidelines

## Minor revision v3

Main text remains 37 pages. Online Resource 1 now has 31 tables and 38 pages after adding checkpoint-derived model sizes and recorded fit times. Model names and Z-only labels in tables were standardized without changing numeric values. See MINOR_REVISION_NOTES.md and Audit/model_resources_summary.json. Original equations and historical-exposure limitations were preserved exactly.
