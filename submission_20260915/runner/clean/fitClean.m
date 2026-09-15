function model = fitClean(kind,X,Y,V,L,cfg,seed)
% Shared trainer. Validation records are never augmented by callers.
rng(seed,'twister');
if strcmpi(cfg.executionEnvironment,'gpu');gpurng(seed);end
kind=string(kind);model=struct('kind',kind);
assert(numel(X)==numel(Y)&&numel(V)==numel(L)&&~isempty(V));
if kind=="logistic"
    model=fitLogisticClean(X,Y);return;
end
if kind=="CNN"
    c=cfg.cnn;filters=c.numFilters;kernels=repmat(c.kernelSize,1,2);dils=[1 1];
elseif kind=="TCN"
    c=cfg.tcn;filters=repmat(c.numFilters(1),1,4);kernels=repmat(c.kernelSize,1,4);dils=c.dilations(1:4);
else
    c=cfg.icnn;filters=[64 128 64 64];kernels=repmat(c.kernelSize,1,4);dils=[1 c.dilations];
end
layers=sequenceInputLayer(size(X{1},2),'Normalization','none','Name','input');
for i=1:numel(filters)
    name=sprintf('block%d',i);
    layers=[layers;convolution1dLayer(kernels(i),filters(i),'Padding','same', ...
        'DilationFactor',dils(i),'Name',[name '_conv']); ...
        batchNormalizationLayer('Name',[name '_bn']);reluLayer('Name',[name '_relu']); ...
        dropoutLayer(c.dropout,'Name',[name '_drop'])]; %#ok<AGROW>
end
layers=[layers;convolution1dLayer(1,3,'Name','head');softmaxLayer('Name','probability')];


weights=single([1 1 1]);
if kind~="CNN" && kind~="TCN"
    weights=single([cfg.lossWeights.P cfg.lossWeights.S cfg.lossWeights.Noise]);
end
% Pre-weighted soft targets implement -sum_k w_k*y_k*log(p_k).
training=sequenceStore(X,Y,weights);
validation=sequenceStore(V,L,weights);
options=trainingOptions('adam','MaxEpochs',c.maxEpochs,'MiniBatchSize',c.miniBatch, ...
    'InitialLearnRate',c.learningRate,'LearnRateSchedule','piecewise', ...
    'LearnRateDropFactor',.5,'LearnRateDropPeriod',20,'L2Regularization',1e-4, ...
    'ValidationData',validation,'ValidationFrequency',max(1,ceil(numel(X)/c.miniBatch)), ...
    'ValidationPatience',c.patience,'OutputNetwork','best-validation-loss', ...
    'Shuffle','every-epoch','Verbose',true,'VerboseFrequency',max(1,ceil(numel(X)/c.miniBatch)),'Plots','none', ...
    'ExecutionEnvironment',cfg.executionEnvironment);
[model.net,info]=trainnet(training,layers,'crossentropy',options);
model.trainingInfo=info;model.seed=seed;model.weights=weights;model.config=c;
model.inputChannels=size(X{1},2);
end

function ds=sequenceStore(X,Y,weights)
% Convert per observation instead of allocating complete single copies.
a=arrayDatastore(X(:),'IterationDimension',1,'OutputType','same');
b=arrayDatastore(Y(:),'IterationDimension',1,'OutputType','same');
ds=transform(combine(a,b),@(batch)convertBatch(batch,weights));
end

function batch=convertBatch(batch,weights)
for i=1:size(batch,1)
    batch{i,1}=single(batch{i,1});
    batch{i,2}=single(batch{i,2}).*weights;
end
end