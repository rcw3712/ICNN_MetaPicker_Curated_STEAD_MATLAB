% =========================================================================
% config_ICNN_MetaPicker.m
% =========================================================================
% PURPOSE:
%   Centralised configuration untuk I-CNN MetaPicker (Curated STEAD CSV).
%   Disesuaikan dengan metadata_master_filled.xlsx yang SUDAH TERISI.
%
% NOTES:
%   metadata_master_filled.xlsx (25.000 baris, 56 kolom) sudah berisi:
%     - source_id ASLI STEAD (mis. 'uw10827933') -> valid untuk split
%     - quality_flag ('good'/'bad') -> QC sudah dilakukan
%     - p_arrival_sec, s_arrival_sec -> dari STEAD manual picks
%     - file_name, file_path: KOSONG -> diisi otomatis dari event_id
%   Data waveform: 2.234 file CSV (stead_event_NNNNN.csv)
%   Format CSV: time, sec, E, N, Z, p_arrival, s_arrival
%
%   URUTAN PENGGUNAAN YANG DIREKOMENDASIKAN:
%     Pertama kali:
%       >> exportMetadataToCSV(config_ICNN_MetaPicker())
%     Kemudian ubah config.metadataPath ke .csv untuk run lebih cepat.
% =========================================================================

function config = config_ICNN_MetaPicker()

% ── Meta-information ─────────────────────────────────────────────────────
config.version       = '1.0.1';
config.targetJournal  = 'Computers & Geosciences';
config.frameworkName  = 'Leakage-Free I-CNN Meta-Learning Framework (Curated STEAD CSV)';
config.randomSeed     = 42;

% ── Paths ─────────────────────────────────────────────────────────────────
% PENTING: File metadata sudah terisi lengkap, tidak perlu dibangun ulang.
% Jika sudah di-export ke CSV (via exportMetadataToCSV), ganti ke .csv:
config.metadataPath = fullfile('metadata', 'metadata_master_filled.xlsx');
% config.metadataPath = fullfile('metadata', 'metadata_master_filled.csv');  % lebih cepat

% Folder berisi 2.234 file stead_event_NNNNN.csv
config.csvFolder    = fullfile('data', 'csv_stead_filtered');

% ── Waveform parameters ───────────────────────────────────────────────────
config.samplingRate  = 100;
config.nSamples       = 6000;
config.durationSec    = 60;
config.channelOrder   = {'E','N','Z'};

% ── Filter provenance (sesuai metadata_master_filled.xlsx) ───────────────
% Filter ini SUDAH diterapkan pada 25.000 records yang ada di metadata.
% Nilai ini dicatat untuk provenance, tidak diterapkan ulang di framework.
config.filter.traceCategory = 'earthquake_local';
config.filter.maxDistanceKm = 15.0;    % <= 15 km (bukan 50 seperti sebelumnya)
config.filter.minMagnitude  = 1.5;
config.filter.minSNR        = 10.0;
config.filter.pStatus       = 'manual';
config.filter.sStatus       = 'manual';
config.filter.version       = 'v1_local_manual_dist15_mag1p5_snr10';
config.filter.reapplyAtLoad = false;

% ── Arrival time source ───────────────────────────────────────────────────
% false (default): gunakan p_arrival/s_arrival dari dalam file CSV (ground truth)
% true           : gunakan p_arrival_sec/s_arrival_sec dari metadata Excel
config.usePArrivalFromMetadata = false;

% ── Filter CSV: hanya load yang file-nya ada di disk ─────────────────────
config.filterExistingCSVOnly = true;

% ── Signal conditioning ───────────────────────────────────────────────────
config.bandpassFreq             = [1, 45];
config.filterOrder               = 4;
config.useDemean                 = true;
config.useDetrend                = true;
config.useNormalization          = true;
config.useEnhancedRepresentation = true;
config.useClipping               = false;
config.clipThreshold             = 10;

% ── Split ─────────────────────────────────────────────────────────────────
% source_id ASLI STEAD tersedia -> split level event benar-benar valid
config.trainRatio = 0.70;
config.valRatio   = 0.15;
config.testRatio  = 0.15;
config.splitKey   = 'source_id';   % ASLI STEAD, bukan alias event_id
config.kFold      = 5;

% ── Gaussian label (dalam samples) ────────────────────────────────────────
config.gaussianSigmaP     = 6;
config.gaussianSigmaS     = 8;
config.gaussianTruncation = 4;
config.useSoftmaxLabels   = false;

