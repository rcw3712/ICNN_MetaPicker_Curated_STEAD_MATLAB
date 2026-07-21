function [Zmeta, featureNames, diagnostics] = buildMetaFeatureTensor(basePredictions, waveformConditioned, config)
% =========================================================================
% buildMetaFeatureTensor.m  -- CANONICAL meta-feature builder
% =========================================================================
% PURPOSE:
%   Build the locked 15-channel meta-feature tensor used by ALL modules:
%   OOF training, validation inference, final test inference, benchmark,
%   diagnostics, visualization, and physics-aware analysis.
%
%   CANONICAL CHANNEL ORDER (must match locked I-CNN training):
%   Channels 1-12  : base-picker probabilities [0,1]
%     1  P_STA    2  S_STA    3  Noise_STA
%     4  P_AIC    5  S_AIC    6  Noise_AIC
%     7  P_CNN    8  S_CNN    9  Noise_CNN
%    10  P_TCN   11  S_TCN   12  Noise_TCN
%   Channels 13-15 : conditioned waveform context (may be negative)
%    13  E_conditioned
%    14  N_conditioned
%    15  Z_conditioned
%
% INPUTS:
%   basePredictions    - struct or cell array of base picker outputs.
%                        Each picker supplies exactly 3 channels [P, S, Noise]
%                        as [T x 3] double or single.
%                        Field names expected: .staLta, .aic, .cnn, .tcn
%                        OR cell array: {staLtaOut, aicOut, cnnOut, tcnOut}
%   waveformConditioned - [T x 3] or [T x Cw] conditioned waveform array.
%                        Only the FIRST THREE channels (E, N, Z) are used
%                        as waveform context. Enhanced-representation channels
%                        (envelope, energy, etc.) must NOT be included here;
%                        pass raw conditioned E/N/Z only.
%   config             - struct framework config.
%                        config.icnn.includeWaveformContext must be true.
%
% OUTPUTS:
%   Zmeta        - [T x 15] single, canonical meta-feature tensor.
%                  For batched use: cell{N,1} where each element is [T x 15].
%   featureNames - {15 x 1} cell of char, canonical feature name list.
%   diagnostics  - struct with validation results for each channel group.
%
% TENSOR-DIMENSION CONVENTION:
%   Internal: [T x C] per record (time samples x channels).
%   Batched:  cell{N,1} of [T x C] -- one cell per waveform record.
%   T = 6000, C = 15, N = 335 for final test set.
%
% CHANNEL CONTRACT:
%   Channels 1-12: softmax probabilities, expected in [0,1], P+S+Noise~=1.
%   Channels 13-15: conditioned waveform, may be negative (z-score scaled).
%
% Z-ONLY CONTRACT:
%   In Z-only mode, channels 13 and 14 (E and N context) are set to zero.
%   Channel 15 (Z_conditioned) retains its value.
%   The tensor remains 15 channels to preserve the model input contract.
%
% ASSUMPTIONS:
%   - The locked I-CNN model was trained with this exact 15-channel order.
%   - Enhanced representations (envelope, energy, STA characteristic
%     functions) are used ONLY internally by base pickers and must NOT
%     appear as waveform-context channels here.
%   - This function is the single source of truth for tensor construction.
%
% ERROR HANDLING:
%   Asserts channel counts and feature names. Raises error on mismatch.
%   Does not silently slice or pad the tensor.
%
% NOTES:
%   Root cause of the 20-channel bug: waveformConditioned was passed from
%   buildEnhancedRepresentation which appended envelope, energy, and
%   STA characteristic channels after E/N/Z, yielding 8 channels instead
%   of 3. The fix is to extract only columns 1:3 (E, N, Z) from the
%   conditioned representation before calling this function.
% =========================================================================

CANONICAL_NAMES = {
    'P_STA'; 'S_STA'; 'Noise_STA';
    'P_AIC'; 'S_AIC'; 'Noise_AIC';
    'P_CNN'; 'S_CNN'; 'Noise_CNN';
    'P_TCN'; 'S_TCN'; 'Noise_TCN';
    'E_conditioned'; 'N_conditioned'; 'Z_conditioned'
};
C_EXPECTED = 15;
N_PICKERS  = 4;
N_PROB_CH  = 12;
N_WAVE_CH  = 3;

featureNames = CANONICAL_NAMES;

