function keys = buildStableRecordKey(t)
% buildStableRecordKey.m
% PURPOSE: Build a stable, unique record-level key for alignment.
%          Priority: file_name > event_id > trace_name > source_id+index
% INPUTS:  t -- prediction table
% OUTPUTS: keys -- {N x 1} cell of char, one per record
% ASSUMPTIONS: At least one of the candidate columns exists.

N = height(t);
cols = lower(t.Properties.VariableNames);

% Try each key column in priority order
for cand = {'file_name','event_id','trace_name','trace_start_time'}
    idx = strcmp(cols, cand{1});
    if any(idx)
        raw = t.(t.Properties.VariableNames{find(idx,1)});
        keys = cellstr(string(raw));
        % Check uniqueness
        if numel(unique(keys)) == N
            fprintf('  [RecordKey] Using column "%s" as stable key (%d unique).\n', cand{1}, N);
            return;
        else
            fprintf('  [RecordKey] "%s" is not unique (%d unique of %d) -- trying next.\n', ...
                cand{1}, numel(unique(keys)), N);
        end
    end
end

% Fallback: source_id + occurrence index
if any(strcmp(cols,'source_id'))
    sidCol = t.Properties.VariableNames{find(strcmp(cols,'source_id'),1)};
    sids = cellstr(string(t.(sidCol)));
    cnt = containers.Map('KeyType','char','ValueType','double');
    keys = cell(N,1);
    for i=1:N
        s = sids{i};
        if isKey(cnt,s); cnt(s)=cnt(s)+1; else; cnt(s)=1; end
        keys{i} = sprintf('%s__%04d', s, cnt(s));
    end
    fprintf('  [RecordKey] Fallback: source_id+index (%d entries, %d unique).\n', ...
        N, numel(unique(keys)));
else
    % Last resort: sequential index
    keys = arrayfun(@(i) sprintf('record_%05d',i), (1:N)', 'UniformOutput',false);
    fprintf('  [RecordKey] Fallback: sequential index.\n');
end
end