% ── Augmentation ──────────────────────────────────────────────────────────
config.useAugmentation     = true;
config.useAdditiveNoise    = true;
config.useAmplitudeScaling = true;
config.useChannelDropout   = true;
config.usePolarityFlip     = false;
config.useTimeShift        = false;  % dimatikan untuk hemat memori
config.augNoiseSNR_dB      = 20;
config.augScaleRange       = [0.5, 2.0];
config.augTimeShiftSamples = 50;
config.augDropoutProb      = 0.20;
config.augFactor           = 1;      % dikurangi dari 3 -> 2x lipat saja
                                     % (set ke 2 atau 3 jika RAM > 16 GB)

% ── Base picker: STA/LTA ──────────────────────────────────────────────────
config.stalta.staSec    = 0.10;
config.stalta.ltaSec    = 1.00;
config.stalta.trigOn    = 3.0;
config.stalta.trigOff   = 1.5;
config.stalta.sigmaConv = 0.15;

% ── Base picker: AIC ──────────────────────────────────────────────────────
config.aic.searchWindowSec = 10.0;
config.aic.sigmaConv       = 0.10;

% ── Base picker: Baseline CNN (LEVEL-1 - BUKAN I-CNN) ────────────────────
% Arsitektur dikecilkan (2 blok, filter lebih sedikit) untuk mengurangi
% penggunaan memori saat training pada sequence panjang T=6000.
config.cnn.numFilters   = [32, 64];    % dikurangi dari [32,64,128]
config.cnn.kernelSize   = 7;
config.cnn.dropout      = 0.30;
config.cnn.maxEpochs    = 30;          % dikurangi dari 50
config.cnn.miniBatch    = 16;          % dikurangi dari 32 -> setengah memori
config.cnn.learningRate = 1e-3;
config.cnn.patience     = 7;

% ── Base picker: Dilated TCN (LEVEL-1 - BUKAN I-CNN) ─────────────────────
% Hanya 4 level dilasi (1,2,4,8) — tanpa residual connection untuk
% menghindari OOM saat batch accumulation di batchNorm.
config.tcn.numFilters   = [32, 32, 32, 32, 32, 32];  % dikurangi dari 64
config.tcn.kernelSize   = 3;
config.tcn.dilations    = [1, 2, 4, 8, 16, 32];       % trainTCN pakai 4 pertama
config.tcn.dropout      = 0.20;
config.tcn.maxEpochs    = 30;           % dikurangi dari 50
config.tcn.miniBatch    = 16;           % dikurangi dari 32
config.tcn.learningRate = 1e-3;
config.tcn.patience     = 7;

% ── I-CNN meta-learner (LEVEL-2 - SATU-SATUNYA yang disebut "I-CNN") ────
config.icnn.numFilters             = [64, 128, 64];
config.icnn.kernelSize             = 5;
config.icnn.dilations              = [1, 2, 4];
config.icnn.dropout                = 0.30;
config.icnn.maxEpochs              = 50;       % dikurangi dari 80
config.icnn.miniBatch              = 16;       % dikurangi dari 32
config.icnn.learningRate           = 5e-4;
config.icnn.patience               = 10;
config.icnn.includeWaveformContext = true;    % false -> C_meta=12, hemat memori
                                               % (set true jika RAM >16 GB)

config.lossWeights.P     = 1.5;
config.lossWeights.S     = 2.5;
config.lossWeights.Noise = 0.5;

% ── Physics-aware picker ──────────────────────────────────────────────────
config.minSPTimeSec      = 0.1;
config.maxSPTimeSec      = 30.0;
config.qualityThresholdP = 3.0;
config.qualityThresholdS = 3.0;
config.pickProbThreshold = 0.30;

% ── Evaluasi ──────────────────────────────────────────────────────────────
config.toleranceMs = [50, 100, 200];
config.snrBins      = [0, 10, 20, Inf];

% ── Experiment mode ───────────────────────────────────────────────────────
config.experimentModes = {'full3C','Zonly','channelDropout','enhancedAblation'};
config.experimentMode  = 'full3C';

% ── Output ────────────────────────────────────────────────────────────────
config.outputFolder = 'results';

% ── Runtime ───────────────────────────────────────────────────────────────
config.verbose    = true;
config.saveFigs   = true;
config.useGPU     = true;
config.numWorkers = 0;

% ── Validasi ──────────────────────────────────────────────────────────────
assert(abs(config.trainRatio + config.valRatio + config.testRatio - 1.0) < 1e-9);
assert(config.minSPTimeSec < config.maxSPTimeSec);
assert(config.gaussianSigmaP > 0 && config.gaussianSigmaS > 0);

end
