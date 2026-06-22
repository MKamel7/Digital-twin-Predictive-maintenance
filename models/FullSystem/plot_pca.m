load('extracted_features.mat');

counts      = histcounts(label_vector, -0.5:1:3.5);
min_samples = min(counts);
fprintf('Capping at %d samples per class\n', min_samples);

balanced_features = [];
balanced_labels   = [];

for c = 0:3
    idx = find(label_vector == c);
    idx = idx(randperm(length(idx), min_samples));
    balanced_features = [balanced_features; feature_matrix(idx, :)];
    balanced_labels   = [balanced_labels;   label_vector(idx)];
end

[~, score, ~, ~, explained] = pca(normalize(balanced_features));
fprintf('PC1: %.1f%%  PC2: %.1f%%  Total: %.1f%%\n', ...
    explained(1), explained(2), explained(1)+explained(2));

colors = {'b','g','r','c'};
names  = {'healthy','gear\_wear','bearing','joint\_imbalance'};
figure; hold on;
for i = 1:4
    idx = balanced_labels == (i-1);
    scatter(score(idx,1), score(idx,2), 20, colors{i}, 'filled', ...
        'DisplayName', names{i});
end
legend; grid on;
xlabel('Principal Component 1');
ylabel('Principal Component 2');
title('2D PCA — 4 Class Balanced');

feature_matrix = balanced_features;
label_vector   = balanced_labels;
save('extracted_features_balanced.mat', 'feature_matrix', 'label_vector', 'categories');
fprintf('Saved — %d samples per class, %d total\n', min_samples, length(balanced_labels));