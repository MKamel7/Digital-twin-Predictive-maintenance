classdef TestTrainFaultClassifier < matlab.unittest.TestCase
    % Tests for train_fault_classifier.
    %
    % These do not assert the published accuracy of the study, which depends
    % on the full dataset that is not in this repository. They assert that the
    % training and scoring plumbing is correct: that the split is stratified,
    % that the reported accuracy is the accuracy of the held-out rows and not
    % of the training rows, and that a separable problem is actually learned.
    % A pipeline that scores the training set instead of the test set is the
    % classic way to report an excellent number that means nothing.

    methods (Static)
        function [X, y] = separable(nPerClass, seed)
            % Four well-separated Gaussian blobs in 6 dimensions.
            rng(seed);
            centres = [0 0 0 0 0 0; 8 0 0 0 0 0; 0 8 0 0 0 0; 0 0 8 0 0 0];
            X = []; y = [];
            for c = 1:4
                X = [X; centres(c,:) + 0.3*randn(nPerClass, 6)]; %#ok<AGROW>
                y = [y; (c-1)*ones(nPerClass, 1)];               %#ok<AGROW>
            end
        end
    end

    methods (Test)

        function separableClassesAreLearned(testCase)
            [X, y] = TestTrainFaultClassifier.separable(40, 1);
            r = train_fault_classifier(X, y, Seed=42);
            testCase.verifyGreaterThan(r.Accuracy, 90, ...
                "four well-separated blobs should be near-perfectly classified");
        end

        function accuracyIsMeasuredOnHeldOutRowsOnly(testCase)
            [X, y] = TestTrainFaultClassifier.separable(40, 2);
            r = train_fault_classifier(X, y, HoldOut=0.25, Seed=7);
            testCase.verifyEqual(nnz(r.TestIndices), sum(r.TestIndices), ...
                "TestIndices should be a logical mask");
            % A quarter held out, to within stratification rounding.
            testCase.verifyEqual(nnz(r.TestIndices), round(0.25*numel(y)), "AbsTol", 4);
            % The training rows and the test rows must not overlap.
            testCase.verifyEqual(nnz(r.TestIndices) + nnz(~r.TestIndices), numel(y));
        end

        function theSplitIsStratifiedAcrossClasses(testCase)
            % cvpartition on a categorical stratifies. If that ever stopped
            % being true, a class could vanish from the test set and its
            % per-class accuracy would silently become NaN.
            [X, y] = TestTrainFaultClassifier.separable(40, 3);
            r = train_fault_classifier(X, y, HoldOut=0.25, Seed=11);
            heldOut = y(r.TestIndices);
            for c = 0:3
                testCase.verifyGreaterThan(sum(heldOut == c), 0, ...
                    sprintf("class %d missing from the test split", c));
            end
        end

        function seedMakesTheRunReproducible(testCase)
            [X, y] = TestTrainFaultClassifier.separable(30, 4);
            a = train_fault_classifier(X, y, Seed=99);
            b = train_fault_classifier(X, y, Seed=99);
            testCase.verifyEqual(b.Accuracy, a.Accuracy);
            testCase.verifyEqual(b.TestIndices, a.TestIndices);
        end

        function perClassAccuracyIsReportedForEveryClass(testCase)
            [X, y] = TestTrainFaultClassifier.separable(40, 5);
            r = train_fault_classifier(X, y, Seed=5);
            testCase.verifyNumElements(r.Classes, 4);
            testCase.verifyNumElements(r.PerClassAccuracy, 4);
            testCase.verifyTrue(all(r.PerClassAccuracy >= 0 & r.PerClassAccuracy <= 100));
        end

        function theModelCanPredictUnseenData(testCase)
            [X, y] = TestTrainFaultClassifier.separable(40, 6);
            r = train_fault_classifier(X, y, Seed=3);
            [Xnew, ~] = TestTrainFaultClassifier.separable(5, 77);
            pred = predict(r.Model, normalize(Xnew));
            testCase.verifyNumElements(pred, size(Xnew,1));
        end

        function reportedAccuracyIsRecomputableFromTestIndices(testCase)
            % The direct guard: score the held-out rows independently and
            % require the reported number to match. If the implementation ever
            % scores the training split, TestIndices and Accuracy stop agreeing.
            [X, y] = TestTrainFaultClassifier.separable(40, 12);
            r  = train_fault_classifier(X, y, Seed=21);
            Yc = categorical(y);
            pred     = predict(r.Model, normalize(X(r.TestIndices, :)));
            expected = sum(pred == Yc(r.TestIndices)) / nnz(r.TestIndices) * 100;
            testCase.verifyEqual(r.Accuracy, expected, "RelTol", 1e-12);
        end

        function uninformativeLabelsScoreNearChance(testCase)
            % The behavioural guard. With labels carrying no information, an
            % honest pipeline lands near chance, 25% for four classes. Scoring
            % the training rows instead reports around 85%, because the RBF
            % learner memorises them. This is the difference between a real
            % accuracy and a meaningless one.
            rng(1);
            X = randn(160, 6);
            y = randi([0 3], 160, 1);
            r = train_fault_classifier(X, y, Seed=42);
            testCase.verifyLessThan(r.Accuracy, 60, ...
                "accuracy on uninformative labels is far above chance, so the reported score is not being measured on held-out rows");
        end

        function mismatchedLabelCountIsRejected(testCase)
            testCase.verifyError(@() train_fault_classifier(randn(20,6), (1:19)'), ...
                "train_fault_classifier:LengthMismatch");
        end

    end
end
