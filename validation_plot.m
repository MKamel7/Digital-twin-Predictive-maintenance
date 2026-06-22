function validation_plot(out, traj_q)
%VALIDATION_PLOT  Section 09 Phase 0 validation figure.
%   Generates 3x3 subplot (position tracking, torque, error) per joint
%   and exports to figures/phase0_validation.pdf

    % Extract signals
    bus = out.logsout.getElement('Robot_Sensors').Values;
    q_sim = [bus.Joint1_Signals.q.Data, ...
             bus.Joint2_Signals.q.Data, ...
             bus.Joint3_Signals.q.Data];
    tau   = [bus.Joint1_Signals.torque.Data, ...
             bus.Joint2_Signals.torque.Data, ...
             bus.Joint3_Signals.torque.Data];
    t     = bus.Joint1_Signals.q.Time;

    % Interpolate reference onto sim time
    t_min = max(t(1), traj_q(1,1));
    t_max = min(t(end), traj_q(end,1));
    mask  = (t >= t_min) & (t <= t_max);
    t_use = t(mask);

    qref = zeros(numel(t_use), 3);
    for j = 1:3
        qref(:,j) = interp1(traj_q(:,1), traj_q(:,j+1), t_use);
    end
    q_use   = q_sim(mask,:);
    tau_use = tau(mask,:);

    joints = {'Waist','Shoulder','Elbow'};
    colors = {'#4ade80','#60a5fa','#f59e0b'};

    fig = figure('Name','Phase 0 Validation', ...
                 'Position',[100 100 1200 800], ...
                 'Color','w');

    for j = 1:3
        % --- Position tracking ---
        subplot(3,3, j);
        plot(t_use, rad2deg(qref(:,j)), '--', 'Color',[0.5 0.5 0.5], ...
             'DisplayName','Ref','LineWidth',1.2);
        hold on;
        plot(t_use, rad2deg(q_use(:,j)), 'Color', colors{j}, ...
             'DisplayName','Actual','LineWidth',1.3);
        title([joints{j} ' — Angle (deg)']);
        xlabel('t (s)'); ylabel('deg');
        legend('Location','best'); grid on;

        % --- Torque ---
        subplot(3,3, j+3);
        plot(t_use, tau_use(:,j), 'Color', colors{j}, 'LineWidth', 1);
        title([joints{j} ' — Torque (Nm)']);
        xlabel('t (s)'); ylabel('Nm');
        grid on;

        % --- Tracking error ---
        subplot(3,3, j+6);
        err = rad2deg(qref(:,j) - q_use(:,j));
        plot(t_use, err, 'Color', colors{j}, 'LineWidth', 1);
        yline(0, '--k');
        rmse_deg = rad2deg(sqrt(mean((qref(:,j) - q_use(:,j)).^2)));
        title(sprintf('%s — Error (deg) | RMSE=%.3f', joints{j}, rmse_deg));
        xlabel('t (s)'); ylabel('deg');
        grid on;
    end

    sgtitle('Phase 0 — Controller Validation on 4-Segment Quintic Mission', ...
            'FontSize', 14, 'FontWeight', 'bold');

    if ~exist('figures','dir'); mkdir('figures'); end
    exportgraphics(fig, 'figures/phase0_validation.pdf', ...
                   'ContentType','vector','Resolution',300);
    fprintf('Exported: figures/phase0_validation.pdf\n');
end
