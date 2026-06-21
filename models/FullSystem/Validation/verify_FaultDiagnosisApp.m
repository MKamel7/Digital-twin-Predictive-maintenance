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
fprintf('Final ConditionValue="%s" MatchValue="%s" (charcode=%s) SeverityGauge=%g\n', ...
    app.ConditionValue.Text, app.MatchValue.Text, mat2str(double(app.MatchValue.Text)), app.SeverityGauge.Value);

% Step from end should wrap to file 1, then walk the full 10-file sequence manually
app.StepButtonPushed();
fprintf('\nAfter Step from end (expect file 1, healthy): %s | %s\n', app.ProgressLabel.Text, app.FileNameLabel.Text);

for k = 1:9
    app.StepButtonPushed();
    fprintf('After Step: %s | %s | pred=%s match="%s" (charcode=%s) severityGauge=%g\n', ...
        app.ProgressLabel.Text, app.FileNameLabel.Text, app.ConditionValue.Text, ...
        app.MatchValue.Text, mat2str(double(app.MatchValue.Text)), app.SeverityGauge.Value);
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
