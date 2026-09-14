classdef TestQuinticTrajCopiesAgree < matlab.unittest.TestCase
    % quintic_traj.m exists in four places: the repository root and one copy
    % beside each Simulink model (models/FullSystem, models/Physical,
    % models/Virtual). They are identical today.
    %
    % That duplication is a live hazard. Which copy a script actually calls
    % depends on MATLAB path order, and addpath prepends, so adding a model
    % folder after the root silently changes which trajectory generator the
    % robot is commanded with. If someone fixes a bug in one copy and not the
    % others, the copies diverge and the behaviour depends on load order.
    %
    % This test fails the build the moment they stop agreeing.

    properties (Constant)
        Copies = [ "quintic_traj.m"
                   fullfile("models", "FullSystem", "quintic_traj.m")
                   fullfile("models", "Physical",   "quintic_traj.m")
                   fullfile("models", "Virtual",    "quintic_traj.m") ]
    end

    methods (Static)
        function root = projectRoot()
            root = fileparts(fileparts(mfilename("fullpath")));
        end
    end

    methods (Test)

        function allCopiesArePresent(testCase)
            root = TestQuinticTrajCopiesAgree.projectRoot();
            for k = 1:numel(TestQuinticTrajCopiesAgree.Copies)
                p = fullfile(root, TestQuinticTrajCopiesAgree.Copies(k));
                testCase.verifyTrue(isfile(p), "missing copy: " + TestQuinticTrajCopiesAgree.Copies(k));
            end
        end

        function allCopiesAreByteIdentical(testCase)
            root = TestQuinticTrajCopiesAgree.projectRoot();
            reference = fileread(fullfile(root, TestQuinticTrajCopiesAgree.Copies(1)));
            for k = 2:numel(TestQuinticTrajCopiesAgree.Copies)
                other = fileread(fullfile(root, TestQuinticTrajCopiesAgree.Copies(k)));
                testCase.verifyEqual(other, reference, ...
                    "quintic_traj copies have diverged: " + TestQuinticTrajCopiesAgree.Copies(k) + ...
                    " no longer matches the repository-root copy. Reconcile them, " + ...
                    "or reduce them to one file on the path.");
            end
        end

        function theRootCopyIsTheOneOnThePath(testCase)
            % Pins the resolution order that scripts/run_public_ci_checks.m sets
            % up, so a future edit to the addpath order is caught here rather
            % than by a silently different trajectory at run time.
            resolved = which("quintic_traj");
            expected = fullfile(TestQuinticTrajCopiesAgree.projectRoot(), "quintic_traj.m");
            testCase.verifyEqual(string(resolved), string(expected), ...
                "quintic_traj resolved to an unexpected copy");
        end

    end
end
