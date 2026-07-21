% =========================================================================
% predictTCNPicker.m  (src/base_pickers/)
% =========================================================================
% PURPOSE:
%   Run inference with a trained Dilated TCN base picker.
%   Menangani semua format output minibatchpredict R2024a (cell, dlarray,
%   atau numeric matrix) baik di CPU maupun GPU execution environment.
% =========================================================================

function Yhat = predictTCNPicker(model, data, config)

N    = numel(data);
Yhat = cell(N, 1);

for i = 1:N
    x    = {single(data(i).X)};
    pred = minibatchpredict(model.net, x, ...
        'ExecutionEnvironment', ternary(config.useGPU, 'gpu', 'cpu'));

    p = extractPrediction(pred);   % [T x 3] double

    Yhat{i}.P     = p(:, 1);
    Yhat{i}.S     = p(:, 2);
    Yhat{i}.Noise = p(:, 3);
end

end

function p = extractPrediction(pred)
if iscell(pred);             raw = pred{1};
elseif isa(pred,'dlarray');  raw = extractdata(pred);
else;                         raw = pred;
end
if isa(raw,'dlarray'); raw = extractdata(raw); end
p = double(raw);
if ndims(p)==3; p = squeeze(p); end
if size(p,2)~=3 && size(p,1)==3; p = p'; end
end

function out = ternary(cond,a,b)
if cond; out=a; else; out=b; end
end
