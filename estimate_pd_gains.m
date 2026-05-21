% =========================================================
%  ESTIMATE_PD_GAINS.M
%  Computes worst-case effective inertia per joint, then
%  gives PD starting gains from a chosen natural frequency.
% =========================================================
clc; clear;

% --- Masses (kg) from GDOFrobot_DataFile.m -----------------
m_shoulderHouse = 1.6378;   % Solid 1  "base_joint"  (rotates with J1)
m_Link2         = 2.2751;   % Solid 2  "Link2"       (forearm)
m_Link1         = 3.2557;   % Solid 4  "Link1"       (upper arm)

% --- CoM-frame inertias (kg·m²) from the same file --------
%       [Ixx Iyy Izz]  after converting kg*mm^2 -> kg*m^2 (×1e-6)
I_shoulderHouse = [11419.5, 6706.3, 9789.2] * 1e-6;
I_Link1         = [41973.1, 17704.4, 29793.8] * 1e-6;
I_Link2         = [25511.5, 25390.8, 2610.9] * 1e-6;

% --- Link geometry (m) estimated from Rigid Transforms -----
L1 = 0.35;     % shoulder → elbow length  (Link1)
L2 = 0.25;     % elbow    → tool length   (Link2)

% Distances from each joint axis to the CoM of downstream bodies
% (worst case: arm fully extended horizontally)
r_L1_from_shoulder = 0.175;          % ~ half of Link1
r_L2_from_shoulder = L1 + 0.125;     % reach + half of Link2
r_L2_from_elbow    = 0.125;          % half of Link2

% Radial distance from the waist vertical axis (worst case)
r_L1_from_waist = 0.175;
r_L2_from_waist = L1 + 0.125;

%% ---- JOINT 3 (Elbow) ------------------------------------
% Rotates Link2 only about a horizontal axis.
% Use the largest transverse inertia of Link2 as worst case.
I_J3 = max(I_Link2(1), I_Link2(2)) ...
     + m_Link2 * r_L2_from_elbow^2;

%% ---- JOINT 2 (Shoulder) ---------------------------------
% Rotates Link1 + Link2 about a horizontal axis.
I_J2 = max(I_Link1(1), I_Link1(2)) + m_Link1 * r_L1_from_shoulder^2 ...
     + max(I_Link2(1), I_Link2(2)) + m_Link2 * r_L2_from_shoulder^2;

%% ---- JOINT 1 (Waist) ------------------------------------
% Rotates everything about the vertical (Z) axis.
I_J1 = I_shoulderHouse(3) ...
     + I_Link1(3) + m_Link1 * r_L1_from_waist^2 ...
     + I_Link2(3) + m_Link2 * r_L2_from_waist^2;

I_eff = [I_J1, I_J2, I_J3];       % worst-case inertias

%% ---- Bandwidth choice -----------------------------------
% Small/medium arm → 12–20 rad/s is a safe, non-aggressive start.
wn   = [15, 15, 20];              % rad/s per joint
zeta = 0.7;                       % slightly under-damped

Kp = I_eff .* wn.^2;
Kd = 2 * zeta * sqrt(Kp .* I_eff);

% Saturation limit (must match the one inside pd_controller.m)
tau_max = [50, 50, 30];

%% ---- Report ---------------------------------------------
fprintf('\n====== PD GAIN ESTIMATE ======\n');
fprintf('%-10s %10s %10s %10s %10s %10s\n', ...
        'Joint','I_eff','wn','Kp','Kd','tau_max');
names = {'Waist','Shoulder','Elbow'};
for j = 1:3
    fprintf('%-10s %10.4f %10.1f %10.2f %10.3f %10.1f\n', ...
        names{j}, I_eff(j), wn(j), Kp(j), Kd(j), tau_max(j));
end
fprintf('\nCopy these into pd_controller.m:\n');
fprintf('  Kp = [%.2f, %.2f, %.2f];\n', Kp);
fprintf('  Kd = [%.3f, %.3f, %.3f];\n', Kd);
fprintf('  tau_sat = [%.1f, %.1f, %.1f];\n', tau_max);
fprintf('===============================\n');
