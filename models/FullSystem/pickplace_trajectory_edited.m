clear traj_q traj_dq traj_ddq q_ref dq_ref ddq_ref t_full

dt       = 0.001;
T        = 5;
NUM_SEGS = 2; % was 4

variance_sample = @() min(max(0.05 * randn(1,3), -0.08), 0.08);

base_home    = [ 0,      -pi/4, -pi/4 ];
base_pick    = [ pi/3,   -pi/2, -pi/3 ];
base_place   = [-pi/3,    0,    -pi/6 ];
base_inspect = [-pi/6,   -pi/6, -pi/2 ];

q0_1 = base_home    + variance_sample();
qf_1 = base_pick    + variance_sample();
q0_2 = qf_1;
qf_2 = base_place   + variance_sample();
q0_3 = qf_2;
qf_3 = base_home    + variance_sample();
q0_4 = qf_3;
qf_4 = base_inspect + variance_sample();

q0s = [q0_1; q0_2; q0_3; q0_4];
qfs = [qf_1; qf_2; qf_3; qf_4];

t_full  = [];
q_ref   = [];
dq_ref  = [];
ddq_ref = [];

for seg = 1:NUM_SEGS
    if seg < NUM_SEGS
        t_seg = (0:dt:T-dt)';
    else
        t_seg = (0:dt:T)';
    end

    q_seg   = zeros(length(t_seg), 3);
    dq_seg  = zeros(length(t_seg), 3);
    ddq_seg = zeros(length(t_seg), 3);

    for j = 1:3
        [q_seg(:,j), dq_seg(:,j), ddq_seg(:,j)] = ...
            quintic_traj(q0s(seg,j), qfs(seg,j), T, t_seg);
    end

    t_global = t_seg + (seg-1)*T;
    t_full   = [t_full;  t_global]; %#ok<AGROW>
    q_ref    = [q_ref;   q_seg];    %#ok<AGROW>
    dq_ref   = [dq_ref;  dq_seg];   %#ok<AGROW>
    ddq_ref  = [ddq_ref; ddq_seg];  %#ok<AGROW>
end

traj_q   = [t_full, q_ref];
traj_dq  = [t_full, dq_ref];
traj_ddq = [t_full, ddq_ref];
stop_time   = NUM_SEGS * T;
sample_time = dt;