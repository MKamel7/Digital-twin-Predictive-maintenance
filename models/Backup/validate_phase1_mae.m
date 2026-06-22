%% validate_phase1_mae.m
% Phase 1 Step 9/10A — Validate Virtual Twin torque accuracy
%
% Main validation:
%   Joint 1 Waist     -> absolute MAE criterion because torque is near zero
%   Joint 2 Shoulder  -> percentage MAE criterion
%   Joint 3 Elbow     -> percentage MAE criterion
%
% Reason:
%   Joint 1 has very small mean torque because it rotates around a mostly
%   vertical axis. Therefore percentage error becomes artificially huge.
%
% Author: Ammar / Digital Twin Predictive Maintenance Project

clc;

%% --------------------------------------------------------
% 1) Locate healthy dataset folder
% ---------------------------------------------------------
healthyFolder = ...
    'C:\Users\AMMAR\Documents\MATLAB\Digital twin Predictive maintenance\models\Backup\data\healthy';

assert(exist(healthyFolder, 'dir') == 7, ...
    'Healthy folder does not exist: %s', healthyFolder);

% Use only the batch-generated healthy files
files = dir(fullfile(healthyFolder, 'run_healthy_H*.mat'));

assert(~isempty(files), ...
    'No batch healthy files found in: %s', healthyFolder);

fprintf('Using healthy dataset folder:\n%s\n\n', healthyFolder);

fprintf('Files selected for validation:\n');
for k = 1:numel(files)
    fprintf('  %s\n', files(k).name);
end
fprintf('\n');

%% --------------------------------------------------------
% 2) Validation settings
% ---------------------------------------------------------
startup_ignore_s = 0.5;

% Percentage requirement for shoulder and elbow
requirement_pct = 5.0;

% Absolute MAE requirement for waist
joint1_abs_limit = 0.5;    % Nm

jointNames = {'Joint1_Waist', 'Joint2_Shoulder', 'Joint3_Elbow'};

numRuns = numel(files);
numJoints = 3;

all_mae      = zeros(numRuns, numJoints);
all_mean_mag = zeros(numRuns, numJoints);
all_pct      = zeros(numRuns, numJoints);
all_rms      = zeros(numRuns, numJoints);
all_max_abs  = zeros(numRuns, numJoints);
all_pass     = false(numRuns, numJoints);

%% --------------------------------------------------------
% 3) Validate each healthy run
% ---------------------------------------------------------
fprintf('=== Phase 1 Step 9/10A — MAE Validation Per Run ===\n\n');

for k = 1:numRuns

    filePath = fullfile(files(k).folder, files(k).name);
    S = load(filePath);

    assert(isfield(S, 'data'), 'File does not contain data struct: %s', files(k).name);

    data = S.data;

    requiredFields = {'time','tau_actual','tau_expected','delta_tau'};
    for r = 1:numel(requiredFields)
        assert(isfield(data, requiredFields{r}), ...
            'Missing field "%s" in file: %s', requiredFields{r}, files(k).name);
    end

    t = data.time;
    idx = t > startup_ignore_s;

    tau_act = data.tau_actual(idx, :);
    tau_exp = data.tau_expected(idx, :);

    residual = tau_act - tau_exp;

    mae      = mean(abs(residual), 1);
    mean_mag = mean(abs(tau_act), 1);
    pct      = (mae ./ mean_mag) * 100;
    rms_val  = rms(residual, 1);
    max_abs  = max(abs(residual), [], 1);

    all_mae(k,:)      = mae;
    all_mean_mag(k,:) = mean_mag;
    all_pct(k,:)      = pct;
    all_rms(k,:)      = rms_val;
    all_max_abs(k,:)  = max_abs;

    fprintf('Run %d/%d: %s\n', k, numRuns, files(k).name);

    if isfield(data, 'trajectory_id')
        fprintf('Trajectory: %s\n', data.trajectory_id);
    end

    for j = 1:numJoints

        if j == 1
            % Joint 1: use absolute MAE criterion
            pass_j = mae(j) <= joint1_abs_limit;
            all_pass(k,j) = pass_j;

            if pass_j
                status = "PASS";
            else
                status = "FAIL";
            end

            fprintf(['  %-16s | MAE = %.4f Nm | Mean|tau| = %.4f Nm | ', ...
                     'Error = %.2f%% | RMS = %.4f Nm | Max = %.4f Nm | ', ...
                     'Criterion: MAE < %.2f Nm | %s\n'], ...
                jointNames{j}, mae(j), mean_mag(j), pct(j), ...
                rms_val(j), max_abs(j), joint1_abs_limit, status);

        else
            % Joint 2 and Joint 3: use percentage MAE criterion
            pass_j = pct(j) <= requirement_pct;
            all_pass(k,j) = pass_j;

            if pass_j
                status = "PASS";
            else
                status = "FAIL";
            end

            fprintf(['  %-16s | MAE = %.4f Nm | Mean|tau| = %.4f Nm | ', ...
                     'Error = %.2f%% | RMS = %.4f Nm | Max = %.4f Nm | ', ...
                     'Criterion: Error < %.1f%% | %s\n'], ...
                jointNames{j}, mae(j), mean_mag(j), pct(j), ...
                rms_val(j), max_abs(j), requirement_pct, status);
        end
    end

    fprintf('\n');
