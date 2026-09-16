function net=phaseNetMatchedLayers()
% PhaseNet-style MATLAB adaptation: 5 levels, 8..128 channels, kernel 7,
% stride 4, BN/ReLU, skip concatenation. Same padding supports 6000 samples.
% Not the official PhaseNet implementation or pretrained benchmark weights.
g=layerGraph([sequenceInputLayer(3,'Normalization','none','MinLength',6000,'Name','input');
 convolution1dLayer(7,8,'Padding','same','Name','inc');
 batchNormalizationLayer('Epsilon',1e-3,'Name','inc_bn');reluLayer('Name','inc_relu')]);
last='inc_relu';skips=strings(4,1);
for i=0:4
 prefix=sprintf('enc%d',i);nf=8*2^i;
 layers=[convolution1dLayer(7,nf,'Padding','same','Name',[prefix '_conv']);
 batchNormalizationLayer('Epsilon',1e-3,'Name',[prefix '_bn']);reluLayer('Name',[prefix '_relu'])];
 g=addLayers(g,layers);g=connectLayers(g,last,[prefix '_conv']);last=[prefix '_relu'];
 if i<4
  skips(i+1)=last;
  layers=[convolution1dLayer(7,nf,'Stride',4,'Padding','same','Name',[prefix '_down']);
   batchNormalizationLayer('Epsilon',1e-3,'Name',[prefix '_down_bn']);reluLayer('Name',[prefix '_down_relu'])];
  g=addLayers(g,layers);g=connectLayers(g,last,[prefix '_down']);last=[prefix '_down_relu'];
 end
end
for i=3:-1:0
 prefix=sprintf('dec%d',i);nf=8*2^i;
 layers=[transposedConv1dLayer(7,nf,'Stride',4,'Cropping','same','Name',[prefix '_up']);
  batchNormalizationLayer('Epsilon',1e-3,'Name',[prefix '_up_bn']);reluLayer('Name',[prefix '_up_relu'])];
 g=addLayers(g,layers);g=connectLayers(g,last,[prefix '_up']);
 g=addLayers(g,PhaseSkipCrop([prefix '_merge']));
 g=connectLayers(g,[prefix '_up_relu'],[prefix '_merge/up']);
 g=connectLayers(g,skips(i+1),[prefix '_merge/skip']);
 layers=[convolution1dLayer(7,nf,'Padding','same','Name',[prefix '_conv']);
  batchNormalizationLayer('Epsilon',1e-3,'Name',[prefix '_bn']);reluLayer('Name',[prefix '_relu'])];
 g=addLayers(g,layers);g=connectLayers(g,[prefix '_merge'],[prefix '_conv']);last=[prefix '_relu'];
end
g=addLayers(g,[convolution1dLayer(1,3,'Name','head');softmaxLayer('Name','probability')]);
g=connectLayers(g,last,'head');net=dlnetwork(g);
end
