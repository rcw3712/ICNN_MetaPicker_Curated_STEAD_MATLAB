function test_clean_protocol()
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'clean'),fullfile(root,'config'),genpath(fullfile(root,'src')));
plan=trainingPlan40();assert(height(plan)==40);
assert(sum(plan.fold>=0)==24&&sum(plan.fold==-1&plan.kind~="logistic")==15&&sum(plan.kind=="logistic")==1);
cfg=config_ICNN_MetaPicker();cfg.experimentMode='Zonly';cfg.nSamples=200;
cfg.executionEnvironment='cpu';cfg.useEnhancedRepresentation=true;
template=struct('source_id','','event_id','','waveform',[],'X',[],'label',[], ...
    'sec',(0:199)'/100,'p_arrival_sec',.4,'s_arrival_sec',1.2,'samplingRate',100, ...
    'p_arrival_sample_0based',40,'s_arrival_sample_0based',120, ...
    'p_arrival_sample_1based',41,'s_arrival_sample_1based',121);
data=repmat(template,20,1);
rng(10);
for i=1:20
    data(i).source_id=sprintf('src%d',ceil(i/2));data(i).event_id=sprintf('event%d',i);
    data(i).waveform=[zeros(200,2),randn(200,1)];
    data(i).X=buildEnhancedRepresentation(data(i).waveform,cfg);
    data(i).label=generateGaussianMasks(data(i).sec,.4,1.2,cfg);
end
folds=sourceFolds(data,5,42);
for k=1:5
    [fit,val]=innerSourceSplit(data(folds~=k),k);held=data(folds==k);
    aug=augmentClean(fit,cfg,k);assertDisjointSources(aug,val,held);
    assertRepresentation(aug,cfg);
end
% Demonstrate the former held-fold reinsertion is caught.
mustFail(@()assertDisjointSources(data(1:5),data(4:8)));
% Positive and negative shifts must move labels in the waveform direction.
cfg.useTimeShift=true;cfg.useAdditiveNoise=false;cfg.useAmplitudeScaling=false;cfg.useChannelDropout=false;
d=data(1);d.waveform=zeros(200,3);d.waveform(41,3)=1;
cfg.augTimeShiftSamples=10;
for seed=1:10
    a=augmentClean(d,cfg,seed);[~,idx]=max(a(2).waveform(:,3));
    assert(abs((idx-1)/100-a(2).p_arrival_sec)<1e-10);
end
cfg.pickProbThreshold=.3;cfg.minSPTimeSec=.1;cfg.maxSPTimeSec=30;
p=zeros(200,1);s=p;p(1)=.9;s(21)=.9;
curves={struct('P',p,'S',s,'Noise',zeros(200,1))};q=decodeClean(curves,cfg,true);
assert(q.p_pred_sec==0&&q.s_pred_sec==.2);
p(:)=.01;curves{1}.P=p;q=decodeClean(curves,cfg,true);
assert(isnan(q.p_pred_sec)&&isnan(q.s_pred_sec));
% Accepted, uncertain, outside tolerance, and not-detected finite candidate.
t=table([0;0;0;0],[.1;.10000000000001;.3;33], ...
    ["detected";"uncertain";"detected";"not_detected"], ...
    'VariableNames',{'p_true_sec','p_pred_sec','p_status'});
t.s_true_sec=t.p_true_sec;t.s_pred_sec=t.p_pred_sec;t.s_status=t.p_status;
t.event_id=["a";"b";"c";"d"];t.source_id=["x";"x";"y";"z"];
m=evaluateClean(t,true);r=m(m.Phase=="P"&m.Tolerance_ms==100,:);
assert(r.TP==2&&r.FP==1&&r.FN==2&&abs(r.MAE_ms-500/3)<1e-7);
m=evaluateClean(t,false);r=m(m.Phase=="P"&m.Tolerance_ms==100,:);
assert(r.N_accepted==2&&r.TP==1);
ci=pairedClusterCI(t,t([4 3 2 1],:),100,42,true);
assert(all(ci.Delta==0 & ci.Delta_low==0 & ci.Delta_high==0));
bad=t;bad.source_id(1)="wrong";mustFail(@()pairedClusterCI(t,bad,10,42,true));
% Horizontal context cannot become a fifth ensemble picker.
x=zeros(200,15);x(:,13:15)=1e6;x(1,[1 4 7 10])=.8;
c=ensembleCurves({x},ones(4,2)/4);assert(c{1}.P(1)==.8&&all(c{1}.S==0));
disp('PASS: 40-job plan, source isolation, augmentation, time shift, decoder, acceptance, F1, paired cluster, ensemble.');
end
function mustFail(fun)
failed=false;try;fun();catch;failed=true;end;assert(failed,'Expected failure did not occur.');
end
