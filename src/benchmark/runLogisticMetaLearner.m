function [picks, model] = runLogisticMetaLearner(metaTrainFeat, metaTrainLbl, ...
    metaTestFeat, config)
% runLogisticMetaLearner.m
% Logistic Regression meta-learner (benchmark).
% Trains a per-timestep binary classifier for P and S separately.
% Uses ridge regularisation (lambda=0.01) for stability.
% No external toolbox required - pure MATLAB gradient descent.

fprintf('  [LogisticMeta] Training logistic regression meta-learner...\n');

% Build training matrix: flatten [T x C_meta] across all records
% Subsample to keep memory tractable (every 10th timestep)
stride = 10;
Xtrain = []; yP = []; yS = [];
for i = 1:numel(metaTrainFeat)
    Z = metaTrainFeat{i};        % [T x C_meta]
    L = metaTrainLbl{i};         % [T x 3]
    idx = 1:stride:size(Z,1);
    Xtrain = [Xtrain; Z(idx,:)]; %#ok
    yP = [yP; double(L(idx,1) > 0.3)]; %#ok
    yS = [yS; double(L(idx,2) > 0.3)]; %#ok
end

% Train with mini-batch gradient descent
lambda = 0.01;
lr     = 0.1;
nEpoch = 20;
[wP, bP] = trainLogistic(Xtrain, yP, lambda, lr, nEpoch);
[wS, bS] = trainLogistic(Xtrain, yS, lambda, lr, nEpoch);

model.wP = wP; model.bP = bP;
model.wS = wS; model.bS = bS;

fprintf('  [LogisticMeta] Done. Applying to test set...\n');

% Apply to test features
N = numel(metaTestFeat);
picks = struct('p_pick_sec',cell(N,1),'s_pick_sec',cell(N,1), ...
    'p_status',cell(N,1),'s_status',cell(N,1), ...
    'p_quality',cell(N,1),'s_quality',cell(N,1), ...
    'p_pick_sample',cell(N,1),'s_pick_sample',cell(N,1), ...
    'p_error_ms',cell(N,1),'s_error_ms',cell(N,1));

for i = 1:N
    Z = metaTestFeat{i};
    probP = sigmoid(Z * wP + bP);
    probS = sigmoid(Z * wS + bS);
    probN = max(0, 1 - probP - probS);
    pred{1}.P = probP; pred{1}.S = probS; pred{1}.Noise = probN;
    p = physicsAwarePicker(pred, config);
    picks(i) = p(1);
end
end

function [w, b] = trainLogistic(X, y, lambda, lr, nEpoch)
[N, D] = size(X);
w = zeros(D,1); b = 0;
for ep = 1:nEpoch
    z    = X*w + b;
    pred = sigmoid(z);
    err  = pred - y;
    grad_w = (X'*err)/N + lambda*w;
    grad_b = mean(err);
    w = w - lr*grad_w;
    b = b - lr*grad_b;
end
end

function s = sigmoid(x)
s = 1./(1+exp(-x));
end
