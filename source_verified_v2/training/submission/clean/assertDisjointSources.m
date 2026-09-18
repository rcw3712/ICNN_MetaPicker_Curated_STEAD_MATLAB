function assertDisjointSources(varargin)
for i=1:nargin
    a=string({varargin{i}.source_id});
    assert(all(~ismissing(a)&strlength(a)>0),'Missing source ID.');
    for j=i+1:nargin
        b=string({varargin{j}.source_id});
        assert(isempty(intersect(a,b)),'ICNN:SourceOverlap','Source leakage detected.');
    end
end
end
