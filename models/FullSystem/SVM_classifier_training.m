% =========================================================================
% SVM Classifier Training
%
% Training and scoring live in train_fault_classifier so that they can be
% tested. This script loads the balanced feature set, calls it, then reports
% and saves, which is the part a test has no business running.
% =========================================================================

cd(fileparts(mfilename('fullpath')));

load('extracted_features_balanced.mat');

result = train_fault_classifier(feature_matrix, label_vector);

% Confusion matrix
Y      = categorical(label_vector);
Ytest  = Y(result.TestIndices);
Ypred  = predict(result.Model, normalize(feature_matrix(result.TestIndices, :)));

figure;
confusionchart(Ytest, Ypred, ...
    'Title', 'SVM Fault Classification', ...
    'RowSummary', 'row-normalized', ...
    'ColumnSummary', 'column-normalized');

fprintf('Test Accuracy: %.2f%%\n', result.Accuracy);

class_names = {'healthy', 'gear_wear', 'bearing', 'joint_imbalance'};
for c = 1:numel(result.Classes)
    name = class_names{str2double(result.Classes{c}) + 1};
    fprintf('%s accuracy: %.2f%%\n', name, result.PerClassAccuracy(c));
end

model = result.Model;
save('svm_fault_classifier.mat', 'model');
fprintf('Model saved.\n');
