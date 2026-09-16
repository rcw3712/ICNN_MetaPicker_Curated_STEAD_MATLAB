function picks = decodeClean(curves,cfg,useSPWindow)
if nargin<3;useSPWindow=true;end
N=numel(curves);blank=struct('p_pred_sec',NaN,'s_pred_sec',NaN, ...
    'p_status',"not_detected",'s_status',"not_detected",'p_quality',0,'s_quality',0);
picks=repmat(blank,N,1);
for i=1:N
    p=curves{i}.P(:);s=curves{i}.S(:);T=numel(p);
    assert(numel(s)==T && all(isfinite([p;s])));
    [peak,ip]=max(p);q=peak/(mean(p)+1e-6);
    status=classify(peak,q,cfg.qualityThresholdP);
    picks(i).p_status=status;picks(i).p_quality=q;
    if status~="not_detected";picks(i).p_pred_sec=(ip-1)/cfg.samplingRate;end
    mask=true(T,1);
    if useSPWindow
        if status=="not_detected";continue;end
        dt=((1:T)'-ip)/cfg.samplingRate;
        mask=dt>=cfg.minSPTimeSec-1e-10 & dt<=cfg.maxSPTimeSec+1e-10;
    end
    if ~any(mask);continue;end
    tmp=s;tmp(~mask)=-Inf;[peak,is]=max(tmp);q=peak/(mean(s(mask))+1e-6);
    status=classify(peak,q,cfg.qualityThresholdS);
    picks(i).s_status=status;picks(i).s_quality=q;
    if status~="not_detected";picks(i).s_pred_sec=(is-1)/cfg.samplingRate;end
end
    function status=classify(peak,q,quality)
        if peak>=cfg.pickProbThreshold && q>=quality;status="detected";
        elseif peak>=cfg.pickProbThreshold*.5;status="uncertain";
        else;status="not_detected";end
    end
end
