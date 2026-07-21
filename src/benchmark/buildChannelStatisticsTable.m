function statT = buildChannelStatisticsTable(statRows, variableNames, outputPath)
% buildChannelStatisticsTable.m
% =========================================================================
% PURPOSE:
%   Safely convert statRows (nested cell vector OR rectangular cell matrix)
%   to a MATLAB table with explicit schema validation.
%   Never truncates data or names. Reports exact mismatch and stops.
%
% INPUTS:
%   statRows      - cell vector {row1, row2, ...} where each row is a
%                   1xM cell, OR a rectangular NxM cell matrix.
%   variableNames - {1xM} cell of char, exact column names.
%   outputPath    - char, path to save CSV (empty = skip save).
%
% OUTPUT:
%   statT         - MATLAB table with named columns.
% =========================================================================

statT = table();

if isempty(statRows)
    warning('buildChannelStatisticsTable: no rows supplied -- returning empty table.');
    return;
end

%    Detect format: nested cell vector vs rectangular cell matrix           
if isvector(statRows) && iscell(statRows) && all(cellfun(@iscell, statRows))
    % Format B: cell vector {row1_cell, row2_cell, ...}
    rowLengths = cellfun(@numel, statRows);
    if numel(unique(rowLengths)) ~= 1
        fprintf('[buildChannelStatisticsTable] Row field counts: %s\n', mat2str(rowLengths));
        error('buildChannelStatisticsTable: inconsistent schema -- row lengths differ: %s', ...
            mat2str(rowLengths));
    end
    % vertcat with {:} unpacks to rectangular cell matrix
    statData = vertcat(statRows{:});
else
    % Format A: rectangular NxM cell matrix
    assert(iscell(statRows), ...
        'buildChannelStatisticsTable: statRows must be a cell array.');
    statData = statRows;
end

%    Schema validation                                                      
nCols    = size(statData, 2);
nNames   = numel(variableNames);

if nCols ~= nNames
    fprintf('[buildChannelStatisticsTable] DATA has %d columns.\n', nCols);
    fprintf('[buildChannelStatisticsTable] VariableNames has %d names:\n', nNames);
    disp(variableNames);
    error(['buildChannelStatisticsTable: schema mismatch -- ' ...
           'data has %d columns but VariableNames has %d names. ' ...
           'Do NOT truncate either side.'], nCols, nNames);
end

%    Build table                                                             
statT = cell2table(statData, 'VariableNames', variableNames);

%    Save CSV if path provided                                              
if nargin >= 3 && ~isempty(outputPath)
    ensureDir(fileparts(outputPath));
    writetable(statT, outputPath);
    fprintf('  [ChannelStats] Saved: %s\n', outputPath);
end
end

function ensureDir(d)
if ~isempty(d) && ~isfolder(d); mkdir(d); end
end
