Healthy Dataset Handoff — Digital Twin Predictive Maintenance
=============================================================

Dataset folder:
C:\Users\AMMAR\Documents\MATLAB\Digital twin Predictive maintenance\data\healthy_50

Number of healthy runs: 50
Model used: RobotFaultDetection_Phase1_step10_baseline_PASS
Sample time: 0.001000 s
Sample rate: 1000.0 Hz
Startup ignored for quality metrics: 0.50 s

Joint order:
  1. Joint1_Waist
  2. Joint2_Shoulder
  3. Joint3_Elbow

Each .mat file contains one struct named data with fields:
  condition, fault_type, joint_id, severity, degradation_index
  time
  tau_actual, tau_expected, delta_tau
  q_actual, dq_actual, current_actual
  q_ref, dq_ref, ddq_ref
  q_tracking_error_deg
  metadata and quality fields

Healthy labels:
  condition = healthy
  fault_type = none
  joint_id = 0
  severity = 0
  degradation_index = 0

Quality sanity limits used:
  residual max abs limits [J1 J2 J3] Nm = [2.00 3.00 2.00]
  tracking max limits [J1 J2 J3] deg = [3.00 8.00 8.00]
