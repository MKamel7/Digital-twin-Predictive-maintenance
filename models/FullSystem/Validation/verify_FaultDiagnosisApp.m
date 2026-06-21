addpath('E:\Digital twin Predictive maintenance\Digital twin Predictive maintenance\models\FullSystem\Validation');

app = FaultDiagnosisApp();

fprintf('Initial: %s | %s | pred=%s match="%s" (charcode=%s)\n', ...
    app.ProgressLabel.Text, app.FileNameLabel.Text, app.ConditionValue.Text, ...
    app.MatchValue.Text, mat2str(double(app.MatchValue.Text)));

% Item 4 (v2, two-stage split): confirm Stage 1 indicator + Stage 2
% 3-bar panel render, Stage 2 sums to ~1 (softmax within 3 only).
% ScoreBarHandle itself is private; access via the public ScorePanelAxes.
classNames3 = {'gear_wear','bearing','imbalance'};
fprintf('Stage1Value (file 1, healthy, expect HEALTHY with checkmark): %s\n', app.Stage1Value.Text);
scoreBar = app.ScorePanelAxes.Children;
fprintf('Stage 2 YData (file 1): %s (sum=%.4f, expect ~1)\n', ...
    mat2str(scoreBar.YData, 4), sum(scoreBar.YData));
fprintf('Stage 2 CData (file 1, expect all neutral/inactive since Stage1=healthy):\n'); disp(scoreBar.CData);

% Simulate pressing Play and letting the timer run through the whole 10-file sequence
app.PlayPauseButtonPushed();
fprintf('PlayPauseButton after Play: %s\n', app.PlayPauseButton.Text);

pause(60); % generous margin -- per-tick timing has been inconsistent across runs this session

fprintf('\nAfter playback: %s\n', app.ProgressLabel.Text);
fprintf('File: %s\n', app.FileNameLabel.Text);
fprintf('PlayPauseButton (expect "Play", auto-stopped at end): %s\n', app.PlayPauseButton.Text);
fprintf('StatusLabel: %s\n', app.StatusLabel.Text);
fprintf('Final ConditionValue="%s" TrueConditionValue="%s" MatchValue="%s" (charcode=%s) SeverityGauge=%g\n', ...
    app.ConditionValue.Text, app.TrueConditionValue.Text, app.MatchValue.Text, mat2str(double(app.MatchValue.Text)), app.SeverityGauge.Value);
fprintf('AccuracyLabel: %s\n', app.AccuracyLabel.Text);
fprintf('LastClassifiedLabel: %s\n', app.LastClassifiedLabel.Text);
fprintf('Confusion matrix (rows=true: healthy,gear_wear,bearing,imbalance; cols=predicted same order):\n');
disp(app.ConfusionTable.Data);
fprintf('Sum of all confusion matrix cells (expect 10 after full playback): %d\n', sum(app.ConfusionTable.Data(:)));

% Step from end should wrap to file 1, then walk the full 10-file sequence manually
app.StepButtonPushed();
fprintf('\nAfter Step from end (expect file 1, healthy): %s | %s\n', app.ProgressLabel.Text, app.FileNameLabel.Text);
fprintf('Confusion matrix sum after wrap (expect 1, confirms reset-on-replay, not stale accumulation): %d\n', ...
    sum(app.ConfusionTable.Data(:)));
fprintf('AccuracyLabel after wrap (expect 1/1 correct -- healthy): %s\n', app.AccuracyLabel.Text);

for k = 1:9
    app.StepButtonPushed();
    fprintf('After Step: %s | %s | true=%s pred=%s match="%s" (charcode=%s) severityGauge=%g\n', ...
        app.ProgressLabel.Text, app.FileNameLabel.Text, app.TrueConditionValue.Text, app.ConditionValue.Text, ...
        app.MatchValue.Text, mat2str(double(app.MatchValue.Text)), app.SeverityGauge.Value);
    if k == 1
        fprintf('  -> at the known sev1 miss: AccuracyLabel=%s (expect 1/2, confirms the miss is counted)\n', app.AccuracyLabel.Text);
        fprintf('  -> Stage1Value (expect FAULTY with checkmark -- stage1 correctly caught the fault): %s\n', app.Stage1Value.Text);
        scoreBarAtMiss = app.ScorePanelAxes.Children;
        scoresAtMiss = scoreBarAtMiss.YData;
        cdataAtMiss = scoreBarAtMiss.CData;
        fprintf('  -> PAYOFF MOMENT check (Stage 2, 3-way only): scores=%s (sum=%.4f)\n', mat2str(scoresAtMiss, 4), sum(scoresAtMiss));
        for ci = 1:3
            fprintf('       %-12s score=%.4f color=%s\n', classNames3{ci}, scoresAtMiss(ci), mat2str(cdataAtMiss(ci,:),3));
        end
        imbalanceIdx = find(strcmp(classNames3,'imbalance'));
        gearWearIdx = find(strcmp(classNames3,'gear_wear'));
        fprintf('  -> imbalance (predicted, wrong) score=%.4f, gear_wear (true, runner-up?) score=%.4f, gap=%.4f\n', ...
            scoresAtMiss(imbalanceIdx), scoresAtMiss(gearWearIdx), scoresAtMiss(imbalanceIdx)-scoresAtMiss(gearWearIdx));
    end
end

% Pause/resume button-state check
app.StepButtonPushed(); % wrap to file 1
app.PlayPauseButtonPushed(); % play
state1 = app.PlayPauseButton.Text;
pause(0.3);
app.PlayPauseButtonPushed(); % pause
state2 = app.PlayPauseButton.Text;
fprintf('\nButton text while playing: %s | after pause: %s (expect Pause/Play)\n', state1, state2);

delete(app);
fprintf('\nApp deleted cleanly.\n');
