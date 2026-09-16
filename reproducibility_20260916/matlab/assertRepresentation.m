function assertRepresentation(data,cfg)
for i=1:numel(data)
    assert(size(data(i).X,2)==8 && size(data(i).waveform,2)==3);
    assert(all(isfinite(data(i).X),'all') && all(isfinite(data(i).label),'all'));
    if strcmpi(cfg.experimentMode,'Zonly')
        assert(all(data(i).waveform(:,1:2)==0,'all'));
        assert(all(data(i).X(:,[1 2 4 5])==0,'all'),'Z-only horizontal features are nonzero.');
    end
end
end
