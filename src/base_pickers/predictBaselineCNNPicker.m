% =========================================================================
% predictBaselineCNNPicker.m  (src/base_pickers/)
% =========================================================================
% PURPOSE:
%   Run inference with a trained Baseline CNN base picker.
%
% INPUT:
%   model  - struct, output of trainBaselineCNNPicker.m
%   data   - struct array, each element must have .X [T x C]
%   config - struct, framework configuration
%
% OUTPUT:
%   Yhat - cell{N,1}, each struct with .P, .S, .Noise [T x 1]
%
% NOTES:
%   minibatchpredict di MATLAB R2024a dengan GPU dapat mengembalikan
%   output dalam format berbeda tergantung arsitektur dan execution env:
%     - cell array  {[T x 3]}  -> gunakan pred{1}
%     - dlarray     [T x 3 x B] -> gunakan extractdata()
%     - matrix      [T x 3]    -> gunakan langsung
%   Fungsi ini menangani ketiga kemungkinan tersebut.
% =========================================================================

function Yhat = predictBaselineCNNPicker(model, data, config)

N    = numel(data);
Yhat = cell(N, 1);

for i = 1:N
    x    = {single(data(i).X)};   % cell{1} berisi [T x C]
    pred = minibatchpredict(model.net, x, ...
        'ExecutionEnvironment', ternary(config.useGPU, 'gpu', 'cpu'));

    % Ekstrak output dengan aman untuk semua format R2024a
    p = extractPrediction(pred);   % selalu menghasilkan [T x 3] double

    Yhat{i}.P     = p(:, 1);
    Yhat{i}.S     = p(:, 2);
    Yhat{i}.Noise = p(:, 3);
end

end

% ── Helpers ───────────────────────────────────────────────────────────────

function p = extractPrediction(pred)
% Menangani semua format output minibatchpredict R2024a:
%   1. cell array  -> ambil elemen pertama
%   2. dlarray     -> extractdata lalu squeeze
%   3. numeric matrix -> gunakan langsung
if iscell(pred)
    raw = pred{1};
elseif isa(pred, 'dlarray')
    raw = extractdata(pred);
else
    raw = pred;
end

% Jika masih dlarray setelah diambil dari cell
if isa(raw, 'dlarray')
    raw = extractdata(raw);
end

% Pastikan double dan 2D [T x 3]
p = double(raw);
if ndims(p) == 3
    % Format [T x 3 x 1] -> squeeze ke [T x 3]
    p = squeeze(p);
end
if size(p, 2) ~= 3 && size(p, 1) == 3
    % Format [3 x T] -> transpose ke [T x 3]
    p = p';
end
end

function out = ternary(cond, a, b)
if cond; out = a; else; out = b; end
end
