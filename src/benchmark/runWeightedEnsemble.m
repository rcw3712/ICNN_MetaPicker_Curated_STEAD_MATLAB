function picks = runWeightedEnsemble(metaFeatures, valData, config)
% runWeightedEnsemble.m
% Weighted mean ensemble - weights optimised on validation set F1@100ms.
% Weights learned from validation OOF predictions, not from test set.

N = numel(metaFeatures);
nPickers = floor(size(metaFeatures{1}, 2) / 3);

% Learn weights on validation data using F1@100ms as objective
% Simple grid search over picker weights
fprintf('  [WeightedEnsemble] Optimising weights on val set...\n');
bestWeights = ones(1, nPickers) / nPickers;
bestF1 = 0;

% Quick grid: try giving extra weight to each picker
for pk = 1:nPickers
    w = ones(1, nPickers);
    w(pk) = 2.0;
    w = w / sum(w);
    f1 = evalWeights(metaFeatures(1:numel(valData)), valData, w, nPickers, config);
    if f1 > bestF1
        bestF1 = f1;
        bestWeights = w;
    end
end
fprintf('  [WeightedEnsemble] Best weights: [%s] F1@100ms=%.3f\n', ...
    num2str(bestWeights,'%.2f '), bestF1);

% Apply to all data
picks = struct('p_pick_sec', cell(N,1), 's_pick_sec', cell(N,1), ...
    'p_status', cell(N,1), 's_status', cell(N,1), ...
    'p_quality', cell(N,1), 's_quality', cell(N,1), ...
    'p_pick_sample', cell(N,1), 's_pick_sample', cell(N,1), ...
    'p_error_ms', cell(N,1), 's_error_ms', cell(N,1));

for i = 1:N
    Z = metaFeatures{i};
    T = size(Z, 1);
    avgP = zeros(T,1); avgS = zeros(T,1);
    for pk = 1:nPickers
        colBase = (pk-1)*3 + 1;
        avgP = avgP + bestWeights(pk) * Z(:, colBase);
        avgS = avgS + bestWeights(pk) * Z(:, min(colBase+1, size(Z,2)));
    end
    pred{1}.P = avgP; pred{1}.S = avgS;
    pred{1}.Noise = max(0, 1 - avgP - avgS);
    p = physicsAwarePicker(pred, config);
    picks(i) = p(1);
end
end

function f1 = evalWeights(metaFeat, data, weights, nPickers, config)
N = min(numel(metaFeat), numel(data));
errP = nan(N,1);
for i = 1:N
    Z = metaFeat{i}; T = size(Z,1);
    avgP = zeros(T,1);
    for pk = 1:nPickers
        colBase = (pk-1)*3+1;
        avgP = avgP + weights(pk)*Z(:,colBase);
    end
    pred{1}.P = avgP; pred{1}.S = zeros(T,1); pred{1}.Noise = 1-avgP;
    p = physicsAwarePicker(pred, config);
    if ~isnan(p(1).p_pick_sec) && isfield(data,'p_arrival_sec')
        errP(i) = (p(1).p_pick_sec - data(i).p_arrival_sec)*1000;
    end
end
valid = ~isnan(errP);
TP = sum(abs(errP(valid))<=100);
FN = sum(~valid);
pr = TP/max(1,TP+sum(abs(errP(valid))>100));
rc = TP/max(1,TP+FN);
f1 = 2*pr*rc/max(1e-10,pr+rc);
end
