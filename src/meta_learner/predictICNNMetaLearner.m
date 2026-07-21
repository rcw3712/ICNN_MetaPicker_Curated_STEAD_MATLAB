% =========================================================================
% predictICNNMetaLearner.m  (src/meta_learner/)
% =========================================================================
% PURPOSE:
%   Run inference with a trained I-CNN meta-learner.
%   Menangani semua format output minibatchpredict R2024a.
% =========================================================================

function predictions = predictICNNMetaLearner(model, metaFeatures, config)

N           = numel(metaFeatures);
predictions = cell(N, 1);

X = cell(N, 1);
for i = 1:N
    X{i} = single(metaFeatures{i});   % [T x C_meta]
end

Ypred = minibatchpredict(model.net, X, ...
    'MiniBatchSize',      config.icnn.miniBatch, ...
    'ExecutionEnvironment', ternary(config.useGPU, 'gpu', 'cpu'));

for i = 1:N
    % Tangani semua format output: cell, dlarray, atau numeric
    if iscell(Ypred)
        raw = Ypred{i};
    elseif isa(Ypred, 'dlarray')
        % Batch output [T x 3 x N] atau [N x T x 3]
        raw = extractdata(Ypred);
        if ndims(raw) == 3
            raw = squeeze(raw(:,:,i));
        end
    else
        % Numeric matrix — batch output, ambil slice ke-i
        if ndims(Ypred) == 3
            raw = Ypred(:,:,i);
        else
            raw = Ypred;
        end
    end

    if isa(raw,'dlarray'); raw = extractdata(raw); end
    p = double(raw);
    if ndims(p)==3; p = squeeze(p); end
    if size(p,2)~=3 && size(p,1)==3; p = p'; end

    predictions{i}.P     = p(:, 1);
    predictions{i}.S     = p(:, 2);
    predictions{i}.Noise = p(:, 3);
end

end

function out = ternary(cond,a,b)
if cond; out=a; else; out=b; end
end
