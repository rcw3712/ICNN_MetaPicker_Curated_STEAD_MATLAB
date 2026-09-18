function out = augmentClean(data,cfg,seed)
rng(seed,'twister');
if cfg.useAugmentation;out=augmentTrainingWaveform(data,cfg);else;out=data;end
assertRepresentation(out,cfg);
end
