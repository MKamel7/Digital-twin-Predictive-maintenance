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
        PredictionPanel     matlab.ui.container.Panel
        GroundTruthPanel    matlab.ui.container.Panel
        SignalPanel         matlab.ui.container.Panel
        StagesPanel         matlab.ui.container.Panel
        ControlPanel        matlab.ui.container.Panel
        ConfusionPanel      matlab.ui.container.Panel
        MetricsPanel        matlab.ui.container.Panel
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
        MetricsNoteLabel    matlab.ui.control.Label
        ScorePanelLabel     matlab.ui.control.Label
        ScorePanelAxes      matlab.ui.control.UIAxes
        Stage1Label         matlab.ui.control.Label
        Stage1Value         matlab.ui.control.Label
        BarLegendLabel      matlab.ui.control.Label
    end

    properties (Access = private)
        Timer
        Results        % struct array, fully precomputed before timer starts
        CurrentIndex = 1
        IsPlaying = false
        ScoreBarHandle % Bar object, created once, updated via set() thereafter
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
                'predCondition',{},'score',{},'isMatch',{},'deltaTauMotor',{},'time',{}, ...
                'stage1Verdict',{},'stage1Correct',{},'stage2Scores3',{},'stage2PredCondition',{});

            % Stage 2's three fault classes, fixed display order (not
            % combined with "healthy" -- stage1 and stage2 are different
            % decision functions on different axes, displayed separately
            % rather than mixed into one illegitimate softmax).
            classNames3 = ["gear_wear","bearing","imbalance"];
            stage2Classes = string(M.stage2Model.ClassNames);

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
                % Always also query stage2, even when stage1 says
                % "healthy" -- this does not change which class WINS
                % (still follows the two-stage decision below); it only
                % gets the fault-type scores for the Stage 2 panel.
                % Querying an already-trained model's decision function
                % an extra time for display is not retraining/new data.
                [pred2, negLoss2] = predict(M.stage2Model, xz);

                if p1 == "faulty"
                    pred = pred2;
                    decisionScore = max(negLoss2);
                else
                    pred = categorical("healthy");
                    decisionScore = max(score1);
                end

                % Two-stage display split -- NOT combined into one
                % softmax. Stage 1's healthy-vs-faulty margin and Stage
                % 2's among-faults NegLoss are different decision
                % functions on different axes; mixing them previously
                % made "healthy" look misleadingly competitive against
                % gear_wear even on files stage1 correctly called
                % faulty. Displaying them separately removes that
                % artifact rather than tuning around it.
                stage1Verdict = string(p1);
                trueIsHealthy = strcmp(cond, 'healthy');
                stage1Correct = (stage1Verdict == "healthy") == trueIsHealthy;

                % Stage 2: softmax within the 3 fault classes only --
                % single decision function, legitimate normalization.
                scores3 = zeros(1,3);
                for c = 1:3
                    idx2 = find(stage2Classes == classNames3(c));
                    scores3(c) = negLoss2(idx2);
                end
                ex = exp(scores3 - max(scores3));
                stage2Scores3 = ex / sum(ex);

                results(k).fileName = fname;
                results(k).trueCondition = cond;
                results(k).trueSeverity = seq(k).severity;
                results(k).predCondition = string(pred);
                results(k).score = decisionScore;
                results(k).isMatch = string(pred) == cond;
                results(k).deltaTauMotor = motor(:, seq(k).jointId);
                results(k).time = tTrim;
                results(k).stage1Verdict = stage1Verdict;
                results(k).stage1Correct = stage1Correct;
                results(k).stage2Scores3 = stage2Scores3;
                results(k).stage2PredCondition = string(pred2);
            end

            app.Results = results;
        end

        function updateDisplay(app)
            r = app.Results(app.CurrentIndex);

            % Dark-mode status colors -- brightened so green/red read
            % clearly against the dark panel background.
            cGood = [0.35 0.85 0.45];
            cBad  = [0.98 0.45 0.45];
            cInk  = [0.93 0.95 0.98];

            app.ConditionValue.Text = r.predCondition;
            if r.isMatch
                app.ConditionValue.FontColor = cGood;
            else
                app.ConditionValue.FontColor = cBad;
            end

            app.ScoreValue.Text = sprintf('%.3f', r.score);

            if r.isMatch
                app.MatchValue.Text = char(10003); % checkmark
                app.MatchValue.FontColor = cGood;
            else
                app.MatchValue.Text = char(10007); % cross
                app.MatchValue.FontColor = cBad;
            end

            app.SeverityGauge.Value = r.trueSeverity;
            app.TrueConditionValue.Text = sprintf('%s (severity %d)', r.trueCondition, r.trueSeverity);

            plot(app.DeltaTauAxes, r.time, r.deltaTauMotor, 'LineWidth', 1.4, 'Color', [0.30 0.72 1.00]);
            title(app.DeltaTauAxes, sprintf('delta\\_tau\\_motor (J%d) -- true: %s', 1, r.trueCondition), 'Color', cInk);
            xlabel(app.DeltaTauAxes, 'Time (s)', 'Color', cInk);
            ylabel(app.DeltaTauAxes, 'Nm', 'Color', cInk);
            grid(app.DeltaTauAxes, 'on');
            app.DeltaTauAxes.GridAlpha = 0.28;
            % Tight on time, but pad the y-range so the signal's top/bottom
            % peaks are not flush against the axis frame (which read as
            % "clipped"). Pad by 12% of the signal span.
            xlim(app.DeltaTauAxes, [min(r.time) max(r.time)]);
            ylo = min(r.deltaTauMotor); yhi = max(r.deltaTauMotor);
            yPad = 0.12 * max(yhi - ylo, eps);
            ylim(app.DeltaTauAxes, [ylo - yPad, yhi + yPad]);

            app.ProgressLabel.Text = sprintf('File %d of %d', app.CurrentIndex, numel(app.Results));
            app.FileNameLabel.Text = r.fileName;

            app.updateConfusionDisplay();
            app.updateScorePanel();
        end

        function updateScorePanel(app)
            % Item 4 (v2, two-stage split): pure display update over
            % already-precomputed Stage1/Stage2 results -- no new
            % inference. set()-only update of the existing Bar handle.
            % Stage 1 and Stage 2 are shown separately because they are
            % different decision functions on different axes; combining
            % them into one softmax previously made "healthy" look
            % misleadingly competitive against gear_wear even on files
            % Stage 1 correctly called faulty.
            r = app.Results(app.CurrentIndex);

            % --- Stage 1 indicator ---
            if r.stage1Correct
                stage1Mark = char(10003); % checkmark
            else
                stage1Mark = char(10007); % cross
            end
            app.Stage1Value.Text = sprintf('%s %s', upper(r.stage1Verdict), stage1Mark);
            if r.stage1Correct
                app.Stage1Value.FontColor = [0.35 0.85 0.45];
            else
                app.Stage1Value.FontColor = [0.98 0.45 0.45];
            end

            % --- Stage 2: 3-bar panel (gear_wear/bearing/imbalance only) ---
            classNames3 = {'gear_wear','bearing','imbalance'};
            scores3 = r.stage2Scores3;
            stage2WinIdx = find(strcmp(classNames3, r.stage2PredCondition));
            [~, sortOrd] = sort(scores3, 'descend');
            if sortOrd(1) == stage2WinIdx
                secondIdx = sortOrd(2);
            else
                secondIdx = sortOrd(1);
            end

            % Dark-mode bar palette -- chosen for contrast against the
            % dark axes. Legend in the Stages panel states the mapping:
            % blue = chosen fault (correct), red = chosen (wrong),
            % light grey = runner-up.
            colorDefault = [0.40 0.42 0.48];
            colorSecond  = [0.66 0.70 0.78];
            colorWin     = [0.30 0.66 0.98];
            colorWinMiss = [0.98 0.42 0.42];
            colorInactive = [0.52 0.54 0.60]; % Stage 1 said healthy -- Stage 2's pick was never the actual output

            cdata = repmat(colorDefault, 3, 1);
            cdata(secondIdx, :) = colorSecond;
            if r.stage1Verdict == "faulty"
                % Stage 2's winner WAS the actual prediction's tiebreaker.
                if r.isMatch
                    cdata(stage2WinIdx, :) = colorWin;
                else
                    cdata(stage2WinIdx, :) = colorWinMiss;
                end
            else
                % Stage 1 said healthy -- Stage 2 never determined the
                % output. Show its top pick neutrally, not as a win/miss.
                cdata(stage2WinIdx, :) = colorInactive;
            end

            set(app.ScoreBarHandle, 'YData', scores3, 'CData', cdata);
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
            % Layout/visual pass only (now dark-themed) -- every
            % component property name, the precomputed-results contract,
            % the two-stage display split, and the verify-script access
            % points are preserved. Components are grouped into titled
            % panels; positions are relative to each panel. No prediction
            % logic or integrity semantics changed.
            figBG       = [0.11 0.12 0.15];   % near-black slate background
            panelBG     = [0.17 0.18 0.22];   % card background
            panelBorder = [0.30 0.32 0.40];
            accent      = [0.34 0.70 1.00];   % bright blue for dark bg
            txtPri      = [0.93 0.95 0.98];   % primary text
            txtSec      = [0.74 0.78 0.85];   % secondary text -- still high contrast
            axBG        = [0.09 0.10 0.13];   % plot area background
            axLine      = [0.78 0.81 0.87];   % axis ticks/labels

            % Built at full design size with Visible='off' so the whole
            % layout is assembled (and the first frame drawn) before the
            % window is shown -- prevents the "compress then expand"
            % flicker of laying out on an already-visible figure. The
            % constructor then explicitly scales every component to fit
            % the actual screen (fitToScreen) and flips Visible='on'.
            % AutoResizeChildren/Resize are 'off' so MATLAB does not
            % fight our manual scaling; without this the top panels
            % (incl. the severity bar) were being clipped off a window
            % that was taller than the screen.
            % Compact landscape design (940 x 648) that fits within a
            % typical 720p / display-scaled work area NATIVELY, so
            % fitToScreen's scale factor is ~1.0 and nothing (notably the
            % uitable) has to shrink into scrollbars.
            app.UIFigure = uifigure('Name', 'Fault Diagnosis Demo', ...
                'Position', [80 40 940 648], 'Color', figBG, 'Visible', 'off', ...
                'AutoResizeChildren', 'off', 'Resize', 'off');
            app.UIFigure.CloseRequestFcn = @(~,~) app.UIFigureCloseRequest();

            app.TitleLabel = uilabel(app.UIFigure, ...
                'Text', 'Automated Fault Diagnosis  --  SVM Classifier (held-out test data)', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', txtPri, ...
                'Position', [20 592 900 24]);

            panelArgs = {'BackgroundColor', panelBG, 'FontWeight', 'bold', ...
                         'FontSize', 11, 'ForegroundColor', accent, ...
                         'BorderColor', panelBorder};

            % ===================== PREDICTION (model output) ===========
            app.PredictionPanel = uipanel(app.UIFigure, panelArgs{:}, ...
                'Title', 'PREDICTION  (model output)', 'Position', [20 480 448 104]);

            app.ConditionLabel = uilabel(app.PredictionPanel, 'Text', 'Predicted condition', ...
                'FontSize', 11, 'FontColor', txtSec, 'Position', [14 58 170 16]);
            app.ConditionValue = uilabel(app.PredictionPanel, 'Text', '-', ...
                'FontSize', 22, 'FontWeight', 'bold', 'FontColor', txtPri, 'Position', [14 24 260 32]);

            app.MatchLabel = uilabel(app.PredictionPanel, 'Text', 'Prediction correct?', ...
                'FontSize', 10, 'FontColor', txtSec, 'Position', [288 60 150 16]);
            app.MatchValue = uilabel(app.PredictionPanel, 'Text', '-', ...
                'FontSize', 24, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                'FontColor', txtPri, 'Position', [330 22 90 34]);

            app.ScoreLabel = uilabel(app.PredictionPanel, ...
                'Text', 'Decision score (SVM margin -- not a calibrated probability):', ...
                'FontSize', 8.5, 'FontColor', txtSec, 'Position', [14 5 300 16]);
            app.ScoreValue = uilabel(app.PredictionPanel, 'Text', '-', ...
                'FontSize', 11, 'FontWeight', 'bold', 'FontColor', txtPri, 'Position', [318 5 120 16]);

            % ===================== GROUND TRUTH (known label) ==========
            app.GroundTruthPanel = uipanel(app.UIFigure, panelArgs{:}, ...
                'Title', 'GROUND TRUTH  (known label, not predicted)', 'Position', [478 480 442 104]);

            app.TrueConditionLabel = uilabel(app.GroundTruthPanel, 'Text', 'Condition', ...
                'FontSize', 11, 'FontColor', txtSec, 'Position', [14 62 90 16]);
            app.TrueConditionValue = uilabel(app.GroundTruthPanel, 'Text', '-', ...
                'FontSize', 15, 'FontWeight', 'bold', 'FontColor', txtPri, ...
                'Position', [104 60 330 20]);

            app.SeverityGaugeLabel = uilabel(app.GroundTruthPanel, ...
                'Text', 'Ground-truth severity (0 = healthy ... 3 = severe):', ...
                'FontSize', 9, 'FontColor', txtSec, 'Position', [14 38 414 14]);
            app.SeverityGauge = uigauge(app.GroundTruthPanel, 'linear', ...
                'Limits', [0 3], 'Position', [14 6 414 30], ...
                'ScaleColors', {[0.25 0.75 0.35], [0.96 0.82 0.25], [0.97 0.58 0.18], [0.95 0.30 0.30]}, ...
                'ScaleColorLimits', [0 0.75; 0.75 1.5; 1.5 2.25; 2.25 3]);

            % ===================== SIGNAL ==============================
            app.SignalPanel = uipanel(app.UIFigure, panelArgs{:}, ...
                'Title', 'Residual torque signal  (delta\_tau\_motor)', 'Position', [20 250 588 222]);
            % Axes sits lower in the panel with headroom below the panel
            % title; ylim padding (in updateDisplay) keeps the signal's
            % top peak off the frame.
            app.DeltaTauAxes = uiaxes(app.SignalPanel, 'Position', [16 12 556 176]);
            app.styleAxesDark(app.DeltaTauAxes, axBG, axLine);

            % ===================== CLASSIFIER STAGES ===================
            % Item 4 (v2, two-stage split): Stage 1 (healthy vs faulty)
            % shown as its own indicator -- NOT mixed into a combined
            % softmax with Stage 2, since the two are different decision
            % functions on different axes. Stage 2's 3-bar panel
            % (gear_wear/bearing/imbalance only) is created ONCE here
            % with placeholder data; updateDisplay reuses this same Bar
            % handle via set(...,'YData','CData') -- never replot().
            app.StagesPanel = uipanel(app.UIFigure, panelArgs{:}, ...
                'Title', 'Classifier stages  (shown separately)', 'Position', [618 250 302 222]);

            app.Stage1Label = uilabel(app.StagesPanel, 'Text', 'Stage 1 -- healthy vs faulty', ...
                'FontSize', 10, 'FontColor', txtSec, 'Position', [14 182 275 14]);
            app.Stage1Value = uilabel(app.StagesPanel, 'Text', '-', ...
                'FontSize', 15, 'FontWeight', 'bold', 'FontColor', txtPri, 'Position', [14 158 275 22]);

            app.ScorePanelLabel = uilabel(app.StagesPanel, ...
                'Text', ['Stage 2 -- fault type only. Softmax within these 3 (relative confidence, ', ...
                         'not a calibrated probability; meaningful only when Stage 1 = faulty).'], ...
                'FontSize', 8.5, 'FontColor', txtSec, 'Position', [14 116 280 40], 'WordWrap', 'on');
            app.ScorePanelAxes = uiaxes(app.StagesPanel, 'Position', [10 26 285 88]);
            app.ScoreBarHandle = barh(app.ScorePanelAxes, 1:3, zeros(1,3), 'FaceColor', 'flat');
            app.ScorePanelAxes.YTick = 1:3;
            app.ScorePanelAxes.YTickLabel = {'gear\_wear','bearing','imbalance'};
            app.ScorePanelAxes.XLim = [0 1];
            app.ScorePanelAxes.FontSize = 8;
            app.styleAxesDark(app.ScorePanelAxes, axBG, axLine);
            xlabel(app.ScorePanelAxes, 'relative confidence', 'Color', axLine);

            app.BarLegendLabel = uilabel(app.StagesPanel, ...
                'Text', 'Bar color:  blue = chosen fault (correct)   red = chosen (wrong)   grey = runner-up', ...
                'FontSize', 7.5, 'FontColor', txtSec, 'Position', [14 2 280 26], 'WordWrap', 'on');

            % ===================== PLAYBACK CONTROLS ===================
            app.ControlPanel = uipanel(app.UIFigure, panelArgs{:}, ...
                'Title', 'Playback', 'Position', [20 188 900 56]);

            btnBG = [0.24 0.40 0.62];
            app.PlayPauseButton = uibutton(app.ControlPanel, 'Text', 'Play', ...
                'FontSize', 12, 'FontWeight', 'bold', 'FontColor', txtPri, 'BackgroundColor', btnBG, ...
                'Position', [14 6 92 26], 'ButtonPushedFcn', @(~,~) app.PlayPauseButtonPushed());
            app.StepButton = uibutton(app.ControlPanel, 'Text', 'Step', ...
                'FontSize', 12, 'FontColor', txtPri, 'BackgroundColor', [0.28 0.30 0.37], ...
                'Position', [114 6 92 26], 'ButtonPushedFcn', @(~,~) app.StepButtonPushed());

            app.ProgressLabel = uilabel(app.ControlPanel, 'Text', 'File 0 of 0', ...
                'FontSize', 11, 'FontWeight', 'bold', 'FontColor', txtPri, 'Position', [222 19 170 16]);
            app.FileNameLabel = uilabel(app.ControlPanel, 'Text', '', ...
                'FontSize', 9, 'FontColor', txtSec, 'Position', [222 4 660 14]);
            app.StatusLabel = uilabel(app.ControlPanel, 'Text', '', ...
                'FontSize', 10, 'FontColor', [0.98 0.62 0.55], 'Position', [410 19 470 16]);

            % --- Item 2: live confusion matrix + running accuracy ---
            app.ConfusionPanel = uipanel(app.UIFigure, panelArgs{:}, ...
                'Title', 'Confusion matrix -- this demo sequence (rows = true, columns = predicted)', ...
                'Position', [20 14 568 168]);
            app.ConfusionLabel = uilabel(app.ConfusionPanel, ...
                'Text', 'Counts accumulate as the sequence plays; resets to zero on replay.', ...
                'FontSize', 9, 'FontColor', txtSec, 'Position', [12 126 544 14]);
            app.ConfusionTable = uitable(app.ConfusionPanel, ...
                'Position', [12 8 458 116], ...
                'ColumnName', {'healthy','gear_wear','bearing','imbalance'}, ...
                'RowName', {'healthy','gear_wear','bearing','imbalance'}, ...
                'ColumnWidth', {94, 94, 94, 94}, ...
                'ColumnFormat', {'numeric','numeric','numeric','numeric'}, ...
                'BackgroundColor', [0.15 0.16 0.20; 0.19 0.20 0.25], ...
                'ForegroundColor', txtPri, 'FontSize', 10, ...
                'Data', zeros(4,4));

            app.MetricsPanel = uipanel(app.UIFigure, panelArgs{:}, ...
                'Title', 'Demo metrics', 'Position', [598 14 322 168]);
            app.AccuracyLabel = uilabel(app.MetricsPanel, 'Text', 'Demo sequence accuracy: 0/0 correct', ...
                'FontSize', 12, 'FontWeight', 'bold', 'FontColor', txtPri, ...
                'Position', [14 118 294 22]);
            app.LastClassifiedLabel = uilabel(app.MetricsPanel, 'Text', '', ...
                'FontSize', 10, 'FontColor', [0.86 0.89 0.94], 'Position', [14 58 294 56], 'WordWrap', 'on');
            app.MetricsNoteLabel = uilabel(app.MetricsPanel, ...
                'Text', ['Note: this accuracy is over the <=10 files shown here, not the model''s ', ...
                         'headline held-out test accuracy. Shown as a raw fraction by design.'], ...
                'FontSize', 8.5, 'FontColor', txtSec, 'Position', [14 6 294 48], 'WordWrap', 'on');
        end

        function styleAxesDark(~, ax, axBG, axLine)
            % Apply a consistent dark theme to a uiaxes: dark plot area,
            % light ticks/grid. Persists across plot()/barh() updates
            % (which replace child graphics objects, not axes appearance).
            ax.Color = axBG;
            ax.XColor = axLine;
            ax.YColor = axLine;
            ax.GridColor = [0.60 0.63 0.70];
            ax.Box = 'on';
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

            % Fit the window to the available screen BEFORE showing it,
            % so no panel is clipped on smaller / display-scaled screens
            % (this is what was hiding the GROUND TRUTH / severity panel
            % at the top). AutoResizeChildren scales every panel to the
            % fitted size, so the full layout stays visible and the
            % window is revealed in one step (no flicker).
            app.fitToScreen();
            drawnow;
            app.UIFigure.Visible = 'on';

            if nargout == 0
                clear app
            end
        end

        function fitToScreen(app)
            % Uniformly scale the whole UI (positions AND font sizes) by
            % a single factor so it fits the available screen, then size
            % and centre the window to match. A uniform factor keeps the
            % design proportions intact -- the layout just gets smaller
            % on smaller / display-scaled screens, and stays full size
            % when there is room. Done manually because uifigure
            % AutoResizeChildren does not rescale absolutely-positioned
            % children on a programmatic resize.
            designW = 940; designH = 648;
            ss = get(groot, 'ScreenSize');   % [x y width height]
            s = min([1, (ss(3) - 40) / designW, (ss(4) - 80) / designH]);
            if s < 1
                app.scaleContainer(app.UIFigure, s);
            end
            figW = round(designW * s);
            figH = round(designH * s);
            x = max(10, round((ss(3) - figW) / 2));
            y = max(30, ss(4) - figH - 50);  % near top, leaving room for the title bar
            app.UIFigure.Position = [x y figW figH];
        end

        function scaleContainer(app, parent, s)
            % Recursively scale Position and FontSize of every descendant
            % by s. Panel children are positioned relative to the panel,
            % so scaling the panel size and its children by the same s
            % preserves the nested layout exactly.
            kids = allchild(parent);
            for i = 1:numel(kids)
                c = kids(i);
                if isprop(c, 'Position') && isnumeric(c.Position) && numel(c.Position) == 4
                    c.Position = c.Position * s;
                end
                if isprop(c, 'FontSize')
                    try
                        c.FontSize = max(6, c.FontSize * s);
                    catch
                    end
                end
                % Table column widths are fixed pixels -- scale them too,
                % otherwise the table grows scrollbars when the widget
                % shrinks but the columns do not.
                if isa(c, 'matlab.ui.control.Table') && iscell(c.ColumnWidth)
                    cw = c.ColumnWidth;
                    for j = 1:numel(cw)
                        if isnumeric(cw{j})
                            cw{j} = cw{j} * s;
                        end
                    end
                    c.ColumnWidth = cw;
                end
                if isa(c, 'matlab.ui.container.Panel')
                    app.scaleContainer(c, s);
                end
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
