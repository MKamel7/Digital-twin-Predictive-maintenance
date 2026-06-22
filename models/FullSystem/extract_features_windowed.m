function features = extract_features_windowed(residual, fs)
    % Skip first and last 2 seconds — transient/ramp-up period
    skip_samples = 2 * fs;
    residual = residual(skip_samples+1:end-skip_samples, :);

    window_sec = 1.0;
    overlap    = 0.5;
    win_len    = round(window_sec * fs);
    step       = round(win_len * (1 - overlap));
    N          = size(residual, 1);
    starts     = 1:step:(N - win_len + 1);
    features   = zeros(length(starts), 42);

    for w = 1:length(starts)
        idx  = starts(w):starts(w) + win_len - 1;
        seg  = residual(idx, :);
        feat = [];

        for j = 1:3
            sig = seg(:, j);

            f_rms   = rms(sig);
            f_mean  = mean(abs(sig)) + 1e-10;
            f_std   = std(sig);
            f_kurt  = kurtosis(sig);
            f_crest = max(abs(sig)) / (f_rms + 1e-10);
            f_skew  = skewness(sig);

            Nw  = length(sig);
            fax = (0:floor(Nw/2)-1) * (fs/Nw);
            S   = abs(fft(sig));
            S   = S(1:floor(Nw/2));
            S2  = sum(S.^2) + 1e-10;

            f_plow     = sum(S(fax <= 10).^2)              / S2;
            f_pmid     = sum(S(fax > 10 & fax <= 50).^2)  / S2;
            f_phigh    = sum(S(fax > 50 & fax <= 200).^2) / S2;
            f_centroid = sum(fax .* S') / (sum(S) + 1e-10);

            [~, peak_idx] = max(S);
            f_peak    = fax(peak_idx);

            S_norm    = S / (sum(S) + 1e-10);
            S_norm(S_norm < 1e-10) = 1e-10;
            f_entropy = -sum(S_norm .* log(S_norm));

            f_shape   = f_rms / f_mean;
            f_impulse = max(abs(sig)) / f_mean;

            feat = [feat, f_rms, f_mean, f_std, f_kurt, ...
                    f_crest, f_skew, f_plow, f_pmid, f_phigh, f_centroid, ...
                    f_peak, f_entropy, f_shape, f_impulse];
        end

        features(w, :) = feat;
    end
end