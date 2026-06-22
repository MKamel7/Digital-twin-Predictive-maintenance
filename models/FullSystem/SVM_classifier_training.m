% =========================================================================
% SVM Classifier Training
% =========================================================================
load('extracted_features_balanced.mat');

% Normalize
X = normalize(feature_matrix);
Y = categorical(label_vector);

% Train/test split 80/20
cv    = cvpartition(Y, 'HoldOut', 0.2);
X_train = X(cv.training, :);
Y_train = Y(cv.training);
X_test  = X(cv.test, :);
Y_test  = Y(cv.test);

% Train multiclass SVM
t = templateSVM('KernelFunction', 'rbf', ...
    'BoxConstraint', 1, ...
    'KernelScale', 'auto', ...
    'Standardize', true);

model = fitcecoc(X_train, Y_train, 'Learners', t, ...
    'Coding', 'onevsone');

% Evaluate
Y_pred = predict(model, X_test);

% Confusion matrix
figure;
cm = confusionchart(Y_test, Y_pred, ...
    'Title', 'SVM Fault Classification', ...
    'RowSummary', 'row-normalized', ...
    'ColumnSummary', 'column-normalized');

% Accuracy
acc = sum(Y_pred == Y_test) / numel(Y_test) * 100;
fprintf('Test Accuracy: %.2f%%\n', acc);

% Per-class accuracy
classes = {'healthy','gear_wear','bearing','joint_imbalance'};
for c = 0:3
    idx  = Y_test == categorical(c);
    pacc = sum(Y_pred(idx) == Y_test(idx)) / sum(idx) * 100;
    fprintf('%s accuracy: %.2f%%\n', classes{c+1}, pacc);
end

% Save model
save('svm_fault_classifier.mat', 'model');
fprintf('Model saved.\n');