%% save_phase1_healthy_batch.m
% Generate and save 5 healthy baseline datasets for Phase 1.
% Assumes your Simulink From Workspace blocks use:
% traj_q, traj_dq, traj_ddq

clc;

%% --------------------------------------------------------
% 0) Project/model setup
%% --------------------------------------------------------
% 0) Project/model setup
% ---------------------------------------------------------
projectRoot = 'C:\Users\AMMAR\Documents\MATLAB\Digital twin Predictive maintenance';
modelFolder = fullfile(projectRoot, 'models', 'Backup');

cd(modelFolder);
addpath(genpath(modelFolder));
rehash toolboxcache;

% Find the Simscape Multibody data file automatically
dataFiles = dir(fullfile(modelFolder, '*DataFile*.m'));

assert(~isempty(dataFiles), 'No DataFile .m file was found in: %s', modelFolder);

dataFile = fullfile(dataFiles(1).folder, dataFiles(1).name);

fprintf('Loading Simscape data file:\n%s\n', dataFile);

run(dataFile);   % loads smiData

assert(exist('smiData','var') == 1, 'smiData was not loaded correctly.');

fprintf('smiData loaded successfully.\n');

% Use your current working model name
modelName = 'RobotFaultDetection_Phase1_step7_residual_working';
% If you saved as step8, use this instead:
% modelName = 'RobotFaultDetection_Phase1_step8_logging_working';

load_system(modelName);

%% --------------------------------------------------------
% 1) Global trajectory settings
% ---------------------------------------------------------
dt = 0.001;                 % 1 kHz
sample_rate = 1/dt;
startup_ignore_s = 0.5;

% Joint order:
joint_order = {'Joint1_Waist', 'Joint2_Shoulder', 'Joint3_Elbow'};

% Base poses
home    = [ 0,       -pi/4,   -pi/4  ];
pick    = [ pi/3,    -pi/3,   -pi/3  ];
place   = [ pi/6,    -pi/2,   -pi/6  ];
inspect = [-pi/3,    -pi/6,   -pi/2  ];

%% --------------------------------------------------------
% 2) Define 5 healthy trajectory variants
% Each row in waypoints is one pose [J1 J2 J3].
% Consecutive rows form smooth quintic segments.
% ---------------------------------------------------------

variants = struct([]);

variants(1).id = 'H01_nominal';
variants(1).T  = 5.0;
variants(1).waypoints = [
    home
    pick
    place
    home
    inspect
];

variants(2).id = 'H02_slow_nominal';
variants(2).T  = 6.0;
variants(2).waypoints = [
    home
    pick
    place
    home
    inspect
];

variants(3).id = 'H03_small_range';
variants(3).T  = 5.0;
variants(3).waypoints = [
    home
    [ 0.85*pi/3, -0.95*pi/3, -0.90*pi/3]
    [ 0.45,      -1.35,      -0.65]
    home
    [-0.80*pi/3, -0.60,      -1.30]
];

variants(4).id = 'H04_elbow_emphasis';
variants(4).T  = 5.5;
variants(4).waypoints = [
    home
    [ pi/4,   -pi/3,  -pi/2]
    [ pi/5,   -1.35,  -pi/5]
    home
    [-pi/4,   -pi/5,  -1.20]
];

variants(5).id = 'H05_alt_inspect';
variants(5).T  = 5.0;
variants(5).waypoints = [
    home
    [ pi/4,    -0.90,   -0.90]
    [ pi/8,    -1.45,   -0.60]
    home
    [-0.90,    -0.70,   -1.40]
];

%% --------------------------------------------------------
% 3) Output folder
% ---------------------------------------------------------
folder = fullfile('data', 'healthy');
if ~exist(folder, 'dir')
    mkdir(folder);
end

summary = struct([]);

%% --------------------------------------------------------
% 4) Run and save all healthy variants
% ---------------------------------------------------------
for k = 1:numel(variants)

    fprintf('\n\n=================================================\n');
    fprintf('Running healthy variant %d/%d: %s\n', k, numel(variants), variants(k).id);
    fprintf('=================================================\n');

    % Generate trajectory variables for Simulink
    [traj_q, traj_dq, traj_ddq, stop_time] = build_quintic_waypoint_traj( ...
        variants(k).waypoints, variants(k).T, dt);

    % Put stop_time into workspace and set Simulink Stop Time
    set_param(modelName, 'StopTime', num2str(stop_time));

    % Basic trajectory checks
    assert(size(traj_q,2) == 4,   'traj_q must be [time q1 q2 q3]');
    assert(size(traj_dq,2) == 4,  'traj_dq must be [time dq1 dq2 dq3]');
    assert(size(traj_ddq,2) == 4, 'traj_ddq must be [time ddq1 ddq2 ddq3]');
    assert(any(diff(traj_q(:,1)) <= 0) == 0, 'Trajectory time must be strictly increasing.');

    fprintf('Trajectory duration: %.3f s | Samples: %d\n', stop_time, size(traj_q,1));

    % Run simulation
    out = sim(modelName);

    % Extract signals and synchronize to delta_tau time
    data = build_healthy_data_record(out, traj_q, traj_dq, traj_ddq, ...
        modelName, variants(k), joint_order, dt, sample_rate, startup_ignore_s);

    % Quality checks
    q = check_healthy_dataset_quality(data, startup_ignore_s);

    % Save only if quality check passes hard safety checks
    if q.pass
        filename = fullfile(folder, sprintf('run_healthy_%s_j0_s0_%s.mat', ...
            variants(k).id, datestr(now, 'yyyymmdd_HHMMSS')));

        save(filename, 'data');

        fprintf('Saved healthy dataset:\n%s\n', filename);
    else
        warning('Variant %s failed quality checks. Dataset was NOT saved.', variants(k).id);
        filename = '';
    end

    % Store summary
    summary(k).trajectory_id = variants(k).id;
    summary(k).saved_file = filename;
    summary(k).pass = q.pass;
    summary(k).residual_rms = q.residual_rms;
    summary(k).residual_max_abs = q.residual_max_abs;
    summary(k).tracking_rms_deg = q.tracking_rms_deg;
    summary(k).tracking_max_deg = q.tracking_max_deg;
end

