function predTable = computePredictionErrors(predTable)
% =========================================================================
% computePredictionErrors.m  (src/diagnostics/)
% =========================================================================
% PURPOSE:
%   Ensure p_error_ms and s_error_ms columns are present and correct.
%   Computes: error_ms = (pred_arrival - true_arrival) * 1000
%   If columns already exist and are non-NaN, they are kept as-is.
%   Handles multiple column name conventions from different framework versions.
%
% INPUTS:
%   predTable - table, prediction CSV
%
% OUTPUTS:
%   predTable - table, with p_error_ms and s_error_ms guaranteed present
% =========================================================================

cols = predTable.Properties.VariableNames;

% Column name aliases for pred/true arrivals
predP_aliases = {'p_pred_sec','pred_p_arrival_sec','p_pick_sec'};
trueP_aliases = {'p_true_sec','true_p_arrival_sec','p_arrival_sec'};
predS_aliases = {'s_pred_sec','pred_s_arrival_sec','s_pick_sec'};
trueS_aliases = {'s_true_sec','true_s_arrival_sec','s_arrival_sec'};

for phase = {'p','s'}
    ph = phase{1};
    errCol = [ph,'_error_ms'];

    % Check if error col already fully populated
    if any(strcmp(cols, errCol))
        existing = predTable.(errCol);
        if isnumeric(existing) && sum(~isnan(existing)) > height(predTable)*0.5
            continue;   % already good
        end
    end

    % Find pred and true columns
    if strcmp(ph,'p')
        predCol = findFirstCol(predTable, predP_aliases);
        trueCol = findFirstCol(predTable, trueP_aliases);
    else
        predCol = findFirstCol(predTable, predS_aliases);
        trueCol = findFirstCol(predTable, trueS_aliases);
    end

    if isempty(predCol) || isempty(trueCol)
        warning('[computePredictionErrors] Cannot find pred/true columns for %s-wave.', upper(ph));
        if ~any(strcmp(cols, errCol))
            predTable.(errCol) = nan(height(predTable),1);
        end
        continue;
    end

    predArr = toNumeric(predTable.(predCol));
    trueArr = toNumeric(predTable.(trueCol));
    predTable.(errCol) = (predArr - trueArr) * 1000;   % convert to ms
end
end

function col = findFirstCol(T, aliases)
col = '';
for a = aliases
    if any(strcmp(T.Properties.VariableNames, a{1}))
        col = a{1}; return;
    end
end
end

function v = toNumeric(x)
if isnumeric(x); v = x;
else; v = str2double(string(x));
end
end
