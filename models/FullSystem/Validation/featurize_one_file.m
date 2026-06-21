function featStruct = featurize_one_file(motor, sensed, fs)
%FEATURIZE_ONE_FILE Compute the 90 hand-crafted SVM features for one run.
%   featStruct = FEATURIZE_ONE_FILE(motor, sensed, fs) replicates
%   step16_extract_balanced_features.m's add_signal_features /
%   simple_fft_features / band_energy exactly (copied verbatim, not
%   reimplemented), extracted into a standalone, GUI-callable function.
%
%   INPUT CONTRACT -- caller must trim before calling, matching step16
%   exactly: trim to data.time > data.startup_ignore_s BEFORE featurizing.
%   This function does NOT trim internally.
%     motor  - [N x 3] already-trimmed delta_tau_motor
%     sensed - [N x 3] already-trimmed delta_tau_sensed
%     fs     - scalar sample rate (Hz)
%
%   OUTPUT:
%     featStruct - struct with 90 named fields (motor_J1_mean, ...,
%                  sensed_J3_band_80_200). Look up by NAME against a
%                  trained model's featureVars list when assembling the
%                  ordered vector for predict() -- do not assume any
%                  positional order here. The training pipeline builds
%                  featureVars via setdiff(), which returns its result
%                  alphabetically sorted, not in this function's
%                  insertion order.

    featStruct = struct();
    featStruct = add_signal_features(featStruct, motor, fs, 'motor');
    featStruct = add_signal_features(featStruct, sensed, fs, 'sensed');
end


function featureStruct = add_signal_features(featureStruct, X, fs, prefix)

    for j = 1:3

        x = X(:,j);
        x = x(:);

        xMean = mean(x);
        xStd  = std(x);
        xRMS  = sqrt(mean(x.^2));
        xAbsMean = mean(abs(x));
        xMaxAbs = max(abs(x));
        xP2P = max(x) - min(x);

        if xRMS > eps
            crest = xMaxAbs / xRMS;
        else
            crest = 0;
        end

        xSkew = skewness(x);
        xKurt = kurtosis(x);

        fftFeat = simple_fft_features(x, fs);

        base = sprintf('%s_J%d_', prefix, j);

        featureStruct.([base 'mean']) = xMean;
        featureStruct.([base 'std']) = xStd;
        featureStruct.([base 'rms']) = xRMS;
        featureStruct.([base 'absmean']) = xAbsMean;
        featureStruct.([base 'maxabs']) = xMaxAbs;
        featureStruct.([base 'p2p']) = xP2P;
        featureStruct.([base 'crest']) = crest;
        featureStruct.([base 'skewness']) = xSkew;
        featureStruct.([base 'kurtosis']) = xKurt;

        featureStruct.([base 'dom_freq']) = fftFeat.dom_freq;
        featureStruct.([base 'dom_amp']) = fftFeat.dom_amp;
        featureStruct.([base 'band_0_5']) = fftFeat.band_0_5;
        featureStruct.([base 'band_5_25']) = fftFeat.band_5_25;
        featureStruct.([base 'band_25_80']) = fftFeat.band_25_80;
        featureStruct.([base 'band_80_200']) = fftFeat.band_80_200;
    end
end


function fftFeat = simple_fft_features(x, fs)

    x = x(:);
    x = x - mean(x);

    N = numel(x);

    if N < 10
        fftFeat.dom_freq = 0;
        fftFeat.dom_amp = 0;
        fftFeat.band_0_5 = 0;
        fftFeat.band_5_25 = 0;
        fftFeat.band_25_80 = 0;
        fftFeat.band_80_200 = 0;
        return;
    end

    n = (0:N-1)';
    w = 0.5 - 0.5*cos(2*pi*n/(N-1));

    xw = x .* w;

    Y = fft(xw);
    P2 = abs(Y / N);
    P1 = P2(1:floor(N/2)+1);
    P1(2:end-1) = 2*P1(2:end-1);

    f = fs*(0:floor(N/2))'/N;

    valid = f >= 0.5 & f <= 200;

    if any(valid)
        [domAmp, localIdx] = max(P1(valid));
        fv = f(valid);
        domFreq = fv(localIdx);
    else
        domAmp = 0;
        domFreq = 0;
    end

    fftFeat.dom_freq = domFreq;
    fftFeat.dom_amp = domAmp;
    fftFeat.band_0_5    = band_energy(f, P1, 0.5, 5);
    fftFeat.band_5_25   = band_energy(f, P1, 5, 25);
    fftFeat.band_25_80  = band_energy(f, P1, 25, 80);
    fftFeat.band_80_200 = band_energy(f, P1, 80, 200);
end


function e = band_energy(f, P, f1, f2)
    idx = f >= f1 & f < f2;

    if ~any(idx)
        e = 0;
    else
        e = sum(P(idx).^2);
    end
end
