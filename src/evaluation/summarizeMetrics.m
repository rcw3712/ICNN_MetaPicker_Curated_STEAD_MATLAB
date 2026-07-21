function summaryTable = summarizeMetrics(metricsCellArray, labels)

assert(numel(metricsCellArray) == numel(labels), ...
    'summarizeMetrics: metricsCellArray and labels must have the same length');

summaryTable = table();
for i = 1:numel(metricsCellArray)
    t = metricsCellArray{i};
    for r = 1:height(t)
        row = t(r,:);
        row.Condition = labels(i);
        if isempty(summaryTable)
            summaryTable = row;
        else
            summaryTable = [summaryTable; row]; %#ok<AGROW>
        end
    end
end

end
