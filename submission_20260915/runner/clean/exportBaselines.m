function exportBaselines(V,T,valData,testData,cfg,folder)
% Weights fitted exclusively from validation standalone F1, separately by phase.
names=["STA","AIC","CNN","TCN"];weights=zeros(4,2);
for pk=1:4
    w=zeros(4,2);w(pk,:)=1;
    cv=ensembleCurves(V,w);
    m=evaluateClean(predictionTable(decodeClean(cv,cfg,true),valData),true);
    weights(pk,1)=m.F1(m.Phase=="P"&m.Tolerance_ms==100);
    weights(pk,2)=m.F1(m.Phase=="S"&m.Tolerance_ms==100);
    exportClean(ensembleCurves(T,w),testData,cfg,folder,names(pk));
end
validationF1=weights;
for ph=1:2
    if sum(weights(:,ph))==0;weights(:,ph)=.25;
    else;weights(:,ph)=weights(:,ph)/sum(weights(:,ph));end
end
save(fullfile(folder,'validation_weights.mat'),'weights','validationF1');
writetable(table(names',validationF1(:,1),validationF1(:,2),weights(:,1),weights(:,2), ...
    'VariableNames',{'Picker','ValidationF1_P','ValidationF1_S','Weight_P','Weight_S'}), ...
    fullfile(folder,'validation_weights.csv'));
exportClean(ensembleCurves(T,ones(4,2)/4),testData,cfg,folder,"mean_ensemble");
exportClean(ensembleCurves(T,weights),testData,cfg,folder,"weighted_ensemble");
end
