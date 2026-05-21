function analyze_step(out, traj_q, j)
% Analyze step response for joint j (1=Waist, 2=Shoulder, 3=Elbow).
%
% Usage after each simulation:
%   analyze_step(out, traj_q, 1)   % waist
%   analyze_step(out, traj_q, 2)   % shoulder
%   analyze_step(out, traj_q, 3)   % elbow

    % --- Extract signals from bus ----------------------
    bus = out.logsout.getElement('Robot_Sensors').Values;
    js  = {bus.Joint1_Signals, bus.Joint2_Signals, bus.Joint3_Signals};

    q   = [js{1}.q.Data,      js{2}.q.Data,      js{3}.q.Data];
    tau = [js{1}.torque.Data, js{2}.torque.Data, js{3}.torque.Data];
    t   = js{1}.q.Time;

    % --- Build reference on same time grid -------------
    qref_col = traj_q(:, j+1);
    qref_i   = interp1(traj_q(:,1), qref_col, t);

	t_step   = 0.5;
	q_before = qref_i(1);              % actual initial reference
	q_after  = qref_i(end);            % final reference
	step     = q_after - q_before;

    post     = t >= t_step;
    t_post   = t(post);
    q_post   = q(post, j);
    err_post = q_after - q_post;

    if step > 0
        peak = max(q_post);
        over = 100 * max(0, peak - q_after) / step;
    else
        trough = min(q_post);
        over   = 100 * max(0, q_after - trough) / abs(step);
    end

    tol = 0.05 * abs(step);
    settled = false(size(t_post));
    for k = 1:numel(t_post)
        settled(k) = all(abs(err_post(k:end)) <= tol);
    end
    fs = find(settled, 1, 'first');
    tsettle = NaN;
    if ~isempty(fs)
        tsettle = t_post(fs) - t_step;
    end

    ss_mask = t_post > (t_post(end) - 0.2);
    ss_err  = rad2deg(mean(q_after - q_post(ss_mask)));
    peak_tau = max(abs(tau(post, j)));

    names = {'Waist','Shoulder','Elbow'};
    fprintf('--- Joint %d (%s) step response ---\n', j, names{j});
    fprintf('  Step size        : %.2f deg\n',  rad2deg(step));
    fprintf('  Overshoot        : %.2f %%\n',   over);
    fprintf('  Settling time    : %.3f s\n',    tsettle);
    fprintf('  Steady-state err : %.3f deg\n',  ss_err);
    fprintf('  Peak torque      : %.2f Nm\n',   peak_tau);

    % --- Plot -----------------------------------------
    figure('Name', sprintf('Joint %d step', j));
    subplot(2,1,1);
    plot(t, rad2deg(qref_i), '--k', 'LineWidth', 1.2); hold on;
    plot(t, rad2deg(q(:,j)), 'b', 'LineWidth', 1.5);
    xlabel('t (s)'); ylabel('angle (deg)');
    legend('Reference','Actual','Location','best'); grid on;
    title(sprintf('Joint %d (%s) — step response', j, names{j}));

    subplot(2,1,2);
    plot(t, tau(:,j), 'r', 'LineWidth', 1.2);
    xlabel('t (s)'); ylabel('torque (Nm)');
    yline([50 -50],'--k'); grid on;
    title('Joint torque');
end
