% =========================================================
%  GENERATE_TRAJECTORY.M
%  Quintic trajectory generator — 4 segments, 3 joints
%  Run this BEFORE starting Simulink simulation
% =========================================================

clear traj_q traj_dq traj_ddq   % clear old workspace variables

%% ── Parameters ──────────────────────────────────────────
dt = 0.001;          % 1 ms timestep — MUST match Simulink fixed step
T  = 5;              % duration per segment (seconds)
t_seg = (0:dt:T)';   % time vector for one segment (5001×1)
N  = length(t_seg);  % number of samples per segment (5001)

%% ── Segment Definitions (radians) ───────────────────────
%        Joint1    Joint2    Joint3
q0_1 = [ 0,        -pi/4,    -pi/4  ];   % Home
qf_1 = [ pi/3,     -pi/3,    -pi/3  ];   % Pick

q0_2 = [ pi/3,     -pi/3,    -pi/3  ];   % Pick
qf_2 = [ pi/6,     -pi/2,    -pi/6  ];   % Place

q0_3 = [ pi/6,     -pi/2,    -pi/6  ];   % Place
qf_3 = [ 0,        -pi/4,    -pi/4  ];   % Home

q0_4 = [ 0,        -pi/4,    -pi/4  ];   % Home
qf_4 = [-pi/3,     -pi/6,    -pi/2  ];   % Inspect

q0s = [q0_1; q0_2; q0_3; q0_4];   % 4×3
qfs = [qf_1; qf_2; qf_3; qf_4];   % 4×3
NUM_SEGS = 4;

%% ── Pre-allocate ─────────────────────────────────────────
total_N  = NUM_SEGS * N;
q_ref    = zeros(total_N, 3);
dq_ref   = zeros(total_N, 3);
ddq_ref  = zeros(total_N, 3);

%% ── Generate All Segments ────────────────────────────────
for seg = 1:NUM_SEGS
    idx = (1:N) + (seg-1)*N;
    for j = 1:3
        [q_ref(idx,j), dq_ref(idx,j), ddq_ref(idx,j)] = ...
            quintic_traj(q0s(seg,j), qfs(seg,j), T, t_seg);
    end
end

%% ── Build Full Time Vector ───────────────────────────────
t_full = (0 : dt : NUM_SEGS*T - dt)';   % 20001×1 for 4 segments × 5 s

% Safety: trim to same length in case of rounding
L = min(length(t_full), total_N);
t_full  = t_full(1:L);
q_ref   = q_ref(1:L,:);
dq_ref  = dq_ref(1:L,:);
ddq_ref = ddq_ref(1:L,:);

%% ── Package for Simulink From Workspace Blocks ───────────
traj_q   = [t_full, q_ref];    % L×4  [time | q1  | q2  | q3 ]
traj_dq  = [t_full, dq_ref];   % L×4  [time | dq1 | dq2 | dq3]
traj_ddq = [t_full, ddq_ref];  % L×4  [time | ddq1| ddq2| ddq3]

%% ── Console Verification ─────────────────────────────────
fprintf('\n====== TRAJECTORY VERIFICATION ======\n');
fprintf('Segments      : %d\n',   NUM_SEGS);
fprintf('Total duration: %.1f s\n', t_full(end));
fprintf('Total steps   : %d\n',   length(t_full));
fprintf('dt            : %.4f s\n', dt);
fprintf('\n--- Boundary Conditions (must all be 0) ---\n');
for seg = 1:NUM_SEGS
    i_start = (seg-1)*N + 1;
    i_end   = min(seg*N, L);   % clamp to actual array length
    fprintf('Seg %d start velocity: [%.2e  %.2e  %.2e]\n', seg, ...
        dq_ref(i_start,1), dq_ref(i_start,2), dq_ref(i_start,3));
    fprintf('Seg %d end   velocity: [%.2e  %.2e  %.2e]\n', seg, ...
        dq_ref(i_end,1),   dq_ref(i_end,2),   dq_ref(i_end,3));
end
fprintf('\n--- Segment Start/End Positions (rad) ---\n');
labels = {'Home→Pick','Pick→Place','Place→Home','Home→Inspect'};
for seg = 1:NUM_SEGS
    i_start = (seg-1)*N + 1;
    i_end   = min(seg*N, L);   % clamp to actual array length
    fprintf('Seg %d (%s)\n', seg, labels{seg});
    fprintf('   Start: [%7.4f  %7.4f  %7.4f]\n', q_ref(i_start,:));
    fprintf('   End  : [%7.4f  %7.4f  %7.4f]\n', q_ref(i_end,:));
end
fprintf('\n--- Workspace Variables ---\n');
fprintf('traj_q   : %dx%d  (use columns [1,2] [1,3] [1,4] in From Workspace)\n', size(traj_q));
fprintf('traj_dq  : %dx%d\n', size(traj_dq));
fprintf('traj_ddq : %dx%d\n', size(traj_ddq));
fprintf('\nSet Simulink Stop Time to: %.1f s\n', t_full(end));
fprintf('=====================================\n\n');

%% ── Verification Plot ────────────────────────────────────
seg_times = (0:NUM_SEGS) * T;   % segment boundary lines

figure('Name','Trajectory Verification','NumberTitle','off');

% Position
ax1 = subplot(3,1,1);
plot(t_full, q_ref, 'LineWidth', 1.5);
hold on;
for s = seg_times(2:end-1)
    xline(s,'--k','Alpha',0.4);
end
hold off;
title('Joint Position (rad)'); ylabel('rad');
legend('Joint 1','Joint 2','Joint 3','Location','best');
grid on;

% Velocity
ax2 = subplot(3,1,2);
plot(t_full, dq_ref, 'LineWidth', 1.5);
hold on;
for s = seg_times(2:end-1)
    xline(s,'--k','Alpha',0.4);
end
yline(0, 'k:', 'LineWidth', 1);
hold off;
title('Joint Velocity (rad/s) — must touch 0 at segment boundaries');
ylabel('rad/s'); legend('Joint 1','Joint 2','Joint 3','Location','best');
grid on;

% Acceleration
ax3 = subplot(3,1,3);
plot(t_full, ddq_ref, 'LineWidth', 1.5);
hold on;
for s = seg_times(2:end-1)
    xline(s,'--k','Alpha',0.4);
end
yline(0, 'k:', 'LineWidth', 1);
hold off;
title('Joint Acceleration (rad/s²) — must touch 0 at segment boundaries');
ylabel('rad/s²'); xlabel('Time (s)');
legend('Joint 1','Joint 2','Joint 3','Location','best');
grid on;

linkaxes([ax1 ax2 ax3], 'x');
sgtitle('Quintic Trajectory — 4 Segments (dashed lines = segment boundaries)');
