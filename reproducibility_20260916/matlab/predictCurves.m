function curves = predictCurves(model,X,cfg)
curves=cell(numel(X),1);
for i=1:numel(X)
    if model.kind=="logistic"
        z=(double(X{i})-model.mu)./model.scale;
        p=1./(1+exp(-max(-60,min(60,z*model.W+model.b))));
        q=[p,max(0,1-max(p,[],2))];
    else
        y=minibatchpredict(model.net,{single(X{i})},'ExecutionEnvironment',cfg.executionEnvironment);
        if iscell(y);y=y{1};end
        if isa(y,'dlarray');y=extractdata(y);end
        q=double(gather(squeeze(y)));
        if size(q,1)==3 && size(q,2)==size(X{i},1);q=q';end
    end
    assert(isequal(size(q),[size(X{i},1),3]),'Unexpected prediction dimensions.');
    assert(all(isfinite(q),'all'),'Nonfinite model output.');
    curves{i}=struct('P',q(:,1),'S',q(:,2),'Noise',q(:,3));
end
end
