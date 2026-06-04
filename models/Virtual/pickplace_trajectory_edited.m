% =========================================================
%  PICKPLACE_TRAJECTORY_EDITED.M
%  Quintic trajectory generator - 4 segments, 3 joints
%
%  Edited for Virtual Twin q-only inverse dynamics:
%  - No duplicated internal segment time points
%  - Final endpoint is included exactly at 20.0 s
%  - q_ref is smooth enough for Revolute Joint Motion = Provided by Input
%  - dq_ref and ddq_ref are still generated for controller/logging/validation
%
%  Run this BEFORE starting the Simulink simulation.
% =========================================================

clear traj_q traj_dq traj_ddq q_ref dq_ref ddq_ref t_full

%% -- Parameters ----------------------------------------------------------
dt = 0.001;          % 1 ms timestep - match Simulink fixed step if used
T  = 5;              % duration per segment (seconds)
NUM_SEGS = 4;        % number of pick/place trajectory segments

%% -- Segment Definitions (radians) --------------------------------------
%        Joint1    Joint2    Joint3
q0_1 = [ 0,        -pi/4,    -pi/4  ];   % Home
qf_1 = [ pi/3,     -pi/3,    -pi/3  ];   % Pick

q0_2 = [ pi/3,     -pi/3,    -pi/3  ];   % Pick
qf_2 = [ pi/6,     -pi/2,    -pi/6  ];   % Place

q0_3 = [ pi/6,     -pi/2,    -pi/6  ];   % Place
qf_3 = [ 0,        -pi/4,    -pi/4  ];   % Home

q0_4 = [ 0,        -pi/4,    -pi/4  ];   % Home
qf_4 = [-pi/3,     -pi/6,    -pi/2  ];   % Inspect

q0s = [q0_1; q0_2; q0_3; q0_4];   % 4 x 3
qfs = [qf_1; qf_2; qf_3; qf_4];   % 4 x 3
labels = {'Home->Pick','Pick->Place','Place->Home','Home->Inspect'};

%% -- Generate all segments without duplicate internal endpoints ----------
% Why this matters:
% If every segment includes both 0 and T, then the global time vector can
% contain repeated internal boundary points. Repeated or trimmed time points
% may cause interpolation issues or tiny artificial torque spikes in the
% Virtual Twin. This version excludes the endpoint for segments 1..3 and
% includes it only for the final segment.

t_full  = [];
q_ref   = [];
dq_ref  = [];
ddq_ref = [];

for seg = 1:NUM_SEGS
    if seg < NUM_SEGS
        t_seg = (0:dt:T-dt)';    % exclude internal endpoint
    else
        t_seg = (0:dt:T)';       % include final endpoint at 20.0 s
    end

    q_seg   = zeros(length(t_seg), 3);
    dq_seg  = zeros(length(t_seg), 3);
    ddq_seg = zeros(length(t_seg), 3);

    for j = 1:3
        [q_seg(:,j), dq_seg(:,j), ddq_seg(:,j)] = ...
            quintic_traj(q0s(seg,j), qfs(seg,j), T, t_seg);
    end

    t_global = t_seg + (seg-1)*T;

    t_full  = [t_full;  t_global]; %#ok<AGROW>
    q_ref   = [q_ref;   q_seg];    %#ok<AGROW>
    dq_ref  = [dq_ref;  dq_seg];   %#ok<AGROW>
    ddq_ref = [ddq_ref; ddq_seg];  %#ok<AGROW>
end

%% -- Package for Simulink From Workspace Blocks -------------------------
% Use these exactly as before:
%   traj_q(:,[1,2])   -> Joint 1 q_ref
%   traj_q(:,[1,3])   -> Joint 2 q_ref
%   traj_q(:,[1,4])   -> Joint 3 q_ref
%
% For the Physical_Arm PD controller, keep using:
%   traj_dq(:,[1,2]), traj_dq(:,[1,3]), traj_dq(:,[1,4])
%
% For the Virtual_Twin q-only motion input, use traj_q only.

traj_q   = [t_full, q_ref];    % [time | q1   | q2   | q3  ]
traj_dq  = [t_full, dq_ref];   % [time | dq1  | dq2  | dq3 ]
traj_ddq = [t_full, ddq_ref];  % [time | ddq1 | ddq2 | ddq3]

