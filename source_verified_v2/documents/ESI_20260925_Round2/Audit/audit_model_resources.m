function audit_model_resources()
w='C:\Users\catur\.codex\visualizations\2026\09\11\01a08fc7-0cf1-7772-a384-020417c19593';
p=fullfile(w,'sync_repo','source_verified_v2');
addpath(fullfile(p,'training','strengthening','clean'));
t=readtable(fullfile(p,'model_manifest.csv'),'TextType','string');
t.parameters=nan(height(t),1);t.elapsedSeconds=nan(height(t),1);
for i=1:height(t)
 s=load(fullfile(p,t.path(i)),'model');m=s.model;
 if isfield(m,'net')
  t.parameters(i)=sum(cellfun(@numel,m.net.Learnables.Value));
 end
 if isfield(m,'elapsedSeconds');t.elapsedSeconds(i)=m.elapsedSeconds;end
 clear s m;
end
writetable(t,fullfile(w,'model_resources_verified.csv'));
fprintf('READ_ONLY_AUDIT %d checkpoints. No inference or training.\n',height(t));
end
