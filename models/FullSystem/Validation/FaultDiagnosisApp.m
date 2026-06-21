classdef FaultDiagnosisApp < matlab.apps.AppBase
    % FaultDiagnosisApp -- Automated Fault Diagnosis demo (SVM classifier,
    % held-out test data). No claim of real-time, RUL, remaining life, or
    % prognosis anywhere in this UI -- this is file-level diagnosis on
    % data the model never trained on, nothing more.
    %
    % Design discipline (per review):
    % - All predictions are precomputed BEFORE the timer starts. The
    %   timer callback ONLY updates the display; it never featurizes or
    %   calls predict(). This is what keeps the timer callback fast and
    %   non-blocking.
    % - Pause = stop(timer). Resume = start(timer). Step = run one
    %   display update manually while the timer is stopped. There is no
    %   "if paused, return" guard inside the callback -- the timer is
    %   either actually running or actually stopped.
    % - The entire timer callback body is wrapped in try/catch. An
    %   uncaught error inside an App Designer timer callback fails
    %   silently and freezes the GUI with no visible error -- this is
    %   exactly the failure mode to avoid.

    properties (Access = public)
        UIFigure            matlab.ui.Figure
        TitleLabel          matlab.ui.control.Label
        ConditionLabel      matlab.ui.control.Label
        ConditionValue      matlab.ui.control.Label
        ScoreLabel          matlab.ui.control.Label
        ScoreValue          matlab.ui.control.Label
        MatchLabel          matlab.ui.control.Label
        MatchValue          matlab.ui.control.Label
        SeverityGauge       matlab.ui.control.LinearGauge
        SeverityGaugeLabel  matlab.ui.control.Label
        TrueConditionLabel  matlab.ui.control.Label
        TrueConditionValue  matlab.ui.control.Label
        DeltaTauAxes        matlab.ui.control.UIAxes
        ProgressLabel       matlab.ui.control.Label
        FileNameLabel       matlab.ui.control.Label
        PlayPauseButton     matlab.ui.control.Button
        StepButton          matlab.ui.control.Button
        StatusLabel         matlab.ui.control.Label
        ConfusionLabel      matlab.ui.control.Label
        ConfusionTable      matlab.ui.control.Table
        AccuracyLabel       matlab.ui.control.Label
        LastClassifiedLabel matlab.ui.control.Label
    end

    properties (Access = private)
        Timer
        Results        % struct array, fully precomputed before timer starts
        CurrentIndex = 1
        IsPlaying = false
    end

    methods (Access = public)

        function precomputeResults(app)
            projectRoot = 'E:\Digital twin Predictive maintenance\Digital twin Predictive maintenance';
            datasetRoot = fullfile(projectRoot, 'data', 'phase2_dataset_v1');
            balancedRoot = fullfile(projectRoot, 'data', 'phase2_dataset_balanced_v1');
            reportFolder = fullfile(balancedRoot, 'validation_reports');

            modelFiles = dir(fullfile(reportFolder, 'svm_final_model_*.mat'));
            [~, idx] = max([modelFiles.datenum]);
            M = load(fullfile(modelFiles(idx).folder, modelFiles(idx).name), ...
                'result', 'stage1Model', 'stage2Model');
            featureVars = M.result.featureVars;
            mu = M.result.mu;
            sigma = M.result.sigma;

            % Demo sequence: healthy -> gear_wear/bearing/imbalance, each
            % sev1/sev2/sev3, all from held-out family 9 (split_family_
            % holdout == "test", never used in training), same trajectory
            % family/variant/joint throughout (f09/v01/j1) so only
            % condition+severity vary between files. gear_wear sev1 is
            % the known-hard case -- verified separately that this exact
            % file is misclassified as "imbalance" using the model's own
            % pre-computed features, so this arc includes a real,
            % pre-confirmed failure case, not a cherry-picked all-success
            % run.
            seq = struct( ...
                'fileName', { ...
                    'run_healthy_f09_v01_j0_s0_seed991000.mat', ...
                    'run_gear_wear_f09_v01_j1_s1_seed991111.mat', ...
                    'run_gear_wear_f09_v01_j1_s2_seed991112.mat', ...
                    'run_gear_wear_f09_v01_j1_s3_seed991113.mat', ...
                    'run_bearing_f09_v01_j1_s1_seed991211.mat', ...
                    'run_bearing_f09_v01_j1_s2_seed991212.mat', ...
                    'run_bearing_f09_v01_j1_s3_seed991213.mat', ...
                    'run_imbalance_f09_v01_j1_s1_seed991311.mat', ...
                    'run_imbalance_f09_v01_j1_s2_seed991312.mat', ...
                    'run_imbalance_f09_v01_j1_s3_seed991313.mat'}, ...
                'condition', { ...
                    'healthy', ...
                    'gear_wear','gear_wear','gear_wear', ...
                    'bearing','bearing','bearing', ...
                    'imbalance','imbalance','imbalance'}, ...
                'severity', {0, 1, 2, 3, 1, 2, 3, 1, 2, 3}, ...
                'jointId', {1, 1, 1, 1, 1, 1, 1, 1, 1, 1});

            results = struct('fileName',{},'trueCondition',{},'trueSeverity',{}, ...
                'predCondition',{},'score',{},'isMatch',{},'deltaTauMotor',{},'time',{});

            for k = 1:numel(seq)
                cond = seq(k).condition;
                fname = seq(k).fileName;
                if strcmp(cond, 'healthy')
                    folder = 'healthy';
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
                tTrim = data.time(idxTrim);

                featStruct = featurize_one_file(motor, sensed, fs);
                x = zeros(1, numel(featureVars));
                for i = 1:numel(featureVars)
                    x(i) = featStruct.(featureVars{i});
                end
                xz = (x - mu) ./ sigma;

                [p1, score1] = predict(M.stage1Model, xz);
                if p1 == "faulty"
                    [pred, score2] = predict(M.stage2Model, xz);
                    decisionScore = max(score2);
                else
                    pred = categorical("healthy");
                    decisionScore = max(score1);
                end

                results(k).fileName = fname;
                results(k).trueCondition = cond;
                results(k).trueSeverity = seq(k).severity;
                results(k).predCondition = string(pred);
                results(k).score = decisionScore;
                results(k).isMatch = string(pred) == cond;
                results(k).deltaTauMotor = motor(:, seq(k).jointId);
                results(k).time = tTrim;
            end

            app.Results = results;
        end

        function updateDisplay(app)
            r = app.Results(app.CurrentIndex);

            app.ConditionValue.Text = r.predCondition;
            if r.isMatch
                app.ConditionValue.FontColor = [0.1 0.6 0.1];
            else
                app.ConditionValue.FontColor = [0.75 0.1 0.1];
            end

            app.ScoreValue.Text = sprintf('%.3f', r.score);

            if r.isMatch
                app.MatchValue.Text = char(10003); % checkmark
                app.MatchValue.FontColor = [0.1 0.6 0.1];
            else
                app.MatchValue.Text = char(10007); % cross
                app.MatchValue.FontColor = [0.75 0.1 0.1];
            end

            app.SeverityGauge.Value = r.trueSeverity;
            app.TrueConditionValue.Text = sprintf('%s (severity %d)', r.trueCondition, r.trueSeverity);

            plot(app.DeltaTauAxes, r.time, r.deltaTauMotor, 'LineWidth', 1.2);
            title(app.DeltaTauAxes, sprintf('delta\\_tau\\_motor (J%d) -- true: %s', 1, r.trueCondition));
            xlabel(app.DeltaTauAxes, 'Time (s)');
            ylabel(app.DeltaTauAxes, 'Nm');
            grid(app.DeltaTauAxes, 'on');

            app.ProgressLabel.Text = sprintf('File %d of %d', app.CurrentIndex, numel(app.Results));
            app.FileNameLabel.Text = r.fileName;

            app.updateConfusionDisplay();
        end

        function updateConfusionDisplay(app)
            % Pure accumulation over already-precomputed predictions
            % (Results(1:CurrentIndex)) -- no new inference here. Derived
            % fresh from CurrentIndex every call (not an incremental
            % running counter), so it resets correctly for free whenever
            % CurrentIndex wraps back to 1 on replay -- no separate reset
            % logic to forget.
            classNames = {'healthy','gear_wear','bearing','imbalance'};
            n = app.CurrentIndex;
            confMat = zeros(4,4);
            nCorrect = 0;
            for i = 1:n
                ti = find(strcmp(classNames, app.Results(i).trueCondition));
                pi = find(strcmp(classNames, app.Results(i).predCondition));
                confMat(ti,pi) = confMat(ti,pi) + 1;
                if app.Results(i).isMatch
                    nCorrect = nCorrect + 1;
                end
            end

            app.ConfusionTable.Data = confMat;
            % "Demo sequence accuracy" labeled explicitly -- this is over
            % the n<=10 stitched files shown, NOT the model's headline
            % held-out test accuracy. Always shown as a raw fraction,
            % never a computed percentage, so "100%" can never appear
            % even when every file so far is correct.
            app.AccuracyLabel.Text = sprintf('Demo sequence accuracy: %d/%d correct', nCorrect, n);

            rCur = app.Results(n);
            app.LastClassifiedLabel.Text = sprintf('Last classified: true=%s, predicted=%s (row %d, col %d)', ...
                rCur.trueCondition, rCur.predCondition, ...
                find(strcmp(classNames, rCur.trueCondition)), ...
                find(strcmp(classNames, rCur.predCondition)));
        end

        function timerCallback(app, ~, ~)
            try
                if app.CurrentIndex < numel(app.Results)
                    app.CurrentIndex = app.CurrentIndex + 1;
                    app.updateDisplay();
                else
                    app.stopPlayback();
                    app.StatusLabel.Text = 'Sequence complete.';
                end
            catch ME
                app.StatusLabel.Text = ['Error: ' ME.message];
                app.stopPlayback();
            end
        end

        function stopPlayback(app)
            if ~isempty(app.Timer) && isvalid(app.Timer) && strcmp(app.Timer.Running, 'on')
                stop(app.Timer);
            end
            app.IsPlaying = false;
            app.PlayPauseButton.Text = 'Play';
        end

        function startPlayback(app)
            if ~isempty(app.Timer) && isvalid(app.Timer) && strcmp(app.Timer.Running, 'off')
                start(app.Timer);
            end
            app.IsPlaying = true;
            app.PlayPauseButton.Text = 'Pause';
        end

        function PlayPauseButtonPushed(app, ~)
            if app.IsPlaying
                app.stopPlayback();
            else
                if app.CurrentIndex >= numel(app.Results)
                    app.CurrentIndex = 1;
                    app.updateDisplay();
                end
                app.startPlayback();
            end
        end

        function StepButtonPushed(app, ~)
            app.stopPlayback();
            if app.CurrentIndex < numel(app.Results)
                app.CurrentIndex = app.CurrentIndex + 1;
            else
                app.CurrentIndex = 1;
            end
            app.updateDisplay();
        end

        function UIFigureCloseRequest(app, ~)
            if ~isempty(app.Timer) && isvalid(app.Timer)
                stop(app.Timer);
                delete(app.Timer);
            end
            delete(app.UIFigure);
        end

        function createComponents(app)
            app.UIFigure = uifigure('Name', 'Fault Diagnosis Demo', 'Position', [100 100 760 860]);
            app.UIFigure.CloseRequestFcn = @(~,~) app.UIFigureCloseRequest();

            app.TitleLabel = uilabel(app.UIFigure, ...
                'Text', 'Automated Fault Diagnosis -- SVM Classifier (held-out test data)', ...
                'FontSize', 16, 'FontWeight', 'bold', ...
                'Position', [20 810 720 30]);

            app.ConditionLabel = uilabel(app.UIFigure, 'Text', 'Predicted condition:', ...
                'FontSize', 13, 'Position', [20 765 160 25]);
            app.ConditionValue = uilabel(app.UIFigure, 'Text', '-', ...
                'FontSize', 22, 'FontWeight', 'bold', 'Position', [190 758 220 35]);

            app.MatchLabel = uilabel(app.UIFigure, 'Text', 'Prediction correct?', ...
                'FontSize', 13, 'Position', [430 765 150 25]);
            app.MatchValue = uilabel(app.UIFigure, 'Text', '-', ...
                'FontSize', 22, 'FontWeight', 'bold', 'Position', [590 758 60 35]);

            app.TrueConditionLabel = uilabel(app.UIFigure, 'Text', 'True condition (known label):', ...
                'FontSize', 13, 'Position', [20 700 220 25]);
            app.TrueConditionValue = uilabel(app.UIFigure, 'Text', '-', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', [0.2 0.2 0.2], ...
                'Position', [250 695 250 30]);

            app.ScoreLabel = uilabel(app.UIFigure, 'Text', 'Decision score (SVM margin, not a calibrated probability):', ...
                'FontSize', 11, 'Position', [20 730 420 22]);
            app.ScoreValue = uilabel(app.UIFigure, 'Text', '-', ...
                'FontSize', 13, 'FontWeight', 'bold', 'Position', [450 730 100 22]);

            app.SeverityGaugeLabel = uilabel(app.UIFigure, 'Text', 'Ground-truth severity (not predicted -- known label)', ...
                'FontSize', 11, 'Position', [560 680 180 35], 'WordWrap', 'on');
            app.SeverityGauge = uigauge(app.UIFigure, 'linear', ...
                'Limits', [0 3], 'Position', [580 600 60 80]);

            app.DeltaTauAxes = uiaxes(app.UIFigure, 'Position', [20 440 540 270]);

            app.ProgressLabel = uilabel(app.UIFigure, 'Text', 'File 0 of 0', ...
                'FontSize', 12, 'Position', [20 400 150 22]);
            app.FileNameLabel = uilabel(app.UIFigure, 'Text', '', ...
                'FontSize', 10, 'FontColor', [0.4 0.4 0.4], 'Position', [180 400 500 22]);

            app.PlayPauseButton = uibutton(app.UIFigure, 'Text', 'Play', ...
                'Position', [20 350 100 35], 'ButtonPushedFcn', @(~,~) app.PlayPauseButtonPushed());
            app.StepButton = uibutton(app.UIFigure, 'Text', 'Step', ...
                'Position', [140 350 100 35], 'ButtonPushedFcn', @(~,~) app.StepButtonPushed());

            app.StatusLabel = uilabel(app.UIFigure, 'Text', '', ...
                'FontSize', 11, 'FontColor', [0.5 0.1 0.1], 'Position', [20 310 700 25]);

            % --- Item 2: live confusion matrix + running accuracy ---
            app.ConfusionLabel = uilabel(app.UIFigure, ...
                'Text', 'Confusion matrix accumulated over this demo sequence (rows = true, columns = predicted):', ...
                'FontSize', 11, 'FontWeight', 'bold', 'Position', [20 270 700 22]);
            app.ConfusionTable = uitable(app.UIFigure, ...
                'Position', [20 90 400 175], ...
                'ColumnName', {'healthy','gear_wear','bearing','imbalance'}, ...
                'RowName', {'healthy','gear_wear','bearing','imbalance'}, ...
                'Data', zeros(4,4));
            app.AccuracyLabel = uilabel(app.UIFigure, 'Text', 'Demo sequence accuracy: 0/0 correct', ...
                'FontSize', 13, 'FontWeight', 'bold', 'Position', [440 220 300 25]);
            app.LastClassifiedLabel = uilabel(app.UIFigure, 'Text', '', ...
                'FontSize', 11, 'Position', [440 190 300 25], 'WordWrap', 'on');
        end
    end

    methods (Access = public)
        function app = FaultDiagnosisApp
            createComponents(app);
            precomputeResults(app);

            app.Timer = timer('ExecutionMode', 'fixedRate', 'Period', 2, ...
                'StartDelay', 1, 'TimerFcn', @(~,~) app.timerCallback());

            app.CurrentIndex = 1;
            updateDisplay(app);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.Timer) && isvalid(app.Timer)
                stop(app.Timer);
                delete(app.Timer);
            end
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end
