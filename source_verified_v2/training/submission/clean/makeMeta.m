function X = makeMeta(data,cnn,tcn,cfg)

X=cell(numel(data),1);
for i=1:numel(data)
    a=predictCurves(cnn,{data(i).X},cfg);b=predictCurves(tcn,{data(i).X},cfg);
    c=runSTALTAPicker(data(i).X,cfg);d=runAICPicker(data(i).X,cfg);
    X{i}=single([c.P(:),c.S(:),c.Noise(:),d.P(:),d.S(:),d.Noise(:), ...
        a{1}.P,a{1}.S,a{1}.Noise,b{1}.P,b{1}.S,b{1}.Noise,data(i).waveform]);
    assert(size(X{i},2)==15 && all(isfinite(X{i}),'all'));
    if strcmpi(cfg.experimentMode,'Zonly');assert(all(X{i}(:,13:14)==0,'all'));end
end
end
