function data = addGaussianLabels(data, config)
for i = 1:numel(data)
    data(i).label = generateGaussianMasks(data(i).sec, ...
        data(i).p_arrival_sec, data(i).s_arrival_sec, config);
end
end
