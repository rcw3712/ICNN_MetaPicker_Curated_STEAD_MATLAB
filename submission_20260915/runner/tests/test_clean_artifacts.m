function test_clean_artifacts()
root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'clean'),fullfile(root,'config'),genpath(fullfile(root,'src')));
folder=tempname;mkdir(folder);cfg=config_ICNN_MetaPicker();cfg.executionEnvironment='cpu';
% SHA fixture and checkpoint reuse validation.
f=fullfile(folder,'hash.txt');fid=fopen(f,'w');fprintf(fid,'abc');fclose(fid);
assert(sha256File(f)=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
plan=trainingPlan40();data=repmat(struct('event_id','','source_id','', ...
    'p_arrival_sec',.2,'s_arrival_sec',.7),4,1);
for i=1:4;data(i).event_id=sprintf('e%d',i);data(i).source_id=sprintf('s%d',ceil(i/2));end
curves=cell(4,1);features=cell(4,1);
for i=1:4
    x=zeros(100,1);y=x;x(21)=.9;y(71)=.9;
    curves{i}=struct('P',x,'S',y,'Noise',max(0,1-max(x,y)));
    features{i}=[repmat([x y curves{i}.Noise],1,4),zeros(100,3)];
end
exportBaselines(features,features,data,data,cfg,fullfile(folder,'baseline_fixture'));
% Reuse requires the exact run signature and record identities, not just N.
job=plan(1,:);sub=fullfile(folder,'models',job.mode);mkdir(sub);
fit=data(1:2);validation=data(3:4);
model=struct('jobId',job.id,'runSignature',"fixture_signature", ...
    'trainKeys',string({fit.event_id})','valKeys',string({validation.event_id})', ...
    'trainSources',string({fit.source_id})','valSources',string({validation.source_id})');
save(fullfile(sub,job.id+".mat"),'model');
reused=fitJob(job,{}, {}, {}, {},cfg,fit,validation,"fixture_signature",folder);
assert(reused.jobId==job.id);
failed=false;try;fitJob(job,{}, {}, {}, {},cfg,fit,validation,"wrong_signature",folder);catch;failed=true;end
assert(failed,'Mismatched cache signature was accepted.');
failed=false;try;fitJob(job,{}, {}, {}, {},cfg,fit([2 1]),validation,"fixture_signature",folder);catch;failed=true;end
assert(failed,'Mismatched record order was accepted.');
% Exercise final summary assembly for exactly 40 planned checkpoint entries.
for i=1:height(plan)
    sub=fullfile(folder,'models',plan.mode(i));if ~isfolder(sub);mkdir(sub);end
    model=struct('jobId',plan.id(i),'elapsedSeconds',0);
    save(fullfile(sub,plan.id(i)+".mat"),'model');
    if plan.fold(i)==-1
        exportClean(curves,data,cfg,fullfile(folder,plan.mode(i),'evaluation'), ...
            plan.kind(i)+"_seed"+plan.seed(i));
    end
end
summarizeClean(folder,plan);
t=readtable(fullfile(folder,'training_ledger_40.csv'));assert(height(t)==40);
r=readtable(fullfile(folder,'multiseed_runs_clean.csv'));assert(height(r)==96);
assert(isfile(fullfile(folder,'figures_clean','F1_100ms.png')));
disp('PASS: hashes, baseline exports, 40-checkpoint ledger, 96 metric rows, cluster CSVs and summary figures.');
end
