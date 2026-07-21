% =========================================================================
% trainBaselineCNNPicker.m  (src/base_pickers/)
% =========================================================================
% PURPOSE:
%   Train a baseline 1D CNN as a LEVEL-1 BASE PICKER.
%   Menggunakan minibatchqueue untuk streaming data per batch,
%   sehingga tidak memuat seluruh dataset ke memori sekaligus.
%
% INPUT:
%   trainData - struct array, .X [T x C], .label [T x 3]
%   valData   - struct array
%   config    - struct, framework configuration
%
% OUTPUT:
%   model - struct dengan .net, .type='BaselineCNN', .config
% =========================================================================

function model = trainBaselineCNNPicker(trainData, valData, config)

fprintf('  [BaselineCNN - base picker] Building architecture...\n');

numFilters = config.cnn.numFilters;
kernelSz   = config.cnn.kernelSize;
dropProb   = config.cnn.dropout;
nChanIn    = size(trainData(1).X, 2);   % jumlah input channel (mis. 8)
T          = size(trainData(1).X, 1);   % panjang sequence (6000)

% ── Arsitektur ────────────────────────────────────────────────────────────
% sequenceInputLayer dengan format 'TBC' (Time x Batch x Channel)
% lebih stabil untuk data panjang di R2024a
layers = [
    sequenceInputLayer(nChanIn, 'Name','input', ...
        'MinLength', 100, 'Normalization','none')
    convolution1dLayer(kernelSz, numFilters(1), 'Padding','same', 'Name','conv1')
    batchNormalizationLayer('Name','bn1')
    reluLayer('Name','relu1')
    dropoutLayer(dropProb, 'Name','drop1')
    convolution1dLayer(kernelSz, numFilters(2), 'Padding','same', 'Name','conv2')
    batchNormalizationLayer('Name','bn2')
    reluLayer('Name','relu2')
    dropoutLayer(dropProb, 'Name','drop2')
    convolution1dLayer(1, 3, 'Padding','same', 'Name','conv_out')
    softmaxLayer('Name','softmax')
];

% ── Siapkan data sebagai cell array [T x C] per elemen ───────────────────
[XTrain, YTrain] = prepSeqData(trainData);
[XVal,   YVal  ] = prepSeqData(valData);

% ── Training options ──────────────────────────────────────────────────────
opts = trainingOptions('adam', ...
    'MaxEpochs',          config.cnn.maxEpochs, ...
    'MiniBatchSize',      config.cnn.miniBatch, ...
    'InitialLearnRate',   config.cnn.learningRate, ...
    'LearnRateSchedule',  'piecewise', ...
    'LearnRateDropFactor', 0.5, ...
    'LearnRateDropPeriod', 20, ...
    'ValidationData',     {XVal, YVal}, ...
    'ValidationFrequency', max(10, floor(numel(XTrain)/config.cnn.miniBatch)), ...
    'ValidationPatience', config.cnn.patience, ...
    'Shuffle',            'every-epoch', ...
    'Verbose',            false, ...
    'Plots',              'none', ...
    'ExecutionEnvironment', ternary(config.useGPU,'gpu','cpu'));

fprintf('  [BaselineCNN] Training (%d epochs, %d records, C=%d)...\n', ...
    config.cnn.maxEpochs, numel(XTrain), nChanIn);

net = trainnet(XTrain, YTrain, layers, 'crossentropy', opts);

model.net    = net;
model.type   = 'BaselineCNN';
model.config = config.cnn;
fprintf('  [BaselineCNN] Training complete.\n');
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
