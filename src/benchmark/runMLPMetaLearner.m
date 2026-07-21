function [picks, mlpModel] = runMLPMetaLearner(metaTrainFeat, metaTrainLbl, ...
    metaValFeat, metaValLbl, metaTestFeat, config)
% runMLPMetaLearner.m
% Lightweight MLP meta-learner (benchmark).
% Architecture: [C_meta] -> [32] -> [3]  (one hidden layer)
% Trained with trainnet, same pattern as I-CNN but no temporal convolution.

fprintf('  [MLPMeta] Building MLP meta-learner...\n');

C_meta = size(metaTrainFeat{1}, 2);

layers = [
    sequenceInputLayer(C_meta, 'Name','input','MinLength',1,'Normalization','none')
    fullyConnectedLayer(32, 'Name','fc1')
    reluLayer('Name','relu1')
    dropoutLayer(0.30,'Name','drop1')
    fullyConnectedLayer(3, 'Name','fc2')
    softmaxLayer('Name','softmax')
];

% Pre-weight labels
weights = [config.lossWeights.P, config.lossWeights.S, config.lossWeights.Noise];
w = reshape(single(weights),[1,3]);

XTrain = cell(numel(metaTrainFeat),1);
YTrain = cell(numel(metaTrainFeat),1);
for i=1:numel(metaTrainFeat)
    XTrain{i} = single(metaTrainFeat{i});
    YTrain{i} = single(metaTrainLbl{i}) .* w;
end

XVal = cell(numel(metaValFeat),1);
YVal = cell(numel(metaValFeat),1);
for i=1:numel(metaValFeat)
    XVal{i} = single(metaValFeat{i});
    YVal{i} = single(metaValLbl{i}) .* w;
end

opts = trainingOptions('adam', ...
    'MaxEpochs',          30, ...
    'MiniBatchSize',      config.icnn.miniBatch, ...
    'InitialLearnRate',   1e-3, ...
    'ValidationData',     {XVal, YVal}, ...
    'ValidationFrequency', max(10, floor(numel(XTrain)/config.icnn.miniBatch)), ...
    'ValidationPatience', 7, ...
    'Shuffle',            'every-epoch', ...
    'Verbose',            false, ...
    'Plots',              'none', ...
    'ExecutionEnvironment', ternary(config.useGPU,'gpu','cpu'));

net = trainnet(XTrain, YTrain, layers, 'crossentropy', opts);
mlpModel.net = net;
mlpModel.type = 'MLP_MetaLearner';

% Apply to test
N = numel(metaTestFeat);
picks = struct('p_pick_sec',cell(N,1),'s_pick_sec',cell(N,1), ...
    'p_status',cell(N,1),'s_status',cell(N,1), ...
    'p_quality',cell(N,1),'s_quality',cell(N,1), ...
    'p_pick_sample',cell(N,1),'s_pick_sample',cell(N,1), ...
    'p_error_ms',cell(N,1),'s_error_ms',cell(N,1));

for i = 1:N
    x = {single(metaTestFeat{i})};
    raw = minibatchpredict(net, x, 'ExecutionEnvironment', ternary(config.useGPU,'gpu','cpu'));
    p3 = extractPred(raw);
    pred{1}.P = p3(:,1); pred{1}.S = p3(:,2); pred{1}.Noise = p3(:,3);
    p = physicsAwarePicker(pred, config);
    picks(i) = p(1);
end
end

function p = extractPred(raw)
if iscell(raw); raw = raw{1}; end
if isa(raw,'dlarray'); raw = extractdata(raw); end
p = double(raw);
if ndims(p)==3; p=squeeze(p); end
if size(p,2)~=3 && size(p,1)==3; p=p'; end
end

function out=ternary(c,a,b); if c; out=a; else; out=b; end; end
