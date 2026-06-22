cd('C:\Users\mkame\Desktop\Digital-twin-Predictive-maintenance-main\Digital-twin-Predictive-maintenance-main\models\FullSystem');

fs           = 1000;
all_features = [];
all_labels   = [];

fault_types = {'healthy', 'gear_wear', 'bearing', 'joint_imbalance'};
label_map   = containers.Map(fault_types, {0,1,2,3});

% Healthy
files = dir('data/healthy/*.mat');
for i = 1:length(files)
    load(fullfile(files(i).folder, files(i).name), 'out');
    delta    = out.logsout.getElement('delta_tau');
    residual = delta.Values.Data;
    if size(residual, 2) ~= 3
        residual = residual';
    end
    feats        = extract_features_windowed(residual, fs);
    n            = size(feats, 1);
    all_features = [all_features; feats];
    all_labels   = [all_labels;   zeros(n, 1)];
end

% Faults
for f_idx = 2:length(fault_types)
    current_fault = fault_types{f_idx};
    label         = label_map(current_fault);
    files         = dir(sprintf('data/faults/%s/*.mat', current_fault));
    for i = 1:length(files)
        load(fullfile(files(i).folder, files(i).name), 'out');
        delta    = out.logsout.getElement('delta_tau');
        residual = delta.Values.Data;
        if size(residual, 2) ~= 3
            residual = residual';
        end
        feats        = extract_features_windowed(residual, fs);
        n            = size(feats, 1);
        all_features = [all_features; feats];
        all_labels   = [all_labels;   label * ones(n, 1)];
    end
end

feature_matrix = all_features;
label_vector   = all_labels;
categories     = fault_types;

[~, ~, ~, ~, explained] = pca(normalize(feature_matrix));
fprintf('PC1: %.1f%%  PC2: %.1f%%  Total: %.1f%%\n', ...
    explained(1), explained(2), explained(1)+explained(2));

save('extracted_features.mat', 'feature_matrix', 'label_vector', 'categories');
fprintf('Saved — %d samples, %d features\n', size(feature_matrix,1), size(feature_matrix,2));