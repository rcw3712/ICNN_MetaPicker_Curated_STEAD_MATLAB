function t = exportClean(curves,data,cfg,folder,name)
if ~isfolder(folder);mkdir(folder);end
t=predictionTable(decodeClean(curves,cfg,true),data);
writetable(t,fullfile(folder,name+"_predictions.csv"));
writetable(evaluateClean(t,true),fullfile(folder,name+"_accepted_metrics.csv"));
writetable(evaluateClean(t,false),fullfile(folder,name+"_strict_metrics.csv"));
% Persist curves and identities for reproducible decoder/physics re-analysis.
event_id=t.event_id;source_id=t.source_id;
save(fullfile(folder,name+"_curves.mat"),'curves','event_id','source_id','-v7.3');
raw=predictionTable(decodeClean(curves,cfg,false),data);
writetable(raw,fullfile(folder,name+"_unconstrained_predictions.csv"));
writetable(evaluateClean(raw,true),fullfile(folder,name+"_unconstrained_metrics.csv"));
end
