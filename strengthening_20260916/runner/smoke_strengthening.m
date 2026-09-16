function smoke_strengthening(executionEnvironment)
% Synthetic one-update test; does not estimate end-to-end dataset peak RAM.
if nargin<1;executionEnvironment='gpu';end
p=fileparts(mfilename('fullpath'));addpath(fullfile(p,'clean'),fullfile(p,'config'),genpath(fullfile(p,'src')));
cfg=config_ICNN_MetaPicker();cfg.executionEnvironment=executionEnvironment;
cfg.phaseNetMatched=struct('maxEpochs',1,'miniBatch',2,'learningRate',5e-4,'patience',1);
for mode=["Full3C","Zonly"]
 rng(91);X={randn(6000,3,'single');randn(6000,3,'single')};
 if mode=="Zonly";for i=1:2;X{i}(:,1:2)=0;end;end
 Y=repmat({repmat(single([.1 .1 .8]),6000,1)},2,1);
 m=fitPhaseNetMatched("PhaseNetMatched",X,Y,X,Y,cfg,43);
 curves=predictCurves(m,X,cfg);assert(numel(curves)==2);
 q=[curves{1}.P curves{1}.S curves{1}.Noise];assert(max(abs(sum(q,2)-1))<1e-5);
 save(fullfile(tempdir,'phasenet_matched_smoke.mat'),'m','-v7.3');
 z=load(fullfile(tempdir,'phasenet_matched_smoke.mat'),'m');
 q2=predictCurves(z.m,X,cfg);assert(max(abs(q2{1}.P-curves{1}.P))<1e-6);
 fprintf('[PASS] %s: train, 6000-sample output, finite probabilities, serialization.\n',mode);
 clear m z X Y curves q2;
end
for b=[43 44]
 for mode=["Full3C","Zonly"]
  plan=run_seed_repeat('plan',[],[],executionEnvironment,b,mode);
  assert(height(plan)==15 && all(plan.seed(plan.fold>=0)==b));
  assert(isequal(sort(plan.seed(plan.fold==-1)),(42:44)'));
 end
end
fprintf('[PASS] Four seed/mode plans: 60 fits; baseline adds 6 fits.\n');
end
