% =========================================================================
% Build the feature matrix from the logged runs.
%
% Reads every run under data/healthy and data/faults/<type>, windows each one
% into 42 features per window, and stacks them into feature_matrix with a
% matching label_vector.
%
% The stacking itself lives in assemble_feature_matrix so that it can be
% tested without Simulink. This script does the file reading, which cannot be.
%
% NOTE: the bulk .mat runs are gitignored with one sample kept per category,
% so on a clean checkout this produces a small matrix, not the published one.
% Regenerate the dataset first to reproduce a published number.
% =========================================================================

cd(fileparts(mfilename('fullpath')));

fs          = 1000;
fault_types = {'healthy', 'gear_wear', 'bearing', 'joint_imbalance'};
label_map   = containers.Map(fault_types, {0, 1, 2, 3});

residuals = {};
labels    = [];

% Healthy
files = dir('data/healthy/*.mat');
for i = 1:length(files)
    load(fullfile(files(i).folder, files(i).name), 'out');
    delta          = out.logsout.getElement('delta_tau');
    residuals{end+1} = delta.Values.Data;     %#ok<SAGROW>
    labels(end+1,1)  = label_map('healthy');  %#ok<SAGROW>
end

% Faults
for f_idx = 2:length(fault_types)
    current_fault = fault_types{f_idx};
    files = dir(sprintf('data/faults/%s/*.mat', current_fault));
    for i = 1:length(files)
        load(fullfile(files(i).folder, files(i).name), 'out');
        delta            = out.logsout.getElement('delta_tau');
        residuals{end+1} = delta.Values.Data;             %#ok<SAGROW>
        labels(end+1,1)  = label_map(current_fault);      %#ok<SAGROW>
    end
end

if isempty(residuals)
    error('build_feature_matrix:NoRuns', ...
          ['No run files found under data/. The bulk .mat runs are gitignored, ' ...
           'so generate the dataset before building the feature matrix.']);
end

[feature_matrix, label_vector] = assemble_feature_matrix(residuals, labels, fs);
categories = fault_types;  %#ok<NASGU> name kept: plot_pca.m re-saves it

[~, ~, ~, ~, explained] = pca(normalize(feature_matrix));
fprintf('PC1: %.1f%%  PC2: %.1f%%  Total: %.1f%%\n', ...
    explained(1), explained(2), explained(1) + explained(2));

save('extracted_features.mat', 'feature_matrix', 'label_vector', 'categories');
fprintf('Saved: %d samples, %d features\n', size(feature_matrix,1), size(feature_matrix,2));
