function data = prepareMode(data,cfg)
for i=1:numel(data)
    t=data(i).sec(:);assert(numel(t)==cfg.nSamples);
    assert(max(abs(t-(0:cfg.nSamples-1)'/cfg.samplingRate))<1e-7,'Unexpected time grid.');
    if strcmpi(cfg.experimentMode,'Zonly');data(i).waveform(:,1:2)=0;end
end
data=addGaussianLabels(applyPreprocessing(data,cfg),cfg);
assertRepresentation(data,cfg);
end
