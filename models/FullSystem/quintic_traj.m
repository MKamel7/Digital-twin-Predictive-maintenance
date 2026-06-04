function [q, dq, ddq] = quintic_traj(q0, qf, T, t)
% QUINTIC_TRAJ  5th-order polynomial trajectory generator
%
%   Inputs:
%     q0  - start position (rad)
%     qf  - end position   (rad)
%     T   - segment duration (s)
%     t   - time vector (s), column vector
%
%   Outputs:
%     q   - position     (rad)
%     dq  - velocity     (rad/s)
%     ddq - acceleration (rad/s²)
%
%   Guarantees zero velocity AND zero acceleration at start and end.

    % Normalise time to [0,1]
    tau = t ./ T;
    tau = min(max(tau, 0), 1);   % clamp against floating-point overshoot

    % Quintic basis and its derivatives
    s   =  10*tau.^3 -  15*tau.^4 +   6*tau.^5;
    ds  = (30*tau.^2 -  60*tau.^3 +  30*tau.^4) ./ T;
    dds = (60*tau    - 180*tau.^2 + 120*tau.^3)  ./ T.^2;

    % Scale to actual joint range
    q   = q0 + (qf - q0) .* s;
    dq  =      (qf - q0) .* ds;
    ddq =      (qf - q0) .* dds;
end
