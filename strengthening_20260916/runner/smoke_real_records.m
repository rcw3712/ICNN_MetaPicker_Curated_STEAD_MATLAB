function smoke_real_records(rawSplitFile,executionEnvironment)
if nargin<2;executionEnvironment='gpu';end
p=fileparts(mfilename('fullpath'));addpath(fullfile(p,'clean'),fullfile(p,'config'),genpath(fullfile(p,'src')));
s=load(rawSplitFile,'rawTrain');raw=s.rawTrain(1:2);clear s;
cfg=config_ICNN_MetaPicker();cfg.executionEnvironment=executionEnvironment;
cfg.phaseNetMatched=struct('maxEpochs',1,'miniBatch',2,'learningRate',5e-4,'patience',1);
for mode=["Full3C","Zonly"]
 cfg.experimentMode=char(mode);tr=prepareMode(raw,cfg);
 tr=augmentClean(tr,cfg,4242);assertRepresentation(tr,cfg);
 X={tr.waveform}';Y={tr.label}';
 if mode=="Zonly";assert(all(cellfun(@(x)all(x(:,1:2)==0,'all'),X)));end
 % Train/validation reuse is intentional in this functional smoke test only.
 m=fitPhaseNetMatched("PhaseNetMatched",X,Y,X,Y,cfg,43);
 curves=predictCurves(m,X,cfg);picks=decodeClean(curves,cfg,true);
 assert(numel(curves)==numel(tr));assert(~isempty(picks));
 fprintf('[PASS REAL] %s: preprocessing, augmentation, training and decoder.\n',mode);
 clear tr X Y m curves picks;
end
end
