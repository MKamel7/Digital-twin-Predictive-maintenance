% =========================================================
%  STEP_TEST_TRAJ.M — one-joint step, others held
% =========================================================
clear; clc;

dt      = 0.001;
T_total = 4;                       % 4-second test per joint
t_full  = (0:dt:T_total)';         % column time vector
N       = length(t_full);

% Home pose (rad)
q_home = [0, -pi/3, -pi/3];       % pick pose — q2+q3 = -2π/3

% Target joint and step size
target_joint = 3;                  % 1 = Waist, 2 = Shoulder, 3 = Elbow
step_size    = deg2rad(20);        % 20° step

% Hold home for 0.5 s, then step
q_ref_mat  = repmat(q_home, N, 1);
idx_step   = t_full >= 0.5;
q_ref_mat(idx_step, target_joint) = q_home(target_joint) + step_size;

% Derivatives of an ideal step are zero (controller absorbs the jump)
dq_ref_mat  = zeros(N,3);
ddq_ref_mat = zeros(N,3);

% Package for From Workspace blocks (same shape as your project)
traj_q   = [t_full, q_ref_mat];
traj_dq  = [t_full, dq_ref_mat];
traj_ddq = [t_full, ddq_ref_mat];

fprintf('Step test ready. Simulink stop time: %.2f s\n', T_total);
fprintf('Joint under test: %d\n', target_joint);