stop_time = NUM_SEGS * T;      % recommended Simulink stop time
sample_time = dt;              % useful if you set a fixed-step solver

%% -- Safety checks -------------------------------------------------------
if any(diff(t_full) <= 0)
    error('Trajectory time vector is not strictly increasing. Check dt/T generation.');
end

if abs(t_full(1) - 0) > eps
    error('Trajectory does not start at t = 0.');
end

if abs(t_full(end) - stop_time) > 10*eps(stop_time)
    error('Trajectory does not end exactly at the expected stop time.');
end

% Verify connected segment positions at exact boundary times.
% Internal boundary samples belong to the next segment start, so their
% position should equal the next segment q0, which is also the previous qf.
for seg = 1:NUM_SEGS-1
    boundary_time = seg*T;
    idx_boundary = find(abs(t_full - boundary_time) < 10*eps(boundary_time), 1, 'first');
    if isempty(idx_boundary)
        error('Missing internal boundary sample at t = %.6f s.', boundary_time);
    end

    expected_q = qfs(seg,:);
    if max(abs(q_ref(idx_boundary,:) - expected_q)) > 1e-10
        error('Position mismatch at boundary after segment %d.', seg);
    end
end

%% -- Console verification ------------------------------------------------
fprintf('\n====== TRAJECTORY VERIFICATION ======\n');
fprintf('Segments      : %d\n',   NUM_SEGS);
fprintf('Total duration: %.3f s\n', t_full(end));
fprintf('Total steps   : %d\n',   length(t_full));
fprintf('dt            : %.4f s\n', dt);
fprintf('Duplicate time points: %d\n', sum(diff(t_full) == 0));

fprintf('\n--- Boundary Conditions at Exact Segment Boundaries ---\n');
for seg = 1:NUM_SEGS
    t_start = (seg-1)*T;
    t_end   = seg*T;

    idx_start = find(abs(t_full - t_start) < max(10*eps(max(1,t_start)), dt/100), 1, 'first');
    idx_end   = find(abs(t_full - t_end)   < max(10*eps(max(1,t_end)),   dt/100), 1, 'first');

    fprintf('Seg %d (%s)\n', seg, labels{seg});
    fprintf('   Start t=%.3f q : [%7.4f  %7.4f  %7.4f]\n', t_full(idx_start), q_ref(idx_start,:));
    fprintf('   Start velocity : [%.2e  %.2e  %.2e]\n', dq_ref(idx_start,1), dq_ref(idx_start,2), dq_ref(idx_start,3));

    if ~isempty(idx_end)
        fprintf('   End   t=%.3f q : [%7.4f  %7.4f  %7.4f]\n', t_full(idx_end), q_ref(idx_end,:));
        fprintf('   End   velocity : [%.2e  %.2e  %.2e]\n', dq_ref(idx_end,1), dq_ref(idx_end,2), dq_ref(idx_end,3));
    else
        % This should not happen with this edited generator.
        fprintf('   End boundary not found.\n');
    end
end

fprintf('\n--- Workspace Variables ---\n');
fprintf('traj_q   : %dx%d  [time | q1 | q2 | q3]\n',   size(traj_q));
fprintf('traj_dq  : %dx%d  [time | dq1 | dq2 | dq3]\n', size(traj_dq));
fprintf('traj_ddq : %dx%d  [time | ddq1 | ddq2 | ddq3]\n', size(traj_ddq));
fprintf('stop_time: %.3f s  -> set Simulink Stop Time to this value\n', stop_time);
fprintf('sample_time: %.4f s\n', sample_time);
fprintf('=====================================\n\n');

%% -- Verification plot ---------------------------------------------------
seg_times = (0:NUM_SEGS) * T;

figure('Name','Trajectory Verification - Edited','NumberTitle','off');

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
title('Joint Velocity (rad/s) - zero at exact segment boundaries');
ylabel('rad/s');
legend('Joint 1','Joint 2','Joint 3','Location','best');
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
title('Joint Acceleration (rad/s^2) - zero at exact segment boundaries');
ylabel('rad/s^2'); xlabel('Time (s)');
legend('Joint 1','Joint 2','Joint 3','Location','best');
grid on;

linkaxes([ax1 ax2 ax3], 'x');
sgtitle('Edited Quintic Trajectory - No Duplicate Internal Time Points');
