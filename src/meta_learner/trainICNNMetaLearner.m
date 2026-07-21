% =========================================================================
% trainICNNMetaLearner.m  (src/meta_learner/)
% =========================================================================
% PURPOSE:
%   Train the I-CNN as a LEVEL-2 META-LEARNER.
%   Input: meta-feature tensor Z_meta [T x C_meta]
%   Output: [P_prob, S_prob, Noise_prob] per timestep
%
%   *** SATU-SATUNYA model yang disebut "I-CNN" dalam framework ini. ***
%   I-CNN adalah meta-learner, bukan direct waveform picker.
% =========================================================================

function [model, trainInfo] = trainICNNMetaLearner(...
    metaTrainFeatures, metaTrainLabels, ...
    metaValFeatures,   metaValLabels, config)

numChan    = size(metaTrainFeatures{1}, 2);   % C_meta (mis. 12 atau 15)
numFilters = config.icnn.numFilters;
kernelSz   = config.icnn.kernelSize;
dilations  = config.icnn.dilations;
dropProb   = config.icnn.dropout;

fprintf('  [I-CNN meta-learner] Building architecture...\n');
fprintf('    Input: meta-feature tensor [T x %d]\n', numChan);
fprintf('    (base picker probability curves%s)\n', ...
    ternary(config.icnn.includeWaveformContext, ' + waveform context', ''));

% ── Arsitektur: Conv1D stack sederhana (hemat memori) ────────────────────
% Untuk dataset dengan T=6000, arsitektur dengan layerGraph + additionLayer
% bisa menyebabkan OOM karena graph overhead. Gunakan sequential stack.
allLayers = {};
allLayers{end+1} = sequenceInputLayer(numChan, 'Name','meta_input', ...
    'MinLength', 12, 'Normalization','none');

% Blok awal: Conv1D + BN + ReLU
allLayers{end+1} = convolution1dLayer(kernelSz, numFilters(1), ...
    'Padding','same', 'Name','icnn_conv0');
allLayers{end+1} = batchNormalizationLayer('Name','icnn_bn0');
allLayers{end+1} = reluLayer('Name','icnn_relu0');
allLayers{end+1} = dropoutLayer(dropProb, 'Name','icnn_drop0');

% Blok dilasi (sequential, tanpa residual — lebih hemat memori)
for d = 1:numel(dilations)
    dil   = dilations(d);
    flt   = numFilters(min(d+1, numel(numFilters)));
    bname = sprintf('icnn_dil%d', d);
    allLayers{end+1} = convolution1dLayer(kernelSz, flt, ...     %#ok
        'Padding','same', 'DilationFactor', dil, 'Name',[bname '_conv']);
    allLayers{end+1} = batchNormalizationLayer('Name',[bname '_bn']); %#ok
    allLayers{end+1} = reluLayer('Name',[bname '_relu']);              %#ok
    allLayers{end+1} = dropoutLayer(dropProb, 'Name',[bname '_drop']); %#ok
end

% Output head
allLayers{end+1} = convolution1dLayer(1, 3, 'Padding','same', 'Name','icnn_out');
allLayers{end+1} = softmaxLayer('Name','icnn_softmax');

layers = [allLayers{:}];

% ── Siapkan data ──────────────────────────────────────────────────────────
XTrain = formatMeta(metaTrainFeatures);
YTrain = formatLabel(metaTrainLabels);
XVal   = formatMeta(metaValFeatures);
YVal   = formatLabel(metaValLabels);

% ── Loss: weighted cross-entropy via pre-weighted labels ──────────────────
% Masalah: trainnet R2024a melewatkan tensor ke custom loss function dalam
% format [T x C x miniBatch] — bukan [T x C] — sehingga wVec [1x3] tidak
% bisa di-broadcast ke dimensi 3 (miniBatch=16), menghasilkan error:
%   "Arrays have incompatible sizes of 3 and 16 in dimension 3"
%
% Solusi: terapkan bobot langsung pada label Y sebelum training, lalu
% gunakan loss 'crossentropy' bawaan trainnet yang robust di semua format.
%
% Ekuivalensi matematis:
%   CE_weighted = -sum_k w_k * Y_k * log(Ypred_k)
%               = -sum_k (w_k * Y_k) * log(Ypred_k)
%               = CE_standard(Ypred, Y_weighted)
% Sehingga menerapkan bobot pada Y dan menggunakan CE standar menghasilkan
% loss yang identik dengan weighted cross-entropy.

