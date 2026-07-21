function picks = runMeanEnsemble(metaFeatures, config)
% runMeanEnsemble.m
% Simple mean ensemble meta-learner (benchmark baseline).
% Averages probability curves from all base pickers.
% Input: metaFeatures - cell array, each [T x C_meta]
%        config       - struct framework config
% Output: picks - struct array with p_pick_sec, s_pick_sec

N = numel(metaFeatures);
picks = struct('p_pick_sec', cell(N,1), 's_pick_sec', cell(N,1), ...
    'p_status', cell(N,1), 's_status', cell(N,1), ...
    'p_quality', cell(N,1), 's_quality', cell(N,1), ...
    'p_pick_sample', cell(N,1), 's_pick_sample', cell(N,1), ...
    'p_error_ms', cell(N,1), 's_error_ms', cell(N,1));

nPickers = floor(size(metaFeatures{1}, 2) / 3);

for i = 1:N
    Z = metaFeatures{i};  % [T x C_meta]
    T = size(Z, 1);

    % Average P, S, Noise across all base pickers
    avgP = zeros(T,1); avgS = zeros(T,1);
    for pk = 1:nPickers
        colBase = (pk-1)*3 + 1;
        avgP = avgP + Z(:, colBase);
        avgS = avgS + Z(:, min(colBase+1, size(Z,2)));
    end
    avgP = avgP / nPickers;
    avgS = avgS / nPickers;

    pred{1}.P = avgP; pred{1}.S = avgS;
    pred{1}.Noise = max(0, 1 - avgP - avgS);

    p = physicsAwarePicker(pred, config);
    picks(i) = p(1);
end
end
