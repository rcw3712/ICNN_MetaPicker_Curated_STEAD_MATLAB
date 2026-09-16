function writeStrengtheningLedger(runRoot,plan)
seconds=zeros(height(plan),1);
for i=1:height(plan)
 s=load(fullfile(runRoot,'models',plan.mode(i),plan.id(i)+".mat"),'model');
 assert(s.model.jobId==plan.id(i));seconds(i)=s.model.elapsedSeconds;
end
writetable([plan,table(seconds)],fullfile(runRoot,'training_ledger.csv'));
end
