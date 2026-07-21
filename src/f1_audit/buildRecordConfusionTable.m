function confT = buildRecordConfusionTable(predTable, phase, tol_ms, ...
    countUncertainAsDetected, outDir, expName)
% buildRecordConfusionTable.m
% PURPOSE: Build per-record confusion labels for conventional and current F1.
% INPUTS:
%   predTable              -- locked prediction table
%   phase                  -- 'P' or 'S'
%   tol_ms                 -- tolerance in ms
%   countUncertainAsDetected -- logical
%   outDir                 -- output directory
%   expName                -- 'Full3C' or 'Zonly'
% OUTPUT: confT -- MATLAB table with per-record classification

N = height(predTable);
keys = buildStableRecordKey(predTable);
sids = safeStr(predTable,'source_id');

c = lower(phase);
trueCol = ternary(strcmp(c,'p'), 'p_true_sec',  's_true_sec');
predCol = ternary(strcmp(c,'p'), 'p_pred_sec',  's_pred_sec');
statCol = ternary(strcmp(c,'p'), 'p_status',    's_status');
errCol  = ternary(strcmp(c,'p'), 'p_error_ms',  's_error_ms');

trueV = safeNum(predTable, trueCol);
predV = safeNum(predTable, predCol);
statV = safeStr(predTable, statCol);
errV  = safeNum(predTable, errCol);

% Recompute error if NaN
mask_recomp = isnan(errV) & ~isnan(predV) & ~isnan(trueV);
if any(mask_recomp)
    errV(mask_recomp) = (predV(mask_recomp) - trueV(mask_recomp)) * 1000;
end

rows = cell(N, 18);
for i = 1:N
    % Ground truth
    gtSec = trueV(i);
    if isnan(gtSec)
        % Case 4: no ground truth (should not occur in locked test set)
        rows(i,:) = {keys{i}, sids{i}, phase, tol_ms, gtSec, predV(i), errV(i), ...
            false, false, false, 0,0,0, 0,0,0, 'INVALID','INVALID'};
        continue;
    end

    % Detected 
    isUncertain = strcmpi(statV{i},'uncertain');
    isMissing   = strcmpi(statV{i},'not_detected') || isnan(predV(i)) || isinf(predV(i));
    isDetected  = ~isMissing && (countUncertainAsDetected || ~isUncertain);

    absErr = abs(errV(i));
    withinTol = isDetected && ~isnan(errV(i)) && absErr <= tol_ms;

    % Conventional counts (Case B)
    if withinTol
        tp_conv=1; fp_conv=0; fn_conv=0; lbl_conv='TP';
    elseif isDetected
        tp_conv=0; fp_conv=1; fn_conv=1; lbl_conv='FP_plus_FN';
    else
        tp_conv=0; fp_conv=0; fn_conv=1; lbl_conv='FN_missing';
    end

    % Current (locked) counts -- FP only for out-of-tolerance
    if withinTol
        tp_cur=1; fp_cur=0; fn_cur=0; lbl_cur='TP';
    elseif isDetected
        tp_cur=0; fp_cur=1; fn_cur=0; lbl_cur='FP_only';
    else
        tp_cur=0; fp_cur=0; fn_cur=1; lbl_cur='FN_missing';
    end

    rows(i,:) = {keys{i}, sids{i}, phase, tol_ms, gtSec, predV(i), errV(i), ...
        isDetected, isUncertain, withinTol, ...
        tp_conv, fp_conv, fn_conv, ...
        tp_cur,  fp_cur,  fn_cur, ...
        lbl_conv, lbl_cur};
end

confT = cell2table(rows, 'VariableNames', {...
    'record_key','source_id','phase','tolerance_ms',...
    'true_sec','pred_sec','error_ms',...
    'detected','uncertain','within_tolerance',...
    'TP_conventional','FP_conventional','FN_conventional',...
    'current_TP','current_FP','current_FN',...
    'classification_conventional','classification_current'});

ensureDir(outDir);
fname = sprintf('%s_%s_%dms.csv', expName, phase, tol_ms);
writetable(confT, fullfile(outDir, fname));
fprintf('  [Confusion] Saved: %s\n', fname);
end

function v=safeNum(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=nan(height(t),1);return;end
v=double(t.(t.Properties.VariableNames{find(idx,1)}));
end
function v=safeStr(t,col)
idx=strcmpi(t.Properties.VariableNames,col);
if ~any(idx);v=repmat({''},height(t),1);return;end
v=cellstr(string(t.(t.Properties.VariableNames{find(idx,1)})));
end
function out=ternary(c,a,b);if c;out=a;else;out=b;end;end
function ensureDir(d);if ~isempty(d)&&~isfolder(d);mkdir(d);end;end
