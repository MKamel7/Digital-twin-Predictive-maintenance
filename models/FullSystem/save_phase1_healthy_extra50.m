%% generate_50_healthy_datasets.m
% Generate 50 robust healthy datasets for Phase 2 handoff.
% Output folder:
%   C:\Users\AMMAR\Documents\MATLAB\Digital twin Predictive maintenance\data\healthy_50

clc;
close all;

%% --------------------------------------------------------
% 0) Project setup
% ---------------------------------------------------------
projectRoot = 'C:\Users\AMMAR\Documents\MATLAB\Digital twin Predictive maintenance';
modelFolder = fullfile(projectRoot, 'models', 'Backup');

outputFolder = fullfile(projectRoot, 'data', 'healthy_50');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

cd(modelFolder);
addpath(genpath(modelFolder));
rehash toolboxcache;

% Load Simscape Multibody import data
dataFiles = dir(fullfile(modelFolder, '*DataFile*.m'));
assert(~isempty(dataFiles), 'No DataFile .m file found in: %s', modelFolder);

dataFile = fullfile(dataFiles(1).folder, dataFiles(1).name);
fprintf('Loading Simscape data file:\n%s\n', dataFile);
run(dataFile);
assert(exist('smiData','var') == 1, 'smiData was not loaded correctly.');

% Choose model
modelCandidates = {
    'RobotFaultDetection_Phase1_step10_validation_PASS'
    'RobotFaultDetection_Phase1_step8_logging_working'
    'RobotFaultDetection_Phase1_step10_baseline_PASS'
	
};

modelName = '';
for i = 1:numel(modelCandidates)
    if exist(fullfile(modelFolder, [modelCandidates{i} '.slx']), 'file')
        modelName = modelCandidates{i};
        break;
    end
end

assert(~isempty(modelName), 'No suitable Simulink model found in modelFolder.');

fprintf('Using model:\n%s\n', modelName);
load_system(modelName);

%% --------------------------------------------------------
% 1) Dataset settings
% ---------------------------------------------------------
rng(20260604);              % reproducible healthy dataset

targetAccepted = 50;
maxAttempts    = 150;

dt              = 0.001;    % 1 kHz
sample_rate     = 1000;
startup_ignore_s = 0.5;

joint_order = {'Joint1_Waist', 'Joint2_Shoulder', 'Joint3_Elbow'};

% Quality gates: sanity gates only, not final thesis thresholds
residual_max_limit_Nm = [2.0, 3.0, 2.0];
tracking_max_limit_deg = [3.0, 8.0, 8.0];

accepted = 0;
attempt  = 0;

manifest = table();

fprintf('\nTarget accepted healthy runs: %d\n', targetAccepted);
fprintf('Output folder:\n%s\n\n', outputFolder);

