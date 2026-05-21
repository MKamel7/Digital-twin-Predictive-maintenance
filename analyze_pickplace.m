% --- Extract simulation signals ---
bus = out.logsout.getElement('Robot_Sensors').Values;
q_sim = [bus.Joint1_Signals.q.Data, ...
         bus.Joint2_Signals.q.Data, ...
         bus.Joint3_Signals.q.Data];
t_sim = bus.Joint1_Signals.q.Time;

% Intersection window
t_min = max(t_sim(1),  traj_q(1,1));
t_max = min(t_sim(end), traj_q(end,1));
mask  = (t_sim >= t_min) & (t_sim <= t_max);

t_use = t_sim(mask);
q_use = q_sim(mask, :);

qref_interp = zeros(size(q_use));
for j = 1:3
    qref_interp(:,j) = interp1(traj_q(:,1), traj_q(:,j+1), t_use);
end

err      = q_use - qref_interp;
rmse_rad = sqrt(mean(err.^2, 1));
rmse_deg = rad2deg(rmse_rad);

fprintf('\n--- Trajectory tracking RMSE ---\n');
fprintf('  Joint 1 (Waist)   : %.3f deg\n', rmse_deg(1));
fprintf('  Joint 2 (Shoulder): %.3f deg\n', rmse_deg(2));
fprintf('  Joint 3 (Elbow)   : %.3f deg\n', rmse_deg(3));
fprintf('  Guide threshold   : 2.86 deg\n');
if all(rmse_rad < 0.05)
    fprintf('  PASS\n');
else
    fprintf('  One or more joints exceed threshold\n');
end

