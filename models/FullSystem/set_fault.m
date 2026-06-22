function set_fault(fault_type_str, joint_id, deg_index)
    map = struct('healthy',0,'gear_wear',1,'bearing',2,'joint_imbalance',3);
    assignin('base', 'FAULT_TYPE',  map.(fault_type_str));
    assignin('base', 'FAULT_JOINT', joint_id);
    assignin('base', 'DEG_INDEX',   deg_index);
    assignin('base', 'GEAR_PARAMS', [6.0, 7.5, 3.0, 0.75, 28.0]);
    assignin('base', 'BEAR_PARAMS', [4.0, 3.0, 1.5, 35.0, 42.0, 55.0, 6.0]);
    assignin('base', 'IMB_PARAMS',  [5.0, 7.5, 2.5, 1.5]);
    fprintf('Fault set: %s | joint=%d | deg=%.3f\n', fault_type_str, joint_id, deg_index);
end