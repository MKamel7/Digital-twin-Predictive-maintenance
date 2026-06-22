modelName = 'Robot_Phase1_PASS';
GDOFrobot_DataFile;
assignin('base', 'sim_payload_mass', 1.5);

fault_types    = {'healthy', 'gear_wear', 'bearing', 'joint_imbalance'};
joint_ids      = [1, 2, 3];
sev_list       = linspace(0.5, 1.0, 20);
payload_levels = [0.5, 1.5, 2.5];

sim_duration = 20.0;
dt_noise     = 0.001;
t_noise      = (0:dt_noise:sim_duration)';
assignin('base', 't_noise', t_noise);

fprintf('Starting Dataset Generation...\n');

for f_idx = 1:length(fault_types)
    current_fault = fault_types{f_idx};

    if strcmp(current_fault, 'healthy')
        j_list = 0;
    else
        j_list = joint_ids;
    end

    for j_idx = 1:length(j_list)
        current_joint = j_list(j_idx);

        for run = 1:length(sev_list)

            if strcmp(current_fault, 'healthy')
                deg_index = 0;
            else
                deg_index = sev_list(run);
            end

            current_payload  = payload_levels(mod(run-1, 3) + 1);
            assignin('base', 'sim_payload_mass', current_payload);

            enc_noise_signal = randn(length(t_noise), 3);
            assignin('base', 'enc_noise_signal', enc_noise_signal);

            set_fault(current_fault, current_joint, deg_index);
            pickplace_trajectory_edited;

            fprintf('Running %s | Joint %d | Sev %.2f | Payload: %.1f kg | Run %d/%d\n', ...
                current_fault, current_joint, deg_index, current_payload, run, length(sev_list));

            out = sim(modelName, 'SrcWorkspace', 'current');

            if strcmp(current_fault, 'healthy')
                filename = sprintf('data/healthy/run_healthy_%03d.mat', run);
            else
                filename = sprintf('data/faults/%s/run_%s_j%d_sev%.2f.mat', ...
                    current_fault, current_fault, current_joint, deg_index);
            end
            save(filename, 'out');
        end
    end
end
fprintf('\n=== DATASET GENERATION COMPLETE ===\n');