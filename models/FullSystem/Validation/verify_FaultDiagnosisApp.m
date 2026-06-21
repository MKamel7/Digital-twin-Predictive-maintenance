addpath('E:\Digital twin Predictive maintenance\Digital twin Predictive maintenance\models\FullSystem\Validation');

app = FaultDiagnosisApp();

fprintf('Initial: %s | %s | pred=%s match="%s" (charcode=%s)\n', ...
    app.ProgressLabel.Text, app.FileNameLabel.Text, app.ConditionValue.Text, ...
    app.MatchValue.Text, mat2str(double(app.MatchValue.Text)));

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
