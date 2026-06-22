function plot_healthy_baseline(matfile)
%PLOT_HEALTHY_BASELINE  Visualize a saved baseline dataset.
%
% Usage:
%   plot_healthy_baseline                                    % picks latest file
%   plot_healthy_baseline('data/healthy/run_...mat')         % specific file

    if nargin < 1 || isempty(matfile)
        files = dir('data/healthy/*.mat');
        if isempty(files)
            error('No .mat files in data/healthy/');
        end
        [~, idx] = max([files.datenum]);
        matfile  = fullfile(files(idx).folder, files(idx).name);
    end

    S = load(matfile);
    data = S.data;
    t = data.time;

    names  = {'Waist','Shoulder','Elbow'};
    colors = {'#4ade80','#60a5fa','#f59e0b'};

    fig = figure('Name','Healthy Baseline', ...
                 'Position',[100 100 1200 900], 'Color','w');

    % --- Position ---
    subplot(4,1,1);
    for j = 1:3
        plot(t, rad2deg(data.q(:,j)), 'Color', colors{j}, ...
             'LineWidth', 1.3, 'DisplayName', names{j});
        hold on;
    end
    ylabel('angle (deg)'); grid on; legend('Location','eastoutside');
    title('Joint angles');

    % --- Velocity ---
    subplot(4,1,2);
    for j = 1:3
        plot(t, rad2deg(data.dq(:,j)), 'Color', colors{j}, ...
             'LineWidth', 1.3, 'DisplayName', names{j});
        hold on;
    end
    ylabel('rate (deg/s)'); grid on; legend('Location','eastoutside');
    title('Joint velocities');

    % --- Torque ---
    subplot(4,1,3);
    for j = 1:3
        plot(t, data.tau(:,j), 'Color', colors{j}, ...
             'LineWidth', 1.1, 'DisplayName', names{j});
        hold on;
    end
    ylabel('\tau (Nm)'); grid on; legend('Location','eastoutside');
    title('Joint torques');

    % --- Current ---
    subplot(4,1,4);
    for j = 1:3
        plot(t, data.current(:,j), 'Color', colors{j}, ...
             'LineWidth', 1.1, 'DisplayName', names{j});
        hold on;
    end
    ylabel('I (A)'); xlabel('t (s)'); grid on; legend('Location','eastoutside');
    title('Joint currents');

    sgtitle(sprintf('Healthy baseline: %s (%.2f s, %d samples)', ...
                    data.condition, t(end), numel(t)), ...
            'FontSize', 14, 'FontWeight', 'bold');
end
