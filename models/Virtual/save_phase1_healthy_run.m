
% 2) Extract timeseries
% ---------------------------------------------------------
ts_tau_actual     = out.tau_actual;
ts_tau_expected   = out.tau_expected;
ts_delta_tau      = out.delta_tau;
ts_q_actual       = out.q_actual;
ts_dq_actual      = out.dq_actual;
ts_current_actual = out.current_actual;

% Optional reference logs
has_q_ref   = isprop(out, 'q_ref')   || isfield(out, 'q_ref');
has_dq_ref  = isprop(out, 'dq_ref')  || isfield(out, 'dq_ref');
has_ddq_ref = isprop(out, 'ddq_ref') || isfield(out, 'ddq_ref');

% ---------------------------------------------------------
% 3) Use delta_tau time as master time vector
% ---------------------------------------------------------
t = ts_delta_tau.Time;

tau_actual     = interp1(ts_tau_actual.Time,     ts_tau_actual.Data,     t, 'linear', 'extrap');
tau_expected   = interp1(ts_tau_expected.Time,   ts_tau_expected.Data,   t, 'linear', 'extrap');
delta_tau      = interp1(ts_delta_tau.Time,      ts_delta_tau.Data,      t, 'linear', 'extrap');
q_actual       = interp1(ts_q_actual.Time,       ts_q_actual.Data,       t, 'linear', 'extrap');
dq_actual      = interp1(ts_dq_actual.Time,      ts_dq_actual.Data,      t, 'linear', 'extrap');
current_actual = interp1(ts_current_actual.Time, ts_current_actual.Data, t, 'linear', 'extrap');

% If references were not logged from Simulink, use trajectory arrays directly
q_ref   = interp1(traj_q(:,1),   traj_q(:,2:4),   t, 'linear', 'extrap');
dq_ref  = interp1(traj_dq(:,1),  traj_dq(:,2:4),  t, 'linear', 'extrap');
ddq_ref = interp1(traj_ddq(:,1), traj_ddq(:,2:4), t, 'linear', 'extrap');

% ---------------------------------------------------------
% 4) Build structured data record
% ---------------------------------------------------------
data = struct();

% Metadata
data.condition    = 'healthy';
data.fault_type   = 'none';
data.joint_id     = 0;        % 0 = healthy, no faulty joint
data.severity     = 0;        % 0 = healthy
data.sample_time  = 0.001;    % from your trajectory script
data.sample_rate  = 1000;     % Hz
data.model_name   = modelName;
data.created_at   = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% Joint order
data.joint_order = {'Joint1_Waist', 'Joint2_Shoulder', 'Joint3_Elbow'};

% Signals
data.time           = t;
data.tau_actual     = tau_actual;
data.tau_expected   = tau_expected;
data.delta_tau      = delta_tau;
data.q_actual       = q_actual;
data.dq_actual      = dq_actual;
data.current_actual = current_actual;
data.q_ref          = q_ref;
data.dq_ref         = dq_ref;
data.ddq_ref        = ddq_ref;

% ---------------------------------------------------------
% 5) Quality checks
% ---------------------------------------------------------
requiredFields = {'tau_actual','tau_expected','delta_tau','q_actual','dq_actual','current_actual'};

fprintf('\n=== Step 8 Dataset Quality Check ===\n');
fprintf('Samples: %d\n', length(data.time));
fprintf('Duration: %.3f s\n', data.time(end) - data.time(1));

for k = 1:numel(requiredFields)
    x = data.(requiredFields{k});
    fprintf('%-16s size: %d x %d | NaN: %d | Inf: %d\n', ...
        requiredFields{k}, size(x,1), size(x,2), any(isnan(x), 'all'), any(isinf(x), 'all'));
end

% Residual after startup transient
idx = data.time > 0.5;

fprintf('\nHealthy residual baseline after 0.5 s:\n');
for j = 1:3
    fprintf('Joint %d: mean = %.4f Nm | RMS = %.4f Nm | max abs = %.4f Nm\n', ...
        j, mean(data.delta_tau(idx,j)), rms(data.delta_tau(idx,j)), max(abs(data.delta_tau(idx,j))));
end

% ---------------------------------------------------------
% 6) Save file
% ---------------------------------------------------------
folder = fullfile('data', 'healthy');
if ~exist(folder, 'dir')
    mkdir(folder);
end

filename = fullfile(folder, sprintf('run_%s_j%d_s%d_%s.mat', ...
    data.condition, data.joint_id, data.severity, datestr(now, 'yyyymmdd_HHMMSS')));

save(filename, 'data');

fprintf('\nSaved healthy dataset:\n%s\n', filename);