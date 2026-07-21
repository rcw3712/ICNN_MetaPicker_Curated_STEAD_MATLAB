% =========================================================================
% trainTCNPicker.m  (src/base_pickers/)
% =========================================================================
% PURPOSE:
%   Train a dilated Temporal Convolutional Network as a LEVEL-1 BASE PICKER.
%   Arsitektur disederhanakan (4 blok dilasi, tanpa residual connection)
%   untuk mengurangi penggunaan memori saat training pada data panjang (T=6000).
%
% INPUT:
%   trainData, valData - struct arrays (.X [T x C], .label [T x 3])
%   config             - struct, framework configuration
%
% OUTPUT:
%   model - struct dengan .net, .type='TCN', .config
% =========================================================================

function model = trainTCNPicker(trainData, valData, config)

fprintf('  [TCN - base picker] Building dilated architecture...\n');

dilations  = config.tcn.dilations(1:min(4, numel(config.tcn.dilations)));
numFilters = config.tcn.numFilters(1);
kernelSz   = config.tcn.kernelSize;
dropProb   = config.tcn.dropout;
nChanIn    = size(trainData(1).X, 2);

% ── Arsitektur TCN (dilated Conv1D stack, tanpa residual) ────────────────
layers = sequenceInputLayer(nChanIn, 'Name','input', ...
    'MinLength', 100, 'Normalization','none');

prevName = 'input';
allLayers = {layers};

for d = 1:numel(dilations)
    dil     = dilations(d);
    bname   = sprintf('tcn%d', d);

    allLayers{end+1} = convolution1dLayer(kernelSz, numFilters, ...
        'Padding','same', 'DilationFactor', dil, 'Name',[bname '_conv']); %#ok
    allLayers{end+1} = batchNormalizationLayer('Name',[bname '_bn']);     %#ok
    allLayers{end+1} = reluLayer('Name',[bname '_relu']);                  %#ok
    allLayers{end+1} = dropoutLayer(dropProb, 'Name',[bname '_drop']);    %#ok
end

allLayers{end+1} = convolution1dLayer(1, 3, 'Padding','same', 'Name','out_conv');
allLayers{end+1} = softmaxLayer('Name','softmax');

layers = [allLayers{:}];   % Konversi ke array layer

% ── Data ─────────────────────────────────────────────────────────────────
[XTrain, YTrain] = prepSeqData(trainData);
[XVal,   YVal  ] = prepSeqData(valData);

% ── Training options ──────────────────────────────────────────────────────
opts = trainingOptions('adam', ...
    'MaxEpochs',          config.tcn.maxEpochs, ...
    'MiniBatchSize',      config.tcn.miniBatch, ...
    'InitialLearnRate',   config.tcn.learningRate, ...
    'LearnRateSchedule',  'piecewise', ...
    'LearnRateDropFactor', 0.5, ...
    'LearnRateDropPeriod', 20, ...
    'ValidationData',     {XVal, YVal}, ...
    'ValidationFrequency', max(10, floor(numel(XTrain)/config.tcn.miniBatch)), ...
    'ValidationPatience', config.tcn.patience, ...
    'Shuffle',            'every-epoch', ...
    'Verbose',            false, ...
    'Plots',              'none', ...
    'ExecutionEnvironment', ternary(config.useGPU,'gpu','cpu'));

fprintf('  [TCN] Training (%d epochs, dilations=%s, C=%d, N=%d)...\n', ...
    config.tcn.maxEpochs, mat2str(dilations), nChanIn, numel(XTrain));

net = trainnet(XTrain, YTrain, layers, 'crossentropy', opts);

model.net    = net;
model.type   = 'TCN';
model.config = config.tcn;
fprintf('  [TCN] Training complete.\n');
end

% ── Helpers ───────────────────────────────────────────────────────────────
function [X, Y] = prepSeqData(data)
N = numel(data);
X = cell(N, 1);
Y = cell(N, 1);
for i = 1:N
    X{i} = single(data(i).X);      % [T x C]
    Y{i} = single(data(i).label);  % [T x 3]
end
end

function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end
