classdef TestSetFault < matlab.unittest.TestCase
    % Tests for set_fault, which is how a fault is injected before a run.
    %
    % It writes into the base workspace, which the Simulink model then reads.
    % That makes it testable without Simulink: call it, then read the base
    % workspace back. The fault code mapping and the three parameter vectors
    % are what every generated dataset is labelled by, so a silent change to
    % either would mislabel runs rather than fail loudly.

    properties (Access = private)
        Saved struct
    end

    properties (Constant)
        Vars = ["FAULT_TYPE","FAULT_JOINT","DEG_INDEX","GEAR_PARAMS","BEAR_PARAMS","IMB_PARAMS"]
    end

    methods (TestMethodSetup)
        function preserveBaseWorkspace(testCase)
            % set_fault writes into the base workspace, so save whatever is
            % already there and put it back afterwards.
            testCase.Saved = struct();
            for v = TestSetFault.Vars
                if evalin("base", sprintf("exist('%s','var')", v))
                    testCase.Saved.(v) = evalin("base", v);
                end
            end
        end
    end

    methods (TestMethodTeardown)
        function restoreBaseWorkspace(testCase)
            for v = TestSetFault.Vars
                evalin("base", sprintf("clear %s", v));
                if isfield(testCase.Saved, v)
                    assignin("base", v, testCase.Saved.(v));
                end
            end
        end
    end

    methods (Access = private)
        function v = baseValue(~, name)
            v = evalin("base", name);
        end
    end

    methods (Test)

        function faultTypesMapToTheirCodes(testCase)
            % These codes are what label_vector is built from downstream, so
            % they are a data contract, not an implementation detail.
            expected = struct('healthy', 0, 'gear_wear', 1, 'bearing', 2, 'joint_imbalance', 3);
            names = fieldnames(expected);
            for k = 1:numel(names)
                evalc("set_fault(names{k}, 1, 0.5)");   % evalc silences its printout
                testCase.verifyEqual(testCase.baseValue("FAULT_TYPE"), expected.(names{k}), ...
                    "wrong code for " + names{k});
            end
        end

        function jointAndSeverityArePassedThrough(testCase)
            evalc("set_fault('bearing', 3, 0.75)");
            testCase.verifyEqual(testCase.baseValue("FAULT_JOINT"), 3);
            testCase.verifyEqual(testCase.baseValue("DEG_INDEX"), 0.75);
        end

        function parameterVectorsAreTheDocumentedConstants(testCase)
            % Pinned so that a tweak during an experiment cannot silently
            % change the physical meaning of every run generated afterwards.
            evalc("set_fault('healthy', 1, 0)");
            testCase.verifyEqual(testCase.baseValue("GEAR_PARAMS"), [6.0, 7.5, 3.0, 0.75, 28.0]);
            testCase.verifyEqual(testCase.baseValue("BEAR_PARAMS"), [4.0, 3.0, 1.5, 35.0, 42.0, 55.0, 6.0]);
            testCase.verifyEqual(testCase.baseValue("IMB_PARAMS"),  [5.0, 7.5, 2.5, 1.5]);
        end

        function allParametersAreSetRegardlessOfFaultType(testCase)
            % The model reads all three vectors whichever fault is active, so
            % every one must exist after any call.
            evalc("set_fault('joint_imbalance', 2, 0.25)");
            for v = TestSetFault.Vars
                testCase.verifyTrue(logical(evalin("base", sprintf("exist('%s','var')", v))), ...
                    v + " was not set");
            end
        end

        function anUnknownFaultTypeIsRejected(testCase)
            % A typo must not quietly produce a healthy run.
            testCase.verifyError(@() set_fault('bearingg', 1, 0.5), ?MException);
        end

    end
end
