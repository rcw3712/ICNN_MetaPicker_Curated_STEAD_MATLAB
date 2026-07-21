% =========================================================================
% splitBySourceID.m  (src/splitting/)
% =========================================================================
% PURPOSE:
%   Split the dataset into train / validation / test subsets at the
%   SOURCE level (earthquake event), guaranteeing zero leakage of the
%   same earthquake across subsets. Automatically falls back to
%   event_id-based splitting (splitByEventID.m) if source_id is not a
%   genuine STEAD source_id (i.e., when it was derived purely from file
%   names, as flagged by buildMetadataFromCSVFolder.m).
%
% INPUT:
%   dataClean - struct array, output of qcWaveformDataset.m
%   config    - struct, framework configuration (uses config.splitKey,
%               config.trainRatio, config.valRatio, config.testRatio)
%
% OUTPUT:
%   trainData, valData, testData - struct arrays, disjoint subsets
%   splitInfo - struct with fields .keyUsed ('source_id'|'event_id'),
%               .isFallback (logical), .trainIDs, .valIDs, .testIDs
%
% NOTES:
%   source_id-based split prevents the same earthquake event from
%   appearing in both train and test. If source_id is missing or appears
%   to be a simple alias of event_id (which is the case whenever metadata
%   was built via buildMetadataFromCSVFolder.m without an auxiliary
%   STEAD source_id file), this function still performs the split — using
%   whatever identifier is available — but emits an explicit warning so
%   the limitation is documented in the experiment log and manuscript.
%
%   If source_id is missing, event_id is used as a temporary fallback,
%   but original STEAD source_id is preferred.
%
%   Output files (CSV):
%       results/splits/train_source_ids.csv
%       results/splits/val_source_ids.csv
%       results/splits/test_source_ids.csv
% =========================================================================

function [trainData, valData, testData, splitInfo] = splitBySourceID(dataClean, config)

% ── Determine which key to use ────────────────────────────────────────────
hasSourceID = isfield(dataClean, 'source_id') && ...
    ~all(cellfun(@isempty, {dataClean.source_id}));

isFallback = false;
if hasSourceID
    % Check whether source_id appears to be a genuine STEAD identifier or
    % merely an alias of event_id (heuristic: if every record has
    % source_id == event_id, it is very likely the file-name fallback).
    sameAsEventID = arrayfun(@(d) strcmp(d.source_id, d.event_id), dataClean);
    if all(sameAsEventID)
        isFallback = true;
        warning('splitBySourceID:fallbackDetected', ...
            ['source_id is missing. event_id is used as fallback. Strict ' ...
             'STEAD source-level leakage-free split requires original ' ...
             'source_id. Proceeding with event_id-equivalent split — ' ...
             'see docs/data_format.md and docs/reproducibility_notes.md.']);
    end
    keyField = 'source_id';
else
    isFallback = true;
    keyField = 'event_id';
    warning('splitBySourceID:noSourceIDField', ...
        ['source_id field not found. event_id is used as fallback. ' ...
         'Strict STEAD source-level leakage-free split requires original ' ...
         'source_id.']);
end

fprintf('  Split key: %s%s\n', keyField, ternary(isFallback,' (fallback)',''));

% ── Delegate to the generic ID-based split implementation ────────────────
[trainData, valData, testData, splitIDs] = splitByGenericID(dataClean, keyField, config);

splitInfo.keyUsed    = keyField;
splitInfo.isFallback = isFallback;
splitInfo.trainIDs   = splitIDs.trainIDs;
splitInfo.valIDs     = splitIDs.valIDs;
splitInfo.testIDs    = splitIDs.testIDs;

% ── Save ID lists ─────────────────────────────────────────────────────────
outDir = fullfile(config.outputFolder, 'splits');
ensureDir(outDir);
writeIDList(splitIDs.trainIDs, fullfile(outDir, 'train_source_ids.csv'), keyField);
writeIDList(splitIDs.valIDs,   fullfile(outDir, 'val_source_ids.csv'),   keyField);
writeIDList(splitIDs.testIDs,  fullfile(outDir, 'test_source_ids.csv'),  keyField);
fprintf('  Split ID lists saved to: %s\n', outDir);

end

% =========================================================================
% splitByEventID.m  (src/splitting/)
% =========================================================================
% PURPOSE:
%   Explicit event_id-based split, used directly when the caller knows
%   in advance that source_id is unavailable, or called internally by
%   splitBySourceID.m as the fallback path.
%
% INPUT/OUTPUT: identical contract to splitBySourceID.m, but always uses
%   event_id regardless of source_id availability.
% =========================================================================


function validateNoLeakage(trainIDs, valIDs, testIDs, keyField)
overlapTV = intersect(trainIDs, valIDs);
overlapTT = intersect(trainIDs, testIDs);
overlapVT = intersect(valIDs,   testIDs);

leak = false;
if ~isempty(overlapTV)
    warning('splitByGenericID:leakage', '%d %s overlap between train and val!', numel(overlapTV), keyField);
    leak = true;
end
if ~isempty(overlapTT)
    warning('splitByGenericID:leakage', '%d %s overlap between train and test!', numel(overlapTT), keyField);
    leak = true;
end
if ~isempty(overlapVT)
    warning('splitByGenericID:leakage', '%d %s overlap between val and test!', numel(overlapVT), keyField);
    leak = true;
end

if leak
    error('splitByGenericID:leakageDetected', ...
        'Data leakage detected in %s split. Aborting pipeline.', keyField);
else
    fprintf('  Leakage validation: PASS — zero %s overlap across subsets.\n', keyField);
end
end


function writeIDList(ids, outPath, keyField)
T = table(string(ids), 'VariableNames', {keyField});
writetable(T, outPath);
end


function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end


function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