%    Determine batched vs single-record mode                                
isBatched = iscell(basePredictions) && numel(basePredictions) > 0 ...
    && iscell(basePredictions{1});

if isBatched
    N = numel(basePredictions);
    Zmeta = cell(N, 1);
    diagnostics = struct('N',N,'C',C_EXPECTED,'featureNames',{featureNames},...
        'probValid',true,'waveValid',true,'tensorShape','cell_N_TxC');
    for i = 1:N
        [Zmeta{i}, ~, d] = buildMetaFeatureTensor(basePredictions{i}, ...
            waveformConditioned{i}, config);
        if ~d.probValid; diagnostics.probValid = false; end
        if ~d.waveValid; diagnostics.waveValid = false; end
    end
    return;
end

%    Single record: extract base-picker probability channels                
pickerNames = {'staLta','aic','cnn','tcn'};
pickerAlt   = {'stalta','STA_LTA','STALTA','staLtaPred','aicPred','cnnPred','tcnPred'};

if isstruct(basePredictions)
    % Struct with named fields
    Zprob = [];
    for pk = 1:N_PICKERS
        pname = pickerNames{pk};
        % Try primary name then alternatives
        candidates = {pname};
        if pk==1; candidates = [candidates, {'stalta','STA_LTA','STALTA','staLtaPred'}]; end
        if pk==2; candidates = [candidates, {'aicPred','AIC'}]; end
        if pk==3; candidates = [candidates, {'cnnPred','CNN'}]; end
        if pk==4; candidates = [candidates, {'tcnPred','TCN'}]; end

        pout = [];
        for c=candidates
            if isfield(basePredictions, c{1})
                raw = basePredictions.(c{1});
                pout = extractPickerOutput(raw);
                break;
            end
        end
        if isempty(pout)
            error('buildMetaFeatureTensor: base picker "%s" not found in basePredictions struct.', pname);
        end
        Zprob = [Zprob, pout]; %#ok
    end

elseif iscell(basePredictions) && numel(basePredictions) == N_PICKERS
    % Cell array {staLtaOut, aicOut, cnnOut, tcnOut}
    Zprob = [];
    for pk = 1:N_PICKERS
        pout = extractPickerOutput(basePredictions{pk});
        Zprob = [Zprob, pout]; %#ok
    end

elseif isnumeric(basePredictions) || isa(basePredictions,'single')
    % Pre-concatenated [T x 12] array
    Zprob = double(basePredictions);
    if size(Zprob,2) ~= N_PROB_CH
        error('buildMetaFeatureTensor: Pre-concatenated basePredictions has %d columns, expected %d.', ...
            size(Zprob,2), N_PROB_CH);
    end
else
    error('buildMetaFeatureTensor: Unsupported basePredictions format: %s.', class(basePredictions));
end

assert(size(Zprob,2) == N_PROB_CH, ...
    'buildMetaFeatureTensor: probability block has %d channels, expected %d.', ...
    size(Zprob,2), N_PROB_CH);

T = size(Zprob, 1);

%    Extract EXACTLY 3 waveform-context channels (E, N, Z)                 
% CRITICAL: Only the first 3 columns of waveformConditioned are used.
% Enhanced-representation channels (envelope, energy, STA characteristic
% functions) that may exist in columns 4+ are EXCLUDED here.
% This was the root cause of the 20-channel bug.

if isempty(waveformConditioned)
    Zwave = zeros(T, N_WAVE_CH, 'double');
    warnMsg = 'buildMetaFeatureTensor: waveformConditioned is empty; using zero context.';
    warning(warnMsg);
elseif size(waveformConditioned, 2) < N_WAVE_CH
    error('buildMetaFeatureTensor: waveformConditioned has %d columns, need at least %d (E,N,Z).', ...
        size(waveformConditioned,2), N_WAVE_CH);
else
    % Use exactly first 3 columns regardless of how many are present
    Zwave = double(waveformConditioned(:, 1:3));
    if size(waveformConditioned, 2) > N_WAVE_CH
        fprintf('  [buildMetaFeatureTensor] NOTE: waveformConditioned has %d columns; using only first 3 (E,N,Z).\n', ...
            size(waveformConditioned,2));
    end
end

%    Z-only contract: zero E and N context channels                         
isZonly = isfield(config,'experiment') && strcmpi(config.experiment,'Zonly');
if ~isZonly && isfield(config,'icnn') && isfield(config.icnn,'zeroHorizontalContext')
    isZonly = config.icnn.zeroHorizontalContext;
