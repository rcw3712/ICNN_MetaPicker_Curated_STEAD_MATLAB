function export_training_history(checkpoint,outputDirectory)
% Export training histories from an existing final checkpoint; no training.
if ~isfolder(outputDirectory);mkdir(outputDirectory);end
s=load(checkpoint,'model');info=s.model.trainingInfo;
writetable(info.TrainingHistory,fullfile(outputDirectory,'training_history.csv'));
writetable(info.ValidationHistory,fullfile(outputDirectory,'validation_history.csv'));
end