%% --------------------------------------------------------
% 2) Generate datasets
% ---------------------------------------------------------
while accepted < targetAccepted && attempt < maxAttempts

    attempt = attempt + 1;

    fprintf('\n=================================================\n');
    fprintf('Attempt %d | Accepted %d/%d\n', attempt, accepted, targetAccepted);
    fprintf('=================================================\n');

    % Build safe random healthy trajectory
    [waypoints, Tseg, trajFamily] = make_safe_healthy_waypoints(attempt);

    [traj_q, traj_dq, traj_ddq, stop_time] = build_quintic_waypoint_traj(waypoints, Tseg, dt);

    % Put variables into base workspace for From Workspace blocks
    assignin('base', 'traj_q', traj_q);
    assignin('base', 'traj_dq', traj_dq);
    assignin('base', 'traj_ddq', traj_ddq);
    assignin('base', 'stop_time', stop_time);
    assignin('base', 'smiData', smiData);

    set_param(modelName, 'StopTime', num2str(stop_time));

    fprintf('Trajectory family: %s\n', trajFamily);
    fprintf('Segments: %d | T per segment: %.2f s | Total duration: %.2f s | Samples: %d\n', ...
        size(waypoints,1)-1, Tseg, stop_time, size(traj_q,1));

    % Run simulation
    try
        out = sim(modelName);
    catch ME
        warning('Simulation failed on attempt %d: %s', attempt, ME.message);
        continue;
    end

    % Build structured dataset
    try
        data = build_healthy_data_record(out, traj_q, traj_dq, traj_ddq, ...
            modelName, attempt, trajFamily, waypoints, Tseg, joint_order, ...
            dt, sample_rate, startup_ignore_s);
    catch ME
        warning('Data extraction failed on attempt %d: %s', attempt, ME.message);
        continue;
    end

    % Quality check
    q = check_healthy_dataset_quality(data, startup_ignore_s, ...
        residual_max_limit_Nm, tracking_max_limit_deg);

    data.quality = q;

    if ~q.pass
        fprintf('QUALITY RESULT: FAIL — not saved.\n');
        continue;
    end

    accepted = accepted + 1;

    trajectory_id = sprintf('H%02d_%s', accepted, trajFamily);
    data.trajectory_id = trajectory_id;

    fileName = sprintf('run_healthy_%s_j0_s0_attempt%03d_%s.mat', ...
        trajectory_id, attempt, datestr(now, 'yyyymmdd_HHMMSS'));

    filePath = fullfile(outputFolder, fileName);

    save(filePath, 'data');

    fprintf('QUALITY RESULT: PASS\n');
    fprintf('Saved:\n%s\n', filePath);

    % Add to manifest
    newRow = table( ...
        {fileName}, ...
        {trajectory_id}, ...
        {trajFamily}, ...
        attempt, ...
        stop_time, ...
        size(data.time,1), ...
        Tseg, ...
        q.residual_rms(1), q.residual_rms(2), q.residual_rms(3), ...
        q.residual_max_abs(1), q.residual_max_abs(2), q.residual_max_abs(3), ...
        q.tracking_rms_deg(1), q.tracking_rms_deg(2), q.tracking_rms_deg(3), ...
        q.tracking_max_deg(1), q.tracking_max_deg(2), q.tracking_max_deg(3), ...
        'VariableNames', { ...
            'file_name','trajectory_id','family','attempt','duration_s','samples','segment_duration_s', ...
            'residual_rms_J1','residual_rms_J2','residual_rms_J3', ...
            'residual_max_J1','residual_max_J2','residual_max_J3', ...
            'tracking_rms_deg_J1','tracking_rms_deg_J2','tracking_rms_deg_J3', ...
            'tracking_max_deg_J1','tracking_max_deg_J2','tracking_max_deg_J3'});

    manifest = [manifest; newRow]; %#ok<AGROW>
end

%% --------------------------------------------------------
% 3) Save manifest and README
% ---------------------------------------------------------
assert(accepted == targetAccepted, ...
    'Only %d/%d healthy datasets were accepted. Increase maxAttempts or relax quality gates.', ...
    accepted, targetAccepted);

manifestFile = fullfile(outputFolder, 'manifest_healthy_50.csv');
writetable(manifest, manifestFile);

summaryFile = fullfile(outputFolder, 'manifest_healthy_50.mat');
save(summaryFile, 'manifest');

readmeFile = fullfile(outputFolder, 'README_healthy_50.txt');
write_healthy_readme(readmeFile, modelName, outputFolder, targetAccepted, dt, sample_rate, ...
    startup_ignore_s, joint_order, residual_max_limit_Nm, tracking_max_limit_deg);

fprintf('\n=================================================\n');
fprintf('HEALTHY DATASET GENERATION COMPLETE\n');
fprintf('Accepted runs: %d/%d\n', accepted, targetAccepted);
fprintf('Folder:\n%s\n', outputFolder);
fprintf('Manifest CSV:\n%s\n', manifestFile);
fprintf('README:\n%s\n', readmeFile);
fprintf('=================================================\n');

winopen(outputFolder);

%% ========================================================
% Local functions
% =========================================================

function [waypoints, Tseg, family] = make_safe_healthy_waypoints(attempt)

    home = [0, -pi/4, -pi/4];

    % Conservative safe joint ranges, away from hard limits
    qMin = [-1.10, -1.60, -1.60];
    qMax = [ 1.10, -0.50, -0.50];

    familyId = mod(attempt-1, 10) + 1;

    switch familyId
        case 1
            family = 'nominal_jitter';
            Tseg = 4.8 + 0.5*rand;
            base = [
                home
                [ pi/3, -pi/3, -pi/3]
                [ pi/6, -pi/2, -pi/6]
                home
                [-pi/3, -pi/6, -pi/2]
            ];
            waypoints = base + 0.06*randn(size(base));
            waypoints(1,:) = home;

        case 2
            family = 'slow_nominal_jitter';
            Tseg = 6.0 + 0.8*rand;
            base = [
                home
                [ pi/3, -pi/3, -pi/3]
                [ pi/6, -pi/2, -pi/6]
                home
                [-pi/3, -pi/6, -pi/2]
            ];
            waypoints = base + 0.05*randn(size(base));
            waypoints(1,:) = home;

        case 3
            family = 'small_range';
            Tseg = 4.8 + 0.8*rand;
            waypoints = [
                home
                random_pose(qMin, qMax, 0.65)
                random_pose(qMin, qMax, 0.60)
                home
                random_pose(qMin, qMax, 0.65)
            ];

        case 4
            family = 'waist_emphasis';
            Tseg = 5.2 + 0.8*rand;
            waypoints = [
                home
                [random_between(-1.05, 1.05), random_between(-1.00,-0.75), random_between(-1.00,-0.75)]
                [random_between(-1.05, 1.05), random_between(-1.30,-0.80), random_between(-1.10,-0.70)]
                home
                [random_between(-1.05, 1.05), random_between(-0.90,-0.60), random_between(-1.35,-0.75)]
            ];

        case 5
            family = 'shoulder_emphasis';
            Tseg = 5.5 + 0.8*rand;
            waypoints = [
                home
                [random_between(-0.60,0.60), random_between(-1.55,-1.25), random_between(-1.05,-0.70)]
                [random_between(-0.50,0.50), random_between(-0.80,-0.55), random_between(-1.25,-0.75)]
                home
                [random_between(-0.90,0.90), random_between(-1.45,-1.10), random_between(-1.45,-0.90)]
            ];

        case 6
            family = 'elbow_emphasis';
            Tseg = 5.6 + 1.0*rand;
            waypoints = [
                home
                [random_between(-0.70,0.70), random_between(-1.10,-0.80), random_between(-1.55,-1.25)]
                [random_between(-0.70,0.70), random_between(-1.40,-0.90), random_between(-0.75,-0.55)]
                home
                [random_between(-0.80,0.80), random_between(-1.10,-0.65), random_between(-1.50,-1.10)]
            ];

        case 7
            family = 'mixed_medium';
            Tseg = 5.0 + 1.2*rand;
            waypoints = make_random_chain(home, qMin, qMax, 6, [0.90, 0.70, 0.80]);

        case 8
            family = 'long_cycle';
            Tseg = 4.6 + 0.7*rand;
            waypoints = make_random_chain(home, qMin, qMax, 8, [0.75, 0.65, 0.70]);

        case 9
            family = 'low_acceleration';
            Tseg = 7.0 + 1.0*rand;
            waypoints = make_random_chain(home, qMin, qMax, 5, [0.85, 0.65, 0.75]);

        case 10
            family = 'alternative_inspect';
            Tseg = 5.2 + 0.8*rand;
            waypoints = [
                home
                [random_between(0.20,0.90), random_between(-1.10,-0.75), random_between(-1.10,-0.75)]
                [random_between(-0.20,0.60), random_between(-1.50,-1.20), random_between(-0.75,-0.55)]
                home
                [random_between(-1.00,-0.40), random_between(-0.95,-0.60), random_between(-1.50,-1.10)]
            ];
    end

    % Clamp safely
    waypoints = min(max(waypoints, qMin), qMax);
    waypoints(1,:) = home;
end