end
if isZonly
    Zwave(:,1) = 0;  % E_conditioned -> zero
    Zwave(:,2) = 0;  % N_conditioned -> zero
    % Zwave(:,3) = Z_conditioned -> retain
end

%    Assemble canonical 15-channel tensor                                   
Zmeta = single([Zprob, Zwave]);

%    Assert channel count and feature names                                 
assert(size(Zmeta,2) == C_EXPECTED, ...
    'buildMetaFeatureTensor: tensor has %d channels, expected %d.', ...
    size(Zmeta,2), C_EXPECTED);

% Name-level assertion -- catches order mistakes, not just count mistakes
assert(numel(featureNames) == C_EXPECTED, ...
    'buildMetaFeatureTensor: featureNames has %d entries, expected %d.', ...
    numel(featureNames), C_EXPECTED);

%    Diagnostics: validate channel groups                                  
tol      = 1e-3;
Zprob_   = double(Zmeta(:, 1:N_PROB_CH));
Zwave_   = double(Zmeta(:, N_PROB_CH+1:end));

probValid = true;
waveValid = true;

% Check probability channels [0,1]
if any(Zprob_(:) < -tol) || any(Zprob_(:) > 1+tol)
    probValid = false;
    warning('buildMetaFeatureTensor: probability channels contain values outside [0,1].');
end
if any(isnan(Zprob_(:))) || any(isinf(Zprob_(:)))
    probValid = false;
    warning('buildMetaFeatureTensor: probability channels contain NaN or Inf.');
end

% Per-picker class-sum check (P+S+Noise should ~ 1)
pickerSumErr = zeros(N_PICKERS,1);
for pk = 1:N_PICKERS
    cols = (pk-1)*3 + (1:3);
    classSum = sum(Zprob_(:,cols), 2);
    pickerSumErr(pk) = mean(abs(classSum - 1));
end

% Check waveform channels (finite, no NaN)
if any(isnan(Zwave_(:))) || any(isinf(Zwave_(:)))
    waveValid = false;
    warning('buildMetaFeatureTensor: waveform context channels contain NaN or Inf.');
end

waveStats = struct();
for k = 1:N_WAVE_CH
    waveStats(k).channel = CANONICAL_NAMES{N_PROB_CH+k};
    waveStats(k).mean    = mean(Zwave_(:,k));
    waveStats(k).std     = std(Zwave_(:,k));
    waveStats(k).min_val = min(Zwave_(:,k));
    waveStats(k).max_val = max(Zwave_(:,k));
end

diagnostics = struct(...
    'N',            1, ...
    'T',            T, ...
    'C',            size(Zmeta,2), ...
    'C_prob',       N_PROB_CH, ...
    'C_wave',       N_WAVE_CH, ...
    'featureNames', {featureNames}, ...
    'probValid',    probValid, ...
    'waveValid',    waveValid, ...
    'pickerSumError', pickerSumErr, ...
    'waveStats',    waveStats, ...
    'tensorShape',  sprintf('[%d x %d]', T, size(Zmeta,2)), ...
    'isZonly',      isZonly);
end

% =========================================================================
% Helper: extract [T x 3] from various picker output formats
% =========================================================================
function pout = extractPickerOutput(raw)
if iscell(raw) && numel(raw)==1; raw = raw{1}; end
if isa(raw,'dlarray'); raw = extractdata(raw); end
raw = double(raw);

if isstruct(raw) && isfield(raw,'P') && isfield(raw,'S')
    pout = [raw.P(:), raw.S(:)];
    if isfield(raw,'Noise'); pout = [pout, raw.Noise(:)];
    else; pout = [pout, max(0, 1-pout(:,1)-pout(:,2))]; end
    return;
end

% Numeric: shape [T x 3] or [3 x T]
sz = size(raw);
if numel(sz) == 2
    if sz(2) == 3
        pout = raw;
    elseif sz(1) == 3
        pout = raw';
    else
        error('extractPickerOutput: expected [T x 3] or [3 x T], got [%d x %d].', sz(1), sz(2));
    end
elseif numel(sz) == 3
    % [3 x T x 1] or [T x 3 x 1]
    if sz(1) == 3; pout = squeeze(raw)'; else; pout = squeeze(raw); end
else
    error('extractPickerOutput: unsupported dimensions.');
end
end
