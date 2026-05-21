function save_run(out, condition, joint_id, severity, notes)
%SAVE_RUN  Extract Robot_Sensors bus and save a structured .mat file.
%
%   save_run(out, 'healthy', 0, 0, 'Phase 0 baseline trajectory')
%   save_run(out, 'gear_wear', 2, 1, 'Shoulder gear wear, severity 1/3')
%
% Inputs:
%   out        - output of sim('GDOFrobot')
%   condition  - 'healthy' | 'gear_wear' | 'bearing' | 'joint_imbalance' | ...
%   joint_id   - 0 (healthy) or 1/2/3 (which joint has the fault)
%   severity   - 0 (healthy) or 1/2/3 (severity level)
%   notes      - free-text description saved alongside the data

    if nargin < 5, notes = ''; end

    % ---- Sanity checks ----
    if ~isempty(out.ErrorMessage)
        error('Simulation errored: %s', out.ErrorMessage);
    end
    if isempty(out.logsout)
        error('out.logsout is empty. Enable signal logging first.');
    end

    bus = out.logsout.getElement('Robot_Sensors').Values;
    j1  = bus.Joint1_Signals;
    j2  = bus.Joint2_Signals;
    j3  = bus.Joint3_Signals;

    % ---- Build data struct ----
    data = struct();
    data.time       = j1.q.Time;
    data.condition  = condition;
    data.joint_id   = joint_id;
    data.severity   = severity;
    data.notes      = notes;
    data.created    = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    data.q   = [j1.q.Data,      j2.q.Data,      j3.q.Data];
    data.dq  = [j1.qdot.Data,   j2.qdot.Data,   j3.qdot.Data];
    data.tau = [j1.torque.Data, j2.torque.Data, j3.torque.Data];

    % Current, if the bus includes it
    if isfield(j1, 'current')
        data.current = [j1.current.Data, j2.current.Data, j3.current.Data];
    else
        Kt = 0.1; eta = 0.9; N = 100;
        data.current = data.tau ./ (Kt * eta * N);
        data.notes   = [data.notes, ' | current computed post-hoc'];
    end

    % ---- Integrity checks ----
    [Nt, ~] = size(data.q);
    assert(Nt > 1000,               'Run too short (%d samples)', Nt);
    assert(~any(isnan(data.q(:))),  'NaN in q signal');
    assert(~any(isnan(data.tau(:))),'NaN in tau signal');

    % ---- Build filename ----
    if strcmpi(condition, 'healthy')
        folder = 'data/healthy';
    else
        folder = sprintf('data/faults/%s', condition);
    end
    if ~exist(folder, 'dir'); mkdir(folder); end

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename  = sprintf('%s/run_%s_j%d_sev%d_%s.mat', ...
                        folder, condition, joint_id, severity, timestamp);

    save(filename, 'data', '-v7.3');

    fprintf('Saved: %s\n', filename);
    fprintf('  Duration  : %.2f s (%d samples)\n', data.time(end), Nt);
    fprintf('  q range   : [%.2f .. %.2f] deg\n', rad2deg(min(data.q(:))), rad2deg(max(data.q(:))));
    fprintf('  tau range : [%.2f .. %.2f] Nm\n',  min(data.tau(:)), max(data.tau(:)));
end
