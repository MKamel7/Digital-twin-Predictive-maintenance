addpath('E:\Digital twin Predictive maintenance\Digital twin Predictive maintenance\models\FullSystem\Validation');

app = FaultDiagnosisApp();

fprintf('Initial: %s | %s | pred=%s match="%s" (charcode=%s)\n', ...
    app.ProgressLabel.Text, app.FileNameLabel.Text, app.ConditionValue.Text, ...
    app.MatchValue.Text, mat2str(double(app.MatchValue.Text)));

% Simulate pressing Play and letting the timer run through the whole sequence
app.PlayPauseButtonPushed();
fprintf('PlayPauseButton after Play: %s\n', app.PlayPauseButton.Text);

pause(16); % generous margin -- UI rendering overhead per tick may push wall time past the naive period*N estimate

fprintf('\nAfter playback: %s\n', app.ProgressLabel.Text);
fprintf('File: %s\n', app.FileNameLabel.Text);
fprintf('PlayPauseButton (expect "Play", auto-stopped at end): %s\n', app.PlayPauseButton.Text);
fprintf('StatusLabel: %s\n', app.StatusLabel.Text);
fprintf('Final ConditionValue="%s" MatchValue="%s" (charcode=%s) SeverityGauge=%g\n', ...
    app.ConditionValue.Text, app.MatchValue.Text, mat2str(double(app.MatchValue.Text)), app.SeverityGauge.Value);

% Step from end should wrap to file 1
app.StepButtonPushed();
fprintf('\nAfter Step from end: %s | %s\n', app.ProgressLabel.Text, app.FileNameLabel.Text);

labels = {'(file1 healthy)','(file2 sev1 - known wobble case)','(file3 sev2)','(file4 sev3)'};
for k = 1:3
    app.StepButtonPushed();
    fprintf('After Step %s: %s | %s | pred=%s match="%s" (charcode=%s) severityGauge=%g\n', ...
        labels{k+1}, app.ProgressLabel.Text, app.FileNameLabel.Text, app.ConditionValue.Text, ...
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
