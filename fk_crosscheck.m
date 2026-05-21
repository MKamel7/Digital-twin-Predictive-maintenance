function fk_crosscheck(out)
%FK_CROSSCHECK  Compare analytical forward kinematics against
%   Simscape Transform Sensor end-effector position.

    % --- Arm geometry from Data File (meters) ---
    d1 = 0.316;     % base height (shoulder axis from world)
    a2 = 0.35;      % Link1 length (shoulder → elbow)
    a3 = 0.25;      % Link2 length (elbow → tool)

    % --- Get joint angles ---
    bus = out.logsout.getElement('Robot_Sensors').Values;
    q   = [bus.Joint1_Signals.q.Data, ...
           bus.Joint2_Signals.q.Data, ...
           bus.Joint3_Signals.q.Data];
    t   = bus.Joint1_Signals.q.Time;

    % --- Analytical FK (standard 3-DOF arm) ---
    q1 = q(:,1); q2 = q(:,2); q3 = q(:,3);

    % Radial reach in shoulder plane
    r  = a2*cos(q2) + a3*cos(q2 + q3);
    z  = d1 + a2*sin(q2) + a3*sin(q2 + q3);

    % Rotate by waist angle to get world XYZ
    ee_analytic = [r.*cos(q1), r.*sin(q1), z];

% --- Get Simscape measurement ---
ee_ts  = out.logsout.getElement('ee_position').Values;
raw    = ee_ts.Data;                 % shape varies: [N x 3], [3 x N], or [3 x 1 x N]
raw    = squeeze(raw);               % collapses [3 x 1 x N] → [3 x N]

% Orient as [N x 3]
if size(raw,1) == 3 && size(raw,2) ~= 3
    ee_sim = raw';                   % [3 x N] → [N x 3]
elseif size(raw,1) ~= 3 && size(raw,2) == 3
    ee_sim = raw;                    % already [N x 3]
elseif size(raw,1) == 3 && size(raw,2) == 3
    % Ambiguous — use time length from ee_ts to disambiguate
    N = numel(ee_ts.Time);
    if size(raw,1) == N
        ee_sim = raw;                % [N x 3]
    else
        ee_sim = raw';               % [3 x N]
    end
else
    error('Unexpected ee_position shape: %s', mat2str(size(raw)));
end

    % --- Error ---
    err_mm = 1000 * (ee_sim - ee_analytic);

    fprintf('\n--- Forward Kinematics Cross-Check ---\n');
    fprintf('                    X(mm)    Y(mm)    Z(mm)\n');
    fprintf('  Mean error     : %7.2f  %7.2f  %7.2f\n', mean(err_mm));
    fprintf('  RMS error      : %7.2f  %7.2f  %7.2f\n', rms(err_mm));
    fprintf('  Max |error|    : %7.2f  %7.2f  %7.2f\n', max(abs(err_mm)));

    err_norm = sqrt(sum(err_mm.^2, 2));
    fprintf('  Max 3D dist    : %7.2f mm\n', max(err_norm));

    if max(err_norm) < 1
        fprintf('  ✓ PASS — all within 1 mm\n');
    elseif max(err_norm) < 10
        fprintf('  ⚠ WARNING — within 10 mm, check DH params\n');
    else
        fprintf('  ✗ FAIL — geometry mismatch, review Link lengths\n');
    end

    % --- Plot ---
    figure('Name','FK cross-check');
    subplot(2,1,1);
    plot(t, ee_analytic*1000,'--','LineWidth',1.2); hold on;
    plot(t, ee_sim*1000,'LineWidth',1.1);
    legend('X_{analytical}','Y_{analytical}','Z_{analytical}', ...
           'X_{sim}','Y_{sim}','Z_{sim}','Location','eastoutside');
    ylabel('mm'); title('End-effector position'); grid on;

    subplot(2,1,2);
    plot(t, err_mm,'LineWidth',1.2);
    legend('\DeltaX','\DeltaY','\DeltaZ');
    ylabel('error (mm)'); xlabel('t (s)');
    title('Analytical - Simscape'); grid on;
end
