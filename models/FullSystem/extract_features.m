function features = extract_features_windowed(residual, fs)
% residual: Nx3 matrix, fs: 1000 Hz
% Returns MxF matrix — M windows, F features

    window_sec = 1.0;      % 1 second windows
    overlap    = 0.5;      % 50% overlap
    win_len    = round(window_sec * fs);
    step       = round(win_len * (1 - overlap));
    N          = size(residual, 1);
    starts     = 1:step:(N - win_len + 1);
    features   = zeros(length(starts), 30);

    for w = 1:length(starts)
        idx     = starts(w):starts(w) + win_len - 1;
        seg     = residual(idx, :);
        feat    = [];

        for j = 1:3
            sig = seg(:, j);

            f_rms   = rms(sig);
            f_mean  = mean(abs(sig));
            f_std   = std(sig);
            f_kurt  = kurtosis(sig);
            f_crest = max(abs(sig)) / (rms(sig) + 1e-10);
            f_skew  = skewness(sig);

            Nw  = length(sig);
            fax = (0:floor(Nw/2)-1) * (fs/Nw);
            S   = abs(fft(sig));
            S   = S(1:floor(Nw/2));
            S2  = sum(S.^2);

            f_plow     = sum(S(fax <= 10).^2)              / S2;
            f_pmid     = sum(S(fax > 10 & fax <= 50).^2)  / S2;
            f_phigh    = sum(S(fax > 50 & fax <= 200).^2) / S2;
            f_centroid = sum(fax .* S') / sum(S);

            feat = [feat, f_rms, f_mean, f_std, f_kurt, ...
                    f_crest, f_skew, f_plow, f_pmid, f_phigh, f_centroid];
        end

        features(w, :) = feat;
    end
end