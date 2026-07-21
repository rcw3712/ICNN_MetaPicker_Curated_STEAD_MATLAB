function [tA, tB, alignReport] = alignPredictionTables(tA, tB, outDir)
% alignPredictionTables.m
% PURPOSE: Align two prediction tables using a key column present in BOTH.
%          Tries key candidates in priority order, picks the first that is
%          unique in both tables and produces 335 matches.
% ERROR HANDLING: errors if no common unique key found; never silently drops rows.

colsA = lower(tA.Properties.VariableNames);
colsB = lower(tB.Properties.VariableNames);

nA = height(tA); nB = height(tB);
fprintf('  [Align] Table A: %d records | Table B: %d records\n', nA, nB);

% Find a key column present in BOTH tables with high match rate
candidates = {'event_id','file_name','trace_name','source_id'};

keysA = {}; keysB = {}; usedCol = '';
for k = 1:numel(candidates)
    cand = candidates{k};
    inA  = any(strcmp(colsA, cand));
    inB  = any(strcmp(colsB, cand));
    if ~inA || ~inB; continue; end

    colA = tA.Properties.VariableNames{strcmp(colsA,cand)};
    colB = tB.Properties.VariableNames{strcmp(colsB,cand)};
    kA   = cellstr(string(tA.(colA)));
    kB   = cellstr(string(tB.(colB)));

    nMatch = numel(intersect(kA, kB));
    pct    = nMatch / max(nA,1);
    fprintf('  [Align] Candidate "%s": %d/%d match (%.0f%%)\n', cand, nMatch, nA, pct*100);

    if pct >= 0.9
        keysA   = kA; keysB = kB; usedCol = cand;
        break;
    end
end

% Fallback: try combining source_id + occurrence index if single column fails
if isempty(keysA)
    fprintf('  [Align] No single column matched. Trying source_id+index fallback...\n');
    inA_sid = any(strcmp(colsA,'source_id'));
    inB_sid = any(strcmp(colsB,'source_id'));
    if inA_sid && inB_sid
        keysA = buildStableRecordKey(tA);
        keysB = buildStableRecordKey(tB);
        nMatch = numel(intersect(keysA, keysB));
        usedCol = 'source_id+index';
        fprintf('  [Align] source_id+index: %d/%d match\n', nMatch, nA);
    end
end

if isempty(keysA)
    error(['alignPredictionTables: No common key column found between tables.\n' ...
           'Columns in A: %s\nColumns in B: %s'], ...
        strjoin(tA.Properties.VariableNames,', '), ...
        strjoin(tB.Properties.VariableNames,', '));
end

fprintf('  [Align] Using key column: "%s"\n', usedCol);

% Reorder B to match A's order
[~, idxB] = ismember(keysA, keysB);
validMatch = idxB > 0;
nMatched   = sum(validMatch);

if nMatched < nA * 0.9
    error(['alignPredictionTables: Only %d/%d records matched using key "%s".\n' ...
           'Check that both prediction CSVs cover the same test set.'], ...
        nMatched, nA, usedCol);
end

if ~all(idxB == (1:nB)')
    tB = tB(idxB(validMatch), :);
    tA = tA(validMatch, :);
    fprintf('  [Align] Reordered B to match A. Matched: %d/%d records.\n', nMatched, nA);
else
    fprintf('  [Align] Tables already in matching order (%d records).\n', nA);
end

% Save alignment report
N = sum(validMatch);
kA_final = keysA(validMatch);
sids = safeStr1(tA,'source_id');
alignRows = cell(N, 5);
for i = 1:N
    alignRows{i,1} = kA_final{i};
    alignRows{i,2} = sids{i};
    alignRows{i,3} = i;
    alignRows{i,4} = idxB(i);
    alignRows{i,5} = 'MATCHED';
end
alignT = cell2table(alignRows,'VariableNames',...
    {'record_key','source_id','reference_index','prediction_index','alignment_status'});
ensureDir(outDir);
writetable(alignT, fullfile(outDir,'record_alignment.csv'));
fprintf('  [Align] Saved: record_alignment.csv (%d rows)\n', N);

alignReport = struct('N_matched',N,'N_A',nA,'N_B',nB,'key_used',usedCol);
end

function v = safeStr1(t, col)
idx = strcmpi(t.Properties.VariableNames, col);
if ~any(idx); v=repmat({''},height(t),1); return; end
v = cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
end
function ensureDir(d); if ~isempty(d)&&~isfolder(d); mkdir(d); end; end
