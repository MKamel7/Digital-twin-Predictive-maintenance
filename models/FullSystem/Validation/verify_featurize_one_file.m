projectRoot = 'E:\Digital twin Predictive maintenance\Digital twin Predictive maintenance';
datasetRoot = fullfile(projectRoot, 'data', 'phase2_dataset_v1');
balancedRoot = fullfile(projectRoot, 'data', 'phase2_dataset_balanced_v1');
reportFolder = fullfile(balancedRoot, 'validation_reports');
addpath(fullfile(projectRoot, 'models', 'FullSystem', 'Validation'));

%% Load trained model's exact featureVars list
modelFiles = dir(fullfile(reportFolder, 'svm_final_model_*.mat'));
[~, idx] = max([modelFiles.datenum]);
A = load(fullfile(modelFiles(idx).folder, modelFiles(idx).name), 'result');
featureVars = A.result.featureVars;
fprintf('Loaded model featureVars: %d features\n', numel(featureVars));

%% Load the already-computed feature table (ground truth from step16)
featFiles = dir(fullfile(reportFolder, 'balanced_extracted_features_*.csv'));
[~, idx] = max([featFiles.datenum]);
opts = detectImportOptions(fullfile(featFiles(idx).folder, featFiles(idx).name), 'Delimiter', ',', 'VariableNamingRule', 'preserve');
T = readtable(fullfile(featFiles(idx).folder, featFiles(idx).name), opts);
for k = 1:width(T)
    n = T.Properties.VariableNames{k};
    if iscell(T.(n)) || ischar(T.(n)) || iscategorical(T.(n))
        T.(n) = string(T.(n));
    end
end

testRows = T(T.split_family_holdout == "test", :);

%% Pick one file per condition (not just table order) -- report worst-case diff
conditions = unique(testRows.condition);
rowIdx = zeros(numel(conditions),1);
for c = 1:numel(conditions)
    rowIdx(c) = find(testRows.condition == conditions(c), 1);
end
nCheck = numel(rowIdx);
worstDiff = 0;
worstFile = "";

for r = 1:nCheck
    row = testRows(rowIdx(r), :);
    cond = row.condition;
    subset = row.source_subset;
    fname = row.file_name;

    if cond == "healthy"
        if subset == "extra_healthy"
            folder = "healthy_extra_balanced";
        else
            folder = "healthy";
        end
    else
        folder = cond;
    end
    filePath = fullfile(datasetRoot, folder, fname);

    S = load(filePath, 'data');
    data = S.data;

    idxTrim = data.time > data.startup_ignore_s;
    fs = 1000;
    if isfield(data, 'sample_rate'); fs = data.sample_rate; end

    motor = data.delta_tau_motor(idxTrim, :);
    sensed = data.delta_tau_sensed(idxTrim, :);

    featStruct = featurize_one_file(motor, sensed, fs);

    newVec = zeros(1, numel(featureVars));
    oldVec = zeros(1, numel(featureVars));
    for i = 1:numel(featureVars)
        newVec(i) = featStruct.(featureVars{i});
        oldVec(i) = row.(featureVars{i});
    end

    diffVec = abs(newVec - oldVec);
    maxDiff = max(diffVec);

    fprintf('File %d (%s, %s): max|diff| = %.3e', r, fname, cond, maxDiff);
    if maxDiff > 1e-9
        [~, worstIdx] = max(diffVec);
        fprintf('  <-- MISMATCH at feature "%s": new=%.6g old=%.6g\n', ...
            featureVars{worstIdx}, newVec(worstIdx), oldVec(worstIdx));
    else
        fprintf('  OK\n');
    end

    if maxDiff > worstDiff
        worstDiff = maxDiff;
        worstFile = fname;
    end
end

fprintf('\n============================================================\n');
fprintf('ROUND-TRIP TEST RESULT\n');
fprintf('============================================================\n');
fprintf('Worst max|diff| across %d files: %.3e (file: %s)\n', nCheck, worstDiff, worstFile);
if worstDiff < 1e-9
    fprintf('PASS -- featurize_one_file.m reproduces training features exactly.\n');
else
    fprintf('FAIL -- mismatch exceeds tolerance. Do not build GUI on this yet.\n');
end