function pose = random_pose(qMin, qMax, scale)
    home = [0, -pi/4, -pi/4];
    raw = qMin + rand(1,3).*(qMax - qMin);
    pose = home + scale*(raw - home);
end


function waypoints = make_random_chain(home, qMin, qMax, nPoints, maxStep)
    waypoints = zeros(nPoints, 3);
    waypoints(1,:) = home;

    for i = 2:nPoints
        accepted = false;
        for tries = 1:100
            candidate = qMin + rand(1,3).*(qMax - qMin);
            if all(abs(candidate - waypoints(i-1,:)) <= maxStep)
                waypoints(i,:) = candidate;
                accepted = true;
                break;
            end
        end

        if ~accepted
            % fallback: small step from previous waypoint
            step = (2*rand(1,3)-1).*maxStep;
            candidate = waypoints(i-1,:) + step;
            waypoints(i,:) = min(max(candidate, qMin), qMax);
        end

        % Occasionally return to home to create realistic repeated work cycles
        if i == ceil(nPoints/2)
            waypoints(i,:) = home;
        end
    end
end


function r = random_between(a,b)
    r = a + (b-a)*rand;
end


function [traj_q, traj_dq, traj_ddq, stop_time] = build_quintic_waypoint_traj(waypoints, T, dt)

    num_points = size(waypoints, 1);
    num_segs = num_points - 1;

    q_ref = [];
    dq_ref = [];
    ddq_ref = [];
    t_full = [];

    for seg = 1:num_segs

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

        t_full  = [t_full;  t_global]; %#ok<AGROW>
        q_ref   = [q_ref;   q_seg]; %#ok<AGROW>
        dq_ref  = [dq_ref;  dq_seg]; %#ok<AGROW>
        ddq_ref = [ddq_ref; ddq_seg]; %#ok<AGROW>
    end

    traj_q   = [t_full, q_ref];
    traj_dq  = [t_full, dq_ref];
    traj_ddq = [t_full, ddq_ref];

    stop_time = t_full(end);
end


function data = build_healthy_data_record(out, traj_q, traj_dq, traj_ddq, ...
    modelName, attempt, family, waypoints, Tseg, joint_order, dt, sample_rate, startup_ignore_s)

    ts_tau_actual     = out.tau_actual;
    ts_tau_expected   = out.tau_expected;
    ts_delta_tau      = out.delta_tau;
    ts_q_actual       = out.q_actual;
    ts_dq_actual      = out.dq_actual;
    ts_current_actual = out.current_actual;

    t = ts_delta_tau.Time;

    data = struct();

    data.condition     = 'healthy';
    data.fault_type    = 'none';
    data.joint_id      = 0;
    data.severity      = 0;
    data.degradation_index = 0;

    data.model_name    = modelName;
    data.attempt_id    = attempt;
    data.trajectory_family = family;
    data.segment_duration = Tseg;
    data.waypoints     = waypoints;

    data.sample_time   = dt;
    data.sample_rate   = sample_rate;
    data.startup_ignore_s = startup_ignore_s;

    data.joint_order   = joint_order;
    data.created_at    = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    data.time = t;

    data.tau_actual = interp1(ts_tau_actual.Time, ts_tau_actual.Data, t, 'linear', 'extrap');
    data.tau_expected = interp1(ts_tau_expected.Time, ts_tau_expected.Data, t, 'linear', 'extrap');
    data.delta_tau = interp1(ts_delta_tau.Time, ts_delta_tau.Data, t, 'linear', 'extrap');

    data.q_actual = interp1(ts_q_actual.Time, ts_q_actual.Data, t, 'linear', 'extrap');
    data.dq_actual = interp1(ts_dq_actual.Time, ts_dq_actual.Data, t, 'linear', 'extrap');
    data.current_actual = interp1(ts_current_actual.Time, ts_current_actual.Data, t, 'linear', 'extrap');

    data.q_ref = interp1(traj_q(:,1), traj_q(:,2:4), t, 'linear', 'extrap');
    data.dq_ref = interp1(traj_dq(:,1), traj_dq(:,2:4), t, 'linear', 'extrap');
    data.ddq_ref = interp1(traj_ddq(:,1), traj_ddq(:,2:4), t, 'linear', 'extrap');

    data.q_tracking_error_deg = (data.q_ref - data.q_actual) * 180/pi;
