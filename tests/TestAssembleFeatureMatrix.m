classdef TestAssembleFeatureMatrix < matlab.unittest.TestCase
    % Tests for assemble_feature_matrix, the stacking step of the dataset
    % build. Every window cut from a run must inherit that run's label; if the
    % rows and the labels ever slip relative to each other the classifier
    % trains on mislabelled data and still reports a healthy-looking accuracy.
    %
    % These use synthetic residuals rather than committed .mat fixtures, so
    % they add no weight to the repository and need no Simulink.

    properties (Constant)
        FS = 100
    end

    methods (Static)
        function r = syntheticRun(seconds, seed)
            rng(seed);
            r = randn(seconds * TestAssembleFeatureMatrix.FS, 3);
        end
    end

    methods (Test)

        function rowsAndLabelsStayInStep(testCase)
            residuals = {TestAssembleFeatureMatrix.syntheticRun(10, 1), ...
                         TestAssembleFeatureMatrix.syntheticRun(8,  2), ...
                         TestAssembleFeatureMatrix.syntheticRun(20, 3)};
            [X, y] = assemble_feature_matrix(residuals, [0; 2; 1], testCase.FS);
            testCase.verifyEqual(size(X,1), numel(y));
            testCase.verifyEqual(size(X,2), 42);
        end

        function eachRunContributesItsOwnLabel(testCase)
            % Counts per label must match the windows each run produces.
            r1 = TestAssembleFeatureMatrix.syntheticRun(10, 4);
            r2 = TestAssembleFeatureMatrix.syntheticRun(20, 5);
            n1 = size(extract_features_windowed(r1, testCase.FS), 1);
            n2 = size(extract_features_windowed(r2, testCase.FS), 1);

            [~, y] = assemble_feature_matrix({r1, r2}, [0; 3], testCase.FS);
            testCase.verifyEqual(sum(y == 0), n1);
            testCase.verifyEqual(sum(y == 3), n2);
            testCase.verifyEqual(y(1:n1), zeros(n1,1));
            testCase.verifyEqual(y(n1+1:end), 3*ones(n2,1));
        end

        function transposedRunsAreAccepted(testCase)
            % The Simulink log returns 3-by-samples or samples-by-3 depending
            % on how the signal was logged, so both must give the same answer.
            r = TestAssembleFeatureMatrix.syntheticRun(10, 6);
            [Xa, ya] = assemble_feature_matrix({r},    0, testCase.FS);
            [Xb, yb] = assemble_feature_matrix({r.'},  0, testCase.FS);
            testCase.verifyEqual(Xb, Xa, "RelTol", 1e-12);
            testCase.verifyEqual(yb, ya);
        end

        function runOrderIsPreserved(testCase)
            % Rows must appear in the order the runs were given, because the
            % label column is built alongside them positionally.
            r1 = TestAssembleFeatureMatrix.syntheticRun(10, 7);
            r2 = TestAssembleFeatureMatrix.syntheticRun(10, 8);
            [X12, ~] = assemble_feature_matrix({r1, r2}, [0; 1], testCase.FS);
            [X1,  ~] = assemble_feature_matrix({r1},     0,      testCase.FS);
            testCase.verifyEqual(X12(1:size(X1,1), :), X1, "RelTol", 1e-12);
        end

        function mismatchedLabelCountIsRejected(testCase)
            % Two runs and three labels is a caller bug that would otherwise
            % silently truncate or error deep inside the loop.
            testCase.verifyError( ...
                @() assemble_feature_matrix({randn(1000,3), randn(1000,3)}, [0;1;2], testCase.FS), ...
                "assemble_feature_matrix:LengthMismatch");
        end

        function aSingleRunMatchesTheExtractorDirectly(testCase)
            % The assembly must not alter the features themselves.
            r = TestAssembleFeatureMatrix.syntheticRun(10, 9);
            [X, ~] = assemble_feature_matrix({r}, 1, testCase.FS);
            testCase.verifyEqual(X, extract_features_windowed(r, testCase.FS), "RelTol", 1e-12);
        end

    end
end
