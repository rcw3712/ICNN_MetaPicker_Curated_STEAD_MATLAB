function generate_clean_figures(runRoot)
% Summary figures only; all values come from the clean evaluator.
t=readtable(fullfile(runRoot,'multiseed_summary_clean.csv'),'TextType','string');
t=t(t.Tolerance_ms==100,:);folder=fullfile(runRoot,'figures_clean');
if ~isfolder(folder);mkdir(folder);end
for metric=["F1","MAE_ms"]
    f=figure('Visible','off','Color','white','Position',[100 100 1100 550]);
    for j=1:2
        ph=["P","S"];subplot(1,2,j);a=t(t.Phase==ph(j),:);
        y=a.("mean_"+metric);s=a.("std_"+metric);
        bar(y);hold on;errorbar(1:numel(y),y,s,'.k');
        xticks(1:numel(y));xticklabels(a.Mode+" "+a.Variant);xtickangle(45);
        title(ph(j)+" phase");ylabel(metric+" (mean and SD across meta seeds)");grid on;
    end
    exportgraphics(f,fullfile(folder,metric+"_100ms.png"),'Resolution',300);close(f);
end
end