end

%% --------------------------------------------------------
% 4) Overall summary across all healthy runs
% ---------------------------------------------------------
mean_mae   = mean(all_mae, 1);
worst_mae  = max(all_mae, [], 1);

mean_pct   = mean(all_pct, 1);
worst_pct  = max(all_pct, [], 1);

mean_rms   = mean(all_rms, 1);
worst_max  = max(all_max_abs, [], 1);

fprintf('\n=== Overall Phase 1 MAE Validation Summary ===\n');

overall_pass = true;

for j = 1:numJoints

    if j == 1
        pass_j = worst_mae(j) <= joint1_abs_limit;

        if pass_j
            status = "PASS";
        else
            status = "FAIL";
            overall_pass = false;
        end

        fprintf(['%-16s | Avg MAE = %.4f Nm | Worst MAE = %.4f Nm | ', ...
                 'Avg Error = %.2f%% | Worst Error = %.2f%% | ', ...
                 'Avg RMS = %.4f Nm | Worst Max = %.4f Nm | ', ...
                 'Criterion: Worst MAE < %.2f Nm | %s\n'], ...
            jointNames{j}, mean_mae(j), worst_mae(j), ...
            mean_pct(j), worst_pct(j), mean_rms(j), worst_max(j), ...
            joint1_abs_limit, status);

    else
        pass_j = worst_pct(j) <= requirement_pct;

        if pass_j
            status = "PASS";
        else
            status = "FAIL";
            overall_pass = false;
        end

        fprintf(['%-16s | Avg MAE = %.4f Nm | Worst MAE = %.4f Nm | ', ...
                 'Avg Error = %.2f%% | Worst Error = %.2f%% | ', ...
                 'Avg RMS = %.4f Nm | Worst Max = %.4f Nm | ', ...
                 'Criterion: Worst Error < %.1f%% | %s\n'], ...
            jointNames{j}, mean_mae(j), worst_mae(j), ...
            mean_pct(j), worst_pct(j), mean_rms(j), worst_max(j), ...
            requirement_pct, status);
    end
end

%% --------------------------------------------------------
% 5) Final interpretation
% ---------------------------------------------------------
fprintf('\n=== Validation Interpretation ===\n');

fprintf(['Joint 1 Waist is evaluated using absolute MAE because its mean torque ', ...
         'is close to zero, making percentage error physically misleading.\n']);

fprintf(['Joint 2 Shoulder and Joint 3 Elbow are evaluated using the standard ', ...
         'percentage MAE criterion.\n\n']);

if overall_pass
    fprintf('OVERALL RESULT: PASS\n');
    fprintf('Virtual Twin validation is acceptable across all healthy trajectories.\n');
else
    fprintf('OVERALL RESULT: FAIL\n');
    fprintf('One or more joints exceeded the selected validation threshold.\n');
end

%% --------------------------------------------------------
% 6) Save validation report
% ---------------------------------------------------------
validation = struct();

validation.files = {files.name};
validation.healthyFolder = healthyFolder;
validation.startup_ignore_s = startup_ignore_s;

validation.jointNames = jointNames;

validation.requirement_pct_for_joints_2_3 = requirement_pct;
validation.joint1_abs_limit_Nm = joint1_abs_limit;

validation.all_mae = all_mae;
validation.all_mean_mag = all_mean_mag;
validation.all_pct = all_pct;
validation.all_rms = all_rms;
validation.all_max_abs = all_max_abs;
validation.all_pass = all_pass;

validation.mean_mae = mean_mae;
validation.worst_mae = worst_mae;
validation.mean_pct = mean_pct;
validation.worst_pct = worst_pct;
validation.mean_rms = mean_rms;
validation.worst_max = worst_max;

validation.overall_pass = overall_pass;

validation.note = ['Joint1_Waist uses absolute MAE because mean torque is near zero; ', ...
                   'Joint2_Shoulder and Joint3_Elbow use percentage MAE.'];

validation.created_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');

reportFile = fullfile(healthyFolder, ...
    sprintf('phase1_mae_validation_modified_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));

save(reportFile, 'validation');

fprintf('\nValidation report saved:\n%s\n', reportFile);