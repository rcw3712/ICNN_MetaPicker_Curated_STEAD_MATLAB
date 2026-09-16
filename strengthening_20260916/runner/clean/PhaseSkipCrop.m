classdef PhaseSkipCrop < nnet.layer.Layer & nnet.layer.Formattable
% Center crop the upsampled sequence to the encoder skip length.
methods
 function layer=PhaseSkipCrop(name)
  layer.Name=name;layer.NumInputs=2;layer.InputNames={'up','skip'};
 end
 function Z=predict(~,up,skip)
  t=finddim(up,'T');c=finddim(up,'C');
  n=size(skip,t);extra=size(up,t)-n;assert(extra>=0);
  idx=repmat({':'},1,ndims(up));idx{t}=floor(extra/2)+(1:n);
  Z=cat(c,skip,up(idx{:}));
 end
end
end