wP     = config.lossWeights.P;
wS     = config.lossWeights.S;
wNoise = config.lossWeights.Noise;
weights = [wP, wS, wNoise];

fprintf('  [I-CNN] Pre-weighting labels: wP=%.1f, wS=%.1f, wNoise=%.1f\n', ...
    wP, wS, wNoise);

YTrainW = applyLabelWeights(YTrain, weights);
YValW   = applyLabelWeights(YVal,   weights);

% ── Training options ──────────────────────────────────────────────────────
opts = trainingOptions('adam', ...
    'MaxEpochs',          config.icnn.maxEpochs, ...
    'MiniBatchSize',      config.icnn.miniBatch, ...
    'InitialLearnRate',   config.icnn.learningRate, ...
    'LearnRateSchedule',  'piecewise', ...
    'LearnRateDropFactor', 0.5, ...
    'LearnRateDropPeriod', 20, ...
    'ValidationData',     {XVal, YValW}, ...
    'ValidationFrequency', max(10, floor(numel(XTrain)/config.icnn.miniBatch)), ...
    'ValidationPatience', config.icnn.patience, ...
    'Shuffle',            'every-epoch', ...
    'Verbose',            config.verbose, ...
    'Plots',              'none', ...
    'ExecutionEnvironment', ternary(config.useGPU,'gpu','cpu'));

fprintf('  [I-CNN meta-learner] Training (%d epochs, N=%d)...\n', ...
    config.icnn.maxEpochs, numel(XTrain));

% Gunakan 'crossentropy' bawaan — tidak ada custom function, tidak ada
% tensor format issue, kompatibel dengan semua execution environment R2024a
[net, trainInfo] = trainnet(XTrain, YTrainW, layers, 'crossentropy', opts);

model.net     = net;
model.type    = 'ICNN_MetaLearner';
model.numChan = numChan;
model.weights = weights;
model.config  = config.icnn;

% Simpan training history sebagai struct biasa (bukan deep.TrainingInfo object)
% agar bisa di-load kembali di sesi MATLAB yang berbeda
try
    tLoss = []; vLoss = []; vEp = [];
    for fn = {'TrainingLoss','TrainLoss','Loss'}
        try; v=trainInfo.(fn{1}); if ~isempty(v); tLoss=double(v(:)); break; end; catch; end
    end
    for fn = {'ValidationLoss','ValLoss','val_loss'}
        try; v=trainInfo.(fn{1}); if ~isempty(v); vLoss=double(v(:)); break; end; catch; end
    end
    for fn = {'ValidationEpoch','ValEpoch','EpochIndex'}
        try; v=trainInfo.(fn{1}); if ~isempty(v); vEp=double(v(:)); break; end; catch; end
    end
    model.trainHistory.TrainingLoss    = tLoss;
    model.trainHistory.ValidationLoss  = vLoss;
    model.trainHistory.ValidationEpoch = vEp;
catch
    model.trainHistory = struct();
end

fprintf('  [I-CNN meta-learner] Done.\n');
try
    vL = model.trainHistory.ValidationLoss;
    vL = vL(isfinite(vL));
    if ~isempty(vL)
        fprintf('  Best val loss: %.4f\n', min(vL));
    end
catch; end
end

% ── Helpers ───────────────────────────────────────────────────────────────
function X = formatMeta(metaFeatures)
N = numel(metaFeatures); X = cell(N,1);
for i = 1:N; X{i} = single(metaFeatures{i}); end   % [T x C_meta]
end

function Y = formatLabel(metaLabels)
N = numel(metaLabels); Y = cell(N,1);
for i = 1:N; Y{i} = single(metaLabels{i}); end     % [T x 3]
end

function YW = applyLabelWeights(Y, weights)
% Terapkan bobot loss pada setiap label cell array sebelum training.
% Y{i} = [T x 3] single, weights = [wP, wS, wNoise]
% YW{i}(t,k) = weights(k) * Y{i}(t,k)
% Ini setara matematis dengan weighted cross-entropy saat digunakan bersama
% loss 'crossentropy' bawaan trainnet.
N  = numel(Y);
YW = cell(N, 1);
w  = reshape(single(weights), [1, 3]);   % [1 x 3] — broadcast ke [T x 3]
for i = 1:N
    YW{i} = Y{i} .* w;
end
end

function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end