%% --------------------------------------------------------
% 5) Save summary
% ---------------------------------------------------------
summaryFile = fullfile(folder, sprintf('healthy_batch_summary_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
save(summaryFile, 'summary');

fprintf('\n\n=================================================\n');
fprintf('Healthy batch complete.\n');
fprintf('Summary saved:\n%s\n', summaryFile);
fprintf('=================================================\n');


%% ========================================================
% Local helper functions
% =========================================================

function [traj_q, traj_dq, traj_ddq, stop_time] = build_quintic_waypoint_traj(waypoints, T, dt)
    % waypoints: M x 3
    % T: duration per segment
    % dt: sample time

    num_points = size(waypoints, 1);
    num_segs = num_points - 1;

    q_ref = [];
    dq_ref = [];
    ddq_ref = [];
    t_full = [];

    for seg = 1:num_segs
        % Exclude endpoint for all but final segment to avoid duplicate times
        if seg < num_segs
            t_seg = (0:dt:T-dt)';
        else
            t_seg = (0:dt:T)';
        end

        q_seg   = zeros(length(t_seg), 3);
        dq_seg  = zeros(length(t_seg), 3);
        ddq_seg = zeros(length(t_seg), 3);

        for j = 1:3
            [q_seg(:,j), dq_seg(:,j), ddq_seg(:,j)] = ...
                quintic_traj(waypoints(seg,j), waypoints(seg+1,j), T, t_seg);
        end

        t_global = t_seg + (seg-1)*T;

        t_full  = [t_full;  t_global];
        q_ref   = [q_ref;   q_seg];
        dq_ref  = [dq_ref;  dq_seg];
        ddq_ref = [ddq_ref; ddq_seg];
    end

    traj_q   = [t_full, q_ref];
    traj_dq  = [t_full, dq_ref];
    traj_ddq = [t_full, ddq_ref];

    stop_time = t_full(end);
end


function data = build_healthy_data_record(out, traj_q, traj_dq, traj_ddq, ...
    modelName, variant, joint_order, dt, sample_rate, startup_ignore_s)

    % Extract timeseries from simulation output object
    ts_tau_actual     = out.tau_actual;
    ts_tau_expected   = out.tau_expected;
    ts_delta_tau      = out.delta_tau;
    ts_q_actual       = out.q_actual;
    ts_dq_actual      = out.dq_actual;
    ts_current_actual = out.current_actual;

    % Use delta_tau time as master simulation time
    t = ts_delta_tau.Time;

    % Synchronize everything to same time vector
    data = struct();

    data.condition    = 'healthy';
    data.fault_type   = 'none';
    data.joint_id     = 0;
    data.severity     = 0;
    data.sample_time  = dt;
    data.sample_rate  = sample_rate;
    data.model_name   = modelName;
    data.trajectory_id = variant.id;
    data.segment_duration = variant.T;
    data.waypoints    = variant.waypoints;
    data.joint_order  = joint_order;
    data.created_at   = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    data.startup_ignore_s = startup_ignore_s;

    data.time = t;

    data.tau_actual = interp1(ts_tau_actual.Time, ts_tau_actual.Data, t, 'linear', 'extrap');
    data.tau_expected = interp1(ts_tau_expected.Time, ts_tau_expected.Data, t, 'linear', 'extrap');
    data.delta_tau = interp1(ts_delta_tau.Time, ts_delta_tau.Data, t, 'linear', 'extrap');

    data.q_actual = interp1(ts_q_actual.Time, ts_q_actual.Data, t, 'linear', 'extrap');
    data.dq_actual = interp1(ts_dq_actual.Time, ts_dq_actual.Data, t, 'linear', 'extrap');
    data.current_actual = interp1(ts_current_actual.Time, ts_current_actual.Data, t, 'linear', 'extrap');

    % Reference signals from trajectory arrays
    data.q_ref = interp1(traj_q(:,1), traj_q(:,2:4), t, 'linear', 'extrap');
    data.dq_ref = interp1(traj_dq(:,1), traj_dq(:,2:4), t, 'linear', 'extrap');
    data.ddq_ref = interp1(traj_ddq(:,1), traj_ddq(:,2:4), t, 'linear', 'extrap');

    % Tracking error in degrees
    data.q_tracking_error_deg = (data.q_ref - data.q_actual) * 180/pi;
end


function q = check_healthy_dataset_quality(data, startup_ignore_s)

    required = {'tau_actual','tau_expected','delta_tau','q_actual','dq_actual','current_actual','q_ref','dq_ref','ddq_ref'};

    fprintf('\n--- Dataset quality check: %s ---\n', data.trajectory_id);
    fprintf('Samples : %d\n', length(data.time));
    fprintf('Duration: %.3f s\n', data.time(end) - data.time(1));

    pass = true;

    for i = 1:numel(required)
        x = data.(required{i});
        has_nan = any(isnan(x), 'all');
        has_inf = any(isinf(x), 'all');

        fprintf('%-16s size: %d x %d | NaN: %d | Inf: %d\n', ...
            required{i}, size(x,1), size(x,2), has_nan, has_inf);

        if size(x,2) ~= 3 || has_nan || has_inf
            pass = false;
        end
    end

    idx = data.time > startup_ignore_s;

    residual_rms = rms(data.delta_tau(idx,:), 1);
    residual_max_abs = max(abs(data.delta_tau(idx,:)), [], 1);

    tracking_rms_deg = rms(data.q_tracking_error_deg(idx,:), 1);
    tracking_max_deg = max(abs(data.q_tracking_error_deg(idx,:)), [], 1);

    fprintf('\nHealthy residual after %.2f s:\n', startup_ignore_s);
    for j = 1:3
        fprintf('Joint %d: RMS = %.4f Nm | Max abs = %.4f Nm\n', ...
            j, residual_rms(j), residual_max_abs(j));
    end

    fprintf('\nTracking error after %.2f s:\n', startup_ignore_s);
    for j = 1:3
        fprintf('Joint %d: RMS = %.3f deg | Max = %.3f deg\n', ...
            j, tracking_rms_deg(j), tracking_max_deg(j));
    end

    % Hard sanity gates. These are not final thesis thresholds.
    % They only prevent saving broken simulations.
    if any(residual_max_abs > [2.0, 3.0, 2.0])
        warning('Residual max is too high for a healthy baseline.');
        pass = false;
    end

    if any(tracking_max_deg > [3.0, 8.0, 8.0])
        warning('Tracking error is too high for a healthy baseline.');
        pass = false;
    end

    q.pass = pass;
    q.residual_rms = residual_rms;
    q.residual_max_abs = residual_max_abs;
    q.tracking_rms_deg = tracking_rms_deg;
    q.tracking_max_deg = tracking_max_deg;

    if pass
        fprintf('\nQUALITY RESULT: PASS\n');
    else
        fprintf('\nQUALITY RESULT: FAIL\n');
    end
end