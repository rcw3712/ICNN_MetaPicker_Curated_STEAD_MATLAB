function model = fitPhaseNetJob(job,X,Y,V,L,cfg,trainRecords,valRecords,signature,runRoot)
folder=fullfile(runRoot,'models',job.mode);if ~isfolder(folder);mkdir(folder);end
path=fullfile(folder,job.id+".mat");
trainKeys=string({trainRecords.event_id})';trainSources=string({trainRecords.source_id})';
valKeys=string({valRecords.event_id})';valSources=string({valRecords.source_id})';
assert(isempty(intersect(trainSources,valSources)),'Fit/validation sources overlap.');
if isfile(path)
    s=load(path,'model');model=s.model;
    assert(model.runSignature==signature&&model.jobId==job.id);
    assert(isequal(model.trainKeys,trainKeys)&&isequal(model.valKeys,valKeys));
    assert(isequal(model.trainSources,trainSources)&&isequal(model.valSources,valSources));
    fprintf('[REUSE verified] %s\n',job.id);return;
end
fprintf('[TRAIN] %s\n',job.id);timer=tic;
model=fitPhaseNetMatched(job.kind,X,Y,V,L,cfg,job.seed);
model.elapsedSeconds=toc(timer);model.jobId=job.id;model.runSignature=signature;
model.trainKeys=trainKeys;model.trainSources=trainSources;model.valKeys=valKeys;model.valSources=valSources;
tmp=path+".partial.mat";save(tmp,'model','-v7.3');movefile(tmp,path);
fprintf('[SAVED] %s (%.1f seconds)\n',job.id,model.elapsedSeconds);
end
