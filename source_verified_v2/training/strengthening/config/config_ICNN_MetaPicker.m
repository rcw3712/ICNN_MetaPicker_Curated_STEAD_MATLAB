% Numerical implementation from the source-verified v2 run.
% See USER_GUIDE.md for inputs, labels, inert legacy fields and current protocol.

function config = config_ICNN_MetaPicker()

config.version       = '1.0.1';
config.targetJournal  = 'Computers & Geosciences';
config.frameworkName  = 'Leakage-Free I-CNN Meta-Learning Framework (Curated STEAD CSV)';
config.randomSeed     = 42;

config.metadataPath = fullfile('metadata', 'metadata_master_filled.xlsx');

config.csvFolder    = fullfile('data', 'csv_stead_filtered');

config.samplingRate  = 100;
config.nSamples       = 6000;
config.durationSec    = 60;
config.channelOrder   = {'E','N','Z'};

config.filter.traceCategory = 'earthquake_local';
config.filter.maxDistanceKm = 15.0;
config.filter.minMagnitude  = 1.5;
config.filter.minSNR        = 10.0;
config.filter.pStatus       = 'manual';
config.filter.sStatus       = 'manual';
config.filter.version       = 'v1_local_manual_dist15_mag1p5_snr10';
config.filter.reapplyAtLoad = false;

config.usePArrivalFromMetadata = false;

config.filterExistingCSVOnly = true;

config.bandpassFreq             = [1, 45];
config.filterOrder               = 4;
config.useDemean                 = true;
config.useDetrend                = true;
config.useNormalization          = true;
config.useEnhancedRepresentation = true;
config.useClipping               = false;
config.clipThreshold             = 10;

config.trainRatio = 0.70;
config.valRatio   = 0.15;
config.testRatio  = 0.15;
config.splitKey   = 'source_id';
config.kFold      = 5;

config.gaussianSigmaP     = 6;
config.gaussianSigmaS     = 8;
config.gaussianTruncation = 4;
config.useSoftmaxLabels   = false;

config.useAugmentation     = true;
config.useAdditiveNoise    = true;
config.useAmplitudeScaling = true;
config.useChannelDropout   = true;
config.usePolarityFlip     = false;
config.useTimeShift        = false;
config.augNoiseSNR_dB      = 20;
config.augScaleRange       = [0.5, 2.0];
config.augTimeShiftSamples = 50;
config.augDropoutProb      = 0.20;
config.augFactor           = 1;

config.stalta.staSec    = 0.10;
config.stalta.ltaSec    = 1.00;
config.stalta.trigOn    = 3.0;
config.stalta.trigOff   = 1.5;
config.stalta.sigmaConv = 0.15;

config.aic.searchWindowSec = 10.0;
config.aic.sigmaConv       = 0.10;

config.cnn.numFilters   = [32, 64];
config.cnn.kernelSize   = 7;
config.cnn.dropout      = 0.30;
config.cnn.maxEpochs    = 30;
config.cnn.miniBatch    = 16;
config.cnn.learningRate = 1e-3;
config.cnn.patience     = 7;

config.tcn.numFilters   = [32, 32, 32, 32, 32, 32];
config.tcn.kernelSize   = 3;
config.tcn.dilations    = [1, 2, 4, 8, 16, 32];
config.tcn.dropout      = 0.20;
config.tcn.maxEpochs    = 30;
config.tcn.miniBatch    = 16;
config.tcn.learningRate = 1e-3;
config.tcn.patience     = 7;

config.icnn.numFilters             = [64, 128, 64];
config.icnn.kernelSize             = 5;
config.icnn.dilations              = [1, 2, 4];
config.icnn.dropout                = 0.30;
config.icnn.maxEpochs              = 50;
config.icnn.miniBatch              = 16;
config.icnn.learningRate           = 5e-4;
config.icnn.patience               = 10;
config.icnn.includeWaveformContext = true;

config.lossWeights.P     = 1.5;
config.lossWeights.S     = 2.5;
config.lossWeights.Noise = 0.5;

config.minSPTimeSec      = 0.1;
config.maxSPTimeSec      = 30.0;
config.qualityThresholdP = 3.0;
config.qualityThresholdS = 3.0;
config.pickProbThreshold = 0.30;

config.toleranceMs = [50, 100, 200];
config.snrBins      = [0, 10, 20, Inf];

config.experimentModes = {'full3C','Zonly','channelDropout','enhancedAblation'};
config.experimentMode  = 'full3C';

config.outputFolder = 'results';

config.verbose    = true;
config.saveFigs   = true;
config.useGPU     = true;
config.numWorkers = 0;

assert(abs(config.trainRatio + config.valRatio + config.testRatio - 1.0) < 1e-9);
assert(config.minSPTimeSec < config.maxSPTimeSec);
assert(config.gaussianSigmaP > 0 && config.gaussianSigmaS > 0);

end
