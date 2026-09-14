classdef TestExtractFeaturesWindowed < matlab.unittest.TestCase
    % Tests for extract_features_windowed, the 42-feature extractor that turns
    % a 3-joint residual-torque signal into the matrix the classifier trains on.
    %
    % 42 features is 3 joints x 14 features per joint. The layout is the
    % contract every downstream script depends on, so it is pinned here.

    properties (Constant)
        FS = 100            % Hz
        NJOINTS = 3
        NPERJOINT = 14
    end

    methods (Static)
        function r = noise(n, seed)
            rng(seed);
            r = randn(n, 3);
        end
    end

    methods (Test)

        function featureCountIsThreeJointsByFourteen(testCase)
            F = extract_features_windowed(TestExtractFeaturesWindowed.noise(10*testCase.FS, 1), testCase.FS);
            testCase.verifySize(F, [size(F,1), testCase.NJOINTS * testCase.NPERJOINT]);
            testCase.verifyEqual(size(F,2), 42);
        end

        function windowCountFollowsTheStatedWindowing(testCase)
            % Two seconds are dropped from each end as ramp-up, then 1 s windows
            % at 50% overlap. Any change to that windowing changes the dataset
            % size and must be a deliberate edit, not a silent one.
            for durationSec = [6 8 10 20]
                n = durationSec * testCase.FS;
                F = extract_features_windowed(TestExtractFeaturesWindowed.noise(n, 2), testCase.FS);
                usable  = n - 4*testCase.FS;
                winLen  = round(testCase.FS);
                step    = round(winLen * 0.5);
                expected = numel(1:step:(usable - winLen + 1));
                testCase.verifyEqual(size(F,1), expected, ...
                    sprintf("window count wrong for a %d s signal", durationSec));
            end
        end

        function extractionIsDeterministic(testCase)
            r = TestExtractFeaturesWindowed.noise(10*testCase.FS, 3);
            testCase.verifyEqual(extract_features_windowed(r, testCase.FS), ...
                                 extract_features_windowed(r, testCase.FS));
        end

        function ordinaryResidualProducesFiniteFeatures(testCase)
            % A realistic residual must never put NaN or Inf into the classifier.
            r = 0.01 * TestExtractFeaturesWindowed.noise(10*testCase.FS, 4);
            F = extract_features_windowed(r, testCase.FS);
            testCase.verifyTrue(all(isfinite(F(:))), "features must be finite");
        end

        function rmsScalesLinearlyWithAmplitude(testCase)
            % Feature 1 of each joint block is RMS, so doubling the residual
            % must double it. This catches a normalisation creeping in.
            r  = TestExtractFeaturesWindowed.noise(10*testCase.FS, 5);
            F1 = extract_features_windowed(r,   testCase.FS);
            F2 = extract_features_windowed(2*r, testCase.FS);
            for j = 0:testCase.NJOINTS-1
                col = j*testCase.NPERJOINT + 1;
                testCase.verifyEqual(F2(:,col), 2*F1(:,col), "RelTol", 1e-10);
            end
        end

        function kurtosisIsInvariantToAmplitude(testCase)
            % Feature 4 is kurtosis, a shape statistic. Scaling the signal must
            % not move it, which is what makes it useful across severities.
            r  = TestExtractFeaturesWindowed.noise(10*testCase.FS, 6);
            F1 = extract_features_windowed(r,   testCase.FS);
            F2 = extract_features_windowed(3*r, testCase.FS);
            for j = 0:testCase.NJOINTS-1
                col = j*testCase.NPERJOINT + 4;
                testCase.verifyEqual(F2(:,col), F1(:,col), "RelTol", 1e-10);
            end
        end

        function rmsOfAConstantChannelIsThatConstant(testCase)
            F = extract_features_windowed(2.5 * ones(10*testCase.FS, 3), testCase.FS);
            testCase.verifyEqual(F(1,1), 2.5, "RelTol", 1e-12);
            testCase.verifyEqual(F(1,3), 0, "AbsTol", 1e-12);   % std of a constant
        end

        function spectralBandPowersAreNonNegative(testCase)
            % Features 7, 8 and 9 are band power fractions of the spectrum.
            r = TestExtractFeaturesWindowed.noise(10*testCase.FS, 7);
            F = extract_features_windowed(r, testCase.FS);
            for j = 0:testCase.NJOINTS-1
                bands = F(:, j*testCase.NPERJOINT + (7:9));
                testCase.verifyGreaterThanOrEqual(bands, 0);
                testCase.verifyLessThanOrEqual(bands, 1 + 1e-9);
            end
        end

        % --- Characterisation of known limitations -----------------------
        % The two tests below pin down behaviour that is NOT desirable. They
        % exist so that the behaviour is visible and cannot change unnoticed,
        % not because it is correct. See docs note in the README.

        function KNOWNLIMITATION_constantChannelYieldsNaNKurtosis(testCase)
            % A perfectly constant channel (a dead sensor, or a joint tracked
            % exactly) gives kurtosis 0/0 = NaN, which propagates into the
            % feature matrix and silently poisons classifier training.
            F = extract_features_windowed(ones(10*testCase.FS, 3), testCase.FS);
            testCase.verifyTrue(any(isnan(F(:))), ...
                "expected the documented NaN; if this now passes cleanly the limitation was fixed and this test should be replaced by an all-finite assertion");
        end

        function KNOWNLIMITATION_tooShortSignalReturnsEmptyInsteadOfErroring(testCase)
            % Shorter than the 4 s of trim plus one window yields a 0x42 matrix
            % rather than an error, so a truncated run can pass through the
            % pipeline contributing no rows and no warning.
            F = extract_features_windowed(randn(3*testCase.FS, 3), testCase.FS);
            testCase.verifySize(F, [0 42]);
        end

    end
end
