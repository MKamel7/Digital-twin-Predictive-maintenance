classdef TestQuinticTraj < matlab.unittest.TestCase
    % Tests for quintic_traj, the 5th-order polynomial trajectory generator.
    %
    % The function claims to guarantee zero velocity AND zero acceleration at
    % both ends of the segment. That claim is the reason the trajectory is safe
    % to command to a joint, so it is tested exactly rather than loosely.

    properties (Constant)
        Q0 = 0.5
        QF = -1.25
        T  = 2.0
    end

    methods (Test)

        function endpointPositionsAreExact(testCase)
            t = linspace(0, testCase.T, 201).';
            q = quintic_traj(testCase.Q0, testCase.QF, testCase.T, t);
            testCase.verifyEqual(q(1), testCase.Q0, "AbsTol", 1e-12);
            testCase.verifyEqual(q(end), testCase.QF, "AbsTol", 1e-12);
        end

        function velocityIsZeroAtBothEnds(testCase)
            t = linspace(0, testCase.T, 201).';
            [~, dq] = quintic_traj(testCase.Q0, testCase.QF, testCase.T, t);
            testCase.verifyEqual(dq(1), 0, "AbsTol", 1e-12);
            testCase.verifyEqual(dq(end), 0, "AbsTol", 1e-12);
        end

        function accelerationIsZeroAtBothEnds(testCase)
            t = linspace(0, testCase.T, 201).';
            [~, ~, ddq] = quintic_traj(testCase.Q0, testCase.QF, testCase.T, t);
            testCase.verifyEqual(ddq(1), 0, "AbsTol", 1e-12);
            testCase.verifyEqual(ddq(end), 0, "AbsTol", 1e-12);
        end

        function midpointIsHalfwayBySymmetry(testCase)
            % The quintic basis is symmetric about tau = 0.5, so the midpoint
            % of the segment is the midpoint of the joint range.
            q = quintic_traj(testCase.Q0, testCase.QF, testCase.T, testCase.T/2);
            testCase.verifyEqual(q, (testCase.Q0 + testCase.QF)/2, "AbsTol", 1e-12);
        end

        function peakVelocityMatchesClosedForm(testCase)
            % max(ds/dtau) over [0,1] is 1.875, reached at tau = 0.5.
            [~, dq] = quintic_traj(testCase.Q0, testCase.QF, testCase.T, testCase.T/2);
            expected = 1.875 * (testCase.QF - testCase.Q0) / testCase.T;
            testCase.verifyEqual(dq, expected, "RelTol", 1e-12);
        end

        function peakAccelerationMatchesClosedForm(testCase)
            % max|dds/dtau^2| is 10/sqrt(3), reached at tau = (3 - sqrt(3))/6.
            tau = (3 - sqrt(3))/6;
            [~, ~, ddq] = quintic_traj(testCase.Q0, testCase.QF, testCase.T, tau*testCase.T);
            expected = (10/sqrt(3)) * (testCase.QF - testCase.Q0) / testCase.T^2;
            testCase.verifyEqual(ddq, expected, "RelTol", 1e-12);
        end

        function timeIsClampedOutsideTheSegment(testCase)
            % Guards the joint against floating-point overshoot on t: before the
            % segment the command holds q0, after it holds qf, both at rest.
            [q, dq, ddq] = quintic_traj(testCase.Q0, testCase.QF, testCase.T, [-1; 3]);
            testCase.verifyEqual(q, [testCase.Q0; testCase.QF], "AbsTol", 1e-12);
            testCase.verifyEqual(dq, [0; 0], "AbsTol", 1e-12);
            testCase.verifyEqual(ddq, [0; 0], "AbsTol", 1e-12);
        end

        function degenerateSegmentHoldsStill(testCase)
            % q0 == qf must produce no motion at all, not a numerical wobble.
            t = linspace(0, testCase.T, 101).';
            [q, dq, ddq] = quintic_traj(1.0, 1.0, testCase.T, t);
            testCase.verifyEqual(q, ones(size(t)), "AbsTol", 1e-12);
            testCase.verifyEqual(dq, zeros(size(t)), "AbsTol", 1e-12);
            testCase.verifyEqual(ddq, zeros(size(t)), "AbsTol", 1e-12);
        end

        function velocityIsTheDerivativeOfPosition(testCase)
            % Central differences on a dense grid, so dq is not merely plausible
            % but actually the derivative of the q that is commanded alongside it.
            t = linspace(0, testCase.T, 20001).';
            [q, dq] = quintic_traj(testCase.Q0, testCase.QF, testCase.T, t);
            dt = t(2) - t(1);
            numeric = (q(3:end) - q(1:end-2)) / (2*dt);
            testCase.verifyEqual(numeric, dq(2:end-1), "AbsTol", 1e-6);
        end

        function accelerationIsTheDerivativeOfVelocity(testCase)
            t = linspace(0, testCase.T, 20001).';
            [~, dq, ddq] = quintic_traj(testCase.Q0, testCase.QF, testCase.T, t);
            dt = t(2) - t(1);
            numeric = (dq(3:end) - dq(1:end-2)) / (2*dt);
            testCase.verifyEqual(numeric, ddq(2:end-1), "AbsTol", 1e-6);
        end

        function motionIsMonotonicBetweenEndpoints(testCase)
            % A quintic with zero end rates never overshoots, so a rising
            % segment must not dip and a falling one must not rise.
            t = linspace(0, testCase.T, 501).';
            q = quintic_traj(0, 1, testCase.T, t);
            testCase.verifyGreaterThanOrEqual(diff(q), -1e-12);
        end

        function outputShapeFollowsTheTimeVector(testCase)
            t = linspace(0, testCase.T, 37).';
            [q, dq, ddq] = quintic_traj(testCase.Q0, testCase.QF, testCase.T, t);
            testCase.verifySize(q, size(t));
            testCase.verifySize(dq, size(t));
            testCase.verifySize(ddq, size(t));
        end

    end
end
