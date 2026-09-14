function [featureMatrix, labelVector] = assemble_feature_matrix(residuals, labels, fs)
%ASSEMBLE_FEATURE_MATRIX  Window every run into features and stack them.
%
%   [X, y] = ASSEMBLE_FEATURE_MATRIX(residuals, labels, fs)
%
%   residuals : cell array. Each element is the logged residual torque of one
%               run, either samples-by-3 or 3-by-samples. Orientation is
%               corrected here, as it was in the original script, because the
%               Simulink log returns either depending on how the signal was
%               logged.
%   labels    : numeric vector, one class label per run. Every window cut from
%               a run inherits that run's label.
%   fs        : sample rate in Hz.
%
%   Returns the feature matrix (windows-by-42) and the matching label column.
%
%   Extracted from build_feature_matrix.m so that the stacking logic can be
%   tested without Simulink and without the bulk .mat runs, which are
%   gitignored. The script keeps the file reading; this keeps the assembly.

    arguments
        residuals cell
        labels (:,1) double
        fs (1,1) double {mustBePositive}
    end

    if numel(residuals) ~= numel(labels)
        error("assemble_feature_matrix:LengthMismatch", ...
              "got %d runs but %d labels", numel(residuals), numel(labels));
    end

    featureMatrix = [];
    labelVector   = [];

    for k = 1:numel(residuals)
        residual = residuals{k};
        if size(residual, 2) ~= 3
            residual = residual.';
        end

        feats = extract_features_windowed(residual, fs);
        n     = size(feats, 1);

        featureMatrix = [featureMatrix; feats];         %#ok<AGROW>
        labelVector   = [labelVector;   labels(k) * ones(n, 1)]; %#ok<AGROW>
    end
end