end


function q = check_healthy_dataset_quality(data, startup_ignore_s, residual_max_limit_Nm, tracking_max_limit_deg)

    required = {'tau_actual','tau_expected','delta_tau','q_actual','dq_actual', ...
                'current_actual','q_ref','dq_ref','ddq_ref'};

    pass = true;

    fprintf('\n--- Quality check: %s ---\n', data.trajectory_family);
    fprintf('Samples : %d\n', length(data.time));
    fprintf('Duration: %.3f s\n', data.time(end) - data.time(1));

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

    residual_rms = sqrt(mean(data.delta_tau(idx,:).^2, 1));
    residual_max_abs = max(abs(data.delta_tau(idx,:)), [], 1);

    tracking_rms_deg = sqrt(mean(data.q_tracking_error_deg(idx,:).^2, 1));
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

    if any(residual_max_abs > residual_max_limit_Nm)
        warning('Residual max exceeded healthy sanity limit.');
        pass = false;
    end

    if any(tracking_max_deg > tracking_max_limit_deg)
        warning('Tracking error exceeded healthy sanity limit.');
        pass = false;
    end

    q = struct();
    q.pass = pass;
    q.residual_rms = residual_rms;
    q.residual_max_abs = residual_max_abs;
    q.tracking_rms_deg = tracking_rms_deg;
    q.tracking_max_deg = tracking_max_deg;
end


function write_healthy_readme(readmeFile, modelName, outputFolder, targetAccepted, dt, sample_rate, ...
    startup_ignore_s, joint_order, residual_max_limit_Nm, tracking_max_limit_deg)

    fid = fopen(readmeFile, 'w');
    assert(fid ~= -1, 'Could not create README file.');

    fprintf(fid, 'Healthy Dataset Handoff — Digital Twin Predictive Maintenance\n');
    fprintf(fid, '=============================================================\n\n');
    fprintf(fid, 'Dataset folder:\n%s\n\n', outputFolder);
    fprintf(fid, 'Number of healthy runs: %d\n', targetAccepted);
    fprintf(fid, 'Model used: %s\n', modelName);
    fprintf(fid, 'Sample time: %.6f s\n', dt);
    fprintf(fid, 'Sample rate: %.1f Hz\n', sample_rate);
    fprintf(fid, 'Startup ignored for quality metrics: %.2f s\n\n', startup_ignore_s);

    fprintf(fid, 'Joint order:\n');
    for j = 1:numel(joint_order)
        fprintf(fid, '  %d. %s\n', j, joint_order{j});
    end

    fprintf(fid, '\nEach .mat file contains one struct named data with fields:\n');
    fprintf(fid, '  condition, fault_type, joint_id, severity, degradation_index\n');
    fprintf(fid, '  time\n');
    fprintf(fid, '  tau_actual, tau_expected, delta_tau\n');
    fprintf(fid, '  q_actual, dq_actual, current_actual\n');
    fprintf(fid, '  q_ref, dq_ref, ddq_ref\n');
    fprintf(fid, '  q_tracking_error_deg\n');
    fprintf(fid, '  metadata and quality fields\n\n');

    fprintf(fid, 'Healthy labels:\n');
    fprintf(fid, '  condition = healthy\n');
    fprintf(fid, '  fault_type = none\n');
    fprintf(fid, '  joint_id = 0\n');
    fprintf(fid, '  severity = 0\n');
    fprintf(fid, '  degradation_index = 0\n\n');

    fprintf(fid, 'Quality sanity limits used:\n');
    fprintf(fid, '  residual max abs limits [J1 J2 J3] Nm = [%.2f %.2f %.2f]\n', residual_max_limit_Nm);
    fprintf(fid, '  tracking max limits [J1 J2 J3] deg = [%.2f %.2f %.2f]\n', tracking_max_limit_deg);

    fclose(fid);
end