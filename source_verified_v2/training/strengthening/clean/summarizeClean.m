function summarizeClean(runRoot,plan)
receipt=load(fullfile(runRoot,'manifest.mat'),'configuration');cfg=jsondecode(receipt.configuration);sourceRoot=cfg.verifiedSourceRoot;verifiedProtocol(sourceRoot);
assert(string(cfg.sourceProtocolHash)==sha256File(fullfile(sourceRoot,'protocol.json')));
completed=false(height(plan),1);seconds=zeros(height(plan),1);
for i=1:height(plan)
    file=fullfile(runRoot,'models',plan.mode(i),plan.id(i)+".mat");
    s=load(file,'model');assert(s.model.jobId==plan.id(i));
    completed(i)=true;seconds(i)=s.model.elapsedSeconds;
end
ledger=[plan,table(completed,seconds)];writetable(ledger,fullfile(runRoot,'training_ledger_40.csv'));
rows=cell(0,1);
for i=find(plan.fold==-1)'
    file=fullfile(runRoot,plan.mode(i),'evaluation', ...
        plan.kind(i)+"_seed"+plan.seed(i)+"_accepted_metrics.csv");
    t=readtable(file,'TextType','string');
    t.Mode=repmat(plan.mode(i),height(t),1);t.Variant=repmat(plan.kind(i),height(t),1);
    t.Seed=repmat(plan.seed(i),height(t),1);rows{end+1,1}=t; %#ok<AGROW>
end
runs=vertcat(rows{:});writetable(runs,fullfile(runRoot,'multiseed_runs_clean.csv'));
summary=groupsummary(runs,{'Mode','Variant','Phase','Tolerance_ms'},{'mean','std'}, ...
    {'F1','MAE_ms','AcceptedCoverage'});
writetable(summary,fullfile(runRoot,'multiseed_summary_clean.csv'));
% Each bootstrap uses the same source draws for the paired configurations.
for seed=42:44
    a=readVerifiedPredictions(fullfile(runRoot,'Full3C','evaluation',"full15ch_seed"+seed+"_predictions.csv"),sourceRoot);
    b=readVerifiedPredictions(fullfile(runRoot,'Zonly','evaluation',"full15ch_seed"+seed+"_predictions.csv"),sourceRoot);
    ci=pairedClusterCI(a,b,2000,42,true);
    writetable(ci,fullfile(runRoot,"paired_source_cluster_seed"+seed+".csv"));
end
generate_clean_figures(runRoot);
end
