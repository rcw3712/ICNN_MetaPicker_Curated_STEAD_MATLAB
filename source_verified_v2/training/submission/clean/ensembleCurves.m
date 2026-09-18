function curves = ensembleCurves(X,weights)
assert(isequal(size(weights),[4 2]));assert(all(weights>=0,'all'));
assert(all(abs(sum(weights,1)-1)<1e-9));curves=cell(numel(X),1);
for i=1:numel(X)
    z=double(X{i}(:,1:12));
    p=z(:,[1 4 7 10])*weights(:,1);s=z(:,[2 5 8 11])*weights(:,2);
    curves{i}=struct('P',p,'S',s,'Noise',max(0,1-max(p,s)));
end
end
