function smoke_train_clean()
% Tiny synthetic fits only, deliberately separate from the 40 real-data fits.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'clean'),fullfile(root,'config'),genpath(fullfile(root,'src')));
cfg=config_ICNN_MetaPicker();cfg.executionEnvironment='cpu';cfg.useGPU=false;
cfg.cnn.maxEpochs=1;cfg.tcn.maxEpochs=1;cfg.icnn.maxEpochs=1;
cfg.cnn.miniBatch=2;cfg.tcn.miniBatch=2;cfg.icnn.miniBatch=2;
X=cell(4,1);Y=X;M=X;rng(2);T=120;
for i=1:4
    X{i}=randn(T,8,'single');M{i}=randn(T,15,'single');
    Y{i}=single(generateGaussianMasks((0:T-1)'/100,.3,.8,cfg));
end
for k=["CNN","TCN","full15ch","logistic"]
    a=X;if k=="full15ch"||k=="logistic";a=M;end
    model=fitClean(k,a(1:3),Y(1:3),a(4),Y(4),cfg,42);
    c=predictCurves(model,a(4),cfg);assert(numel(c)==1&&numel(c{1}.P)==T);
    tmp=[tempname '.mat'];save(tmp,'model','-v7.3');s=load(tmp,'model');
    c2=predictCurves(s.model,a(4),cfg);assert(max(abs(c{1}.P-c2{1}.P))<1e-6);
    delete(tmp);fprintf('PASS smoke fit/save/reload/infer: %s\n',k);
end
end
