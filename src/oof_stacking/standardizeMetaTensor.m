function [Zout, info] = standardizeMetaTensor(Zin)
% standardizeMetaTensor.m
% Detect actual format and standardize to cell{N,1} of [T x C] single.
% Does NOT overwrite the original tensor.
%
% Supported input formats:
%   [T x C x N] numeric
%   [C x T x N] numeric
%   cell{N,1} of [T x C]
%   cell{N,1} of [C x T]
%
% Output: cell{N,1} of [T x C] single
% Expected final: T=6000, C=15, N=335

info = struct('original_format','unknown','T',0,'C',0,'N',0);

if iscell(Zin)
    N = numel(Zin);
    if N == 0; Zout = {}; return; end
    sample = double(Zin{1});
    sz = size(sample);
    if numel(sz)==2 && sz(2)==15
        % Already [T x C] -- correct
        info.original_format = 'cell_N_of_TxC';
        info.T=sz(1); info.C=sz(2); info.N=N;
        Zout = cellfun(@(z) single(z), Zin, 'UniformOutput', false);
    elseif numel(sz)==2 && sz(1)==15
        % [C x T] -- transpose each
        info.original_format = 'cell_N_of_CxT';
        info.T=sz(2); info.C=sz(1); info.N=N;
        Zout = cellfun(@(z) single(z'), Zin, 'UniformOutput', false);
        fprintf('  [standardizeMetaTensor] Transposed cell{%d} from [%d x %d] to [%d x %d].\n', ...
            N, sz(1), sz(2), sz(2), sz(1));
    else
        % Determine from first element
        if sz(1) > sz(2)
            info.original_format = 'cell_N_of_TxC_guessed';
            info.T=sz(1); info.C=sz(2); info.N=N;
            Zout = cellfun(@(z) single(z), Zin, 'UniformOutput', false);
        else
            info.original_format = 'cell_N_of_CxT_guessed';
            info.T=sz(2); info.C=sz(1); info.N=N;
            Zout = cellfun(@(z) single(z'), Zin, 'UniformOutput', false);
        end
        warning('standardizeMetaTensor: ambiguous cell format, guessed %s.', info.original_format);
    end

elseif isnumeric(Zin) || isa(Zin,'single')
    sz = size(Zin);
    if numel(sz)==3
        if sz(2)==15
            % [T x C x N]
            info.original_format = 'TxCxN'; info.T=sz(1); info.C=sz(2); info.N=sz(3);
            Zout = cell(sz(3),1);
            for i=1:sz(3); Zout{i}=single(Zin(:,:,i)); end
        elseif sz(1)==15
            % [C x T x N]
            info.original_format = 'CxTxN'; info.T=sz(2); info.C=sz(1); info.N=sz(3);
            Zout = cell(sz(3),1);
            for i=1:sz(3); Zout{i}=single(squeeze(Zin(:,:,i))'); end
            fprintf('  [standardizeMetaTensor] Permuted [%d x %d x %d] to cell of [%d x %d].\n',...
                sz(1),sz(2),sz(3),sz(2),sz(1));
        else
            error('standardizeMetaTensor: 3D numeric tensor has ambiguous C dimension.');
        end
    elseif numel(sz)==2
        % Single record
        if sz(2)==15
            info.original_format='TxC_single'; info.T=sz(1); info.C=sz(2); info.N=1;
            Zout={single(Zin)};
        elseif sz(1)==15
            info.original_format='CxT_single'; info.T=sz(2); info.C=sz(1); info.N=1;
            Zout={single(Zin')};
        else
            error('standardizeMetaTensor: 2D numeric tensor: neither dim is 15.');
        end
    else
        error('standardizeMetaTensor: unsupported numeric shape.');
    end
else
    error('standardizeMetaTensor: unsupported input type: %s.', class(Zin));
end

fprintf('  [standardizeMetaTensor] Input: %s | Standardized: cell{%d} of [%d x %d]\n',...
    info.original_format, info.N, info.T, info.C);
end
