classdef TestSimulinkModel < matlab.unittest.TestCase
    % Structural tests for the Simulink model, Robot_Phase1_PASS.
    %
    % These load the model and inspect it. They do not simulate it: a run is
    % 20 s of ode15s over a Simscape Multibody arm, which is minutes of CPU and
    % would make every push expensive for little added confidence.
    %
    % What they protect is the contract between the model and everything
    % downstream. build_feature_matrix reads out.logsout.getElement('delta_tau'),
    % so the name delta_tau is an interface, not a label. Renaming that signal
    % breaks the dataset build silently, at the point where the run is already
    % expensive to regenerate.
    %
    % Requires Simulink, Simscape and Simscape Multibody, so this class is run
    % by scripts/run_model_checks.m and is deliberately NOT in the default
    % public suite.

    properties (Constant)
        ModelName = "Robot_Phase1_PASS"
    end

    properties
        OldDir
    end

    methods (TestClassSetup)
        function loadTheModel(testCase)
            here = fileparts(mfilename("fullpath"));
            root = fileparts(here);
            modelDir = fullfile(root, "models", "FullSystem");

            testCase.OldDir = pwd;
            cd(modelDir);
            addpath(modelDir);
            testCase.addTeardown(@() cd(testCase.OldDir));

            % The model warns that it cannot reload its workspace from a data
            % source path on another machine. That is a real defect, recorded
            % in the README, but it does not stop the model loading.
            ws = warning("off", "all");
            testCase.addTeardown(@() warning(ws));

            load_system(testCase.ModelName);
            testCase.addTeardown(@() close_system(testCase.ModelName, 0));
        end
    end

    methods (Test)

        function theModelLoads(testCase)
            testCase.verifyTrue(bdIsLoaded(char(testCase.ModelName)));
        end

        function bothArmsArePresent(testCase)
            % The whole method is the difference between a physical arm and a
            % healthy virtual twin. If either subsystem is renamed or removed,
            % the residual has no meaning.
            subsystems = find_system(testCase.ModelName, "SearchDepth", 1, "BlockType", "SubSystem");
            names = string(subsystems);
            testCase.verifyTrue(any(endsWith(names, "/Physical_Arm")), "Physical_Arm subsystem missing");
            testCase.verifyTrue(any(endsWith(names, "/Virtual_Twin")), "Virtual_Twin subsystem missing");
        end

        function theDeltaTauSignalExists(testCase)
            % The interface build_feature_matrix depends on by name.
            lines = find_system(testCase.ModelName, "FindAll", "on", ...
                "LookUnderMasks", "all", "FollowLinks", "on", "Type", "line");
            names = get(lines, "Name");
            if ~iscell(names)
                names = {names};
            end
            names = string(names(~cellfun(@isempty, names)));
            testCase.verifyTrue(any(names == "delta_tau"), ...
                "no signal named delta_tau. build_feature_matrix reads " + ...
                "out.logsout.getElement('delta_tau'), so renaming it breaks the dataset build.");
        end

        function theModelWorkspaceLoadsItsParameters(testCase)
            % The model workspace is fed from GDOFrobot_DataFile.m, which
            % defines smiData: every link length, mass, inertia and joint
            % frame of the arm. An empty workspace means the model is not the
            % machine it claims to be.
            %
            % This is here because it was broken. The data source pointed at
            % an absolute path on another machine, the workspace loaded zero
            % variables, and nothing failed. The structural tests all passed.
            hws = get_param(char(testCase.ModelName), "ModelWorkspace");
            testCase.verifyGreaterThan(numel(hws.whos), 0, ...
                "the model workspace is empty, so the arm has no parameters");
            testCase.verifyTrue(hws.hasVariable("smiData"), ...
                "smiData missing: the Simscape Multibody parameters did not load");
        end

        function theWorkspaceSourceIsARelativePath(testCase)
            % An absolute path makes the model work on exactly one machine.
            % Keeping the filename relative lets it resolve beside the model
            % in any checkout.
            hws  = get_param(char(testCase.ModelName), "ModelWorkspace");
            name = string(hws.FileName);
            testCase.verifyFalse(contains(name, ":") || startsWith(name, "/") || startsWith(name, "\"), ...
                "the model workspace data source is an absolute path (" + name + ...
                "), so it will not resolve on another machine");
        end

        function solverConfigurationIsUnchanged(testCase)
            % A stiff Simscape multibody model. Swapping to a fixed-step or
            % non-stiff solver changes the residual that everything is
            % computed from, so the choice is pinned.
            cfg = getActiveConfigSet(char(testCase.ModelName));
            testCase.verifyEqual(string(get_param(cfg, "Solver")), "ode15s");
            testCase.verifyEqual(string(get_param(cfg, "StopTime")), "20");
        end

    end
end
