function result = train_fault_classifier(X, Y, opts)
%TRAIN_FAULT_CLASSIFIER  Train the one-vs-one RBF SVM and score it.
%
%   result = TRAIN_FAULT_CLASSIFIER(X, Y)
%   result = TRAIN_FAULT_CLASSIFIER(X, Y, HoldOut=0.2, Seed=42)
%
%   X : feature matrix, samples-by-features.
%   Y : class labels, one per row of X.
%
%   result is a struct with
%     .Model            the trained ECOC model
%     .Accuracy         overall test accuracy, percent
%     .Classes          the class labels, in order
%     .PerClassAccuracy accuracy per class, percent, NaN where the test split
%                       happens to contain none of that class
%     .TestIndices      logical index of the held-out rows
%
%   Extracted from SVM_classifier_training.m unchanged in substance: the same
%   normalisation, the same stratified hold-out, the same RBF learner with
%   BoxConstraint 1, KernelScale auto, Standardize on, and one-vs-one coding.
%   What is left behind in the script is the plotting and the saving, neither
%   of which belongs in something a test can call. Pass Seed to make the
%   partition reproducible.

    arguments
        X double {mustBeNonempty}
        Y
        opts.HoldOut (1,1) double {mustBeGreaterThan(opts.HoldOut,0), mustBeLessThan(opts.HoldOut,1)} = 0.2
        opts.Seed = []
    end

    if size(X, 1) ~= numel(Y)
        error("train_fault_classifier:LengthMismatch", ...
              "X has %d rows but Y has %d labels", size(X,1), numel(Y));
    end

    if ~isempty(opts.Seed)
        rng(opts.Seed);
    end

    Xn = normalize(X);
    Yc = categorical(Y(:));

    cv      = cvpartition(Yc, "HoldOut", opts.HoldOut);
    learner = templateSVM("KernelFunction", "rbf", ...
                          "BoxConstraint", 1, ...
                          "KernelScale", "auto", ...
                          "Standardize", true);

    model = fitcecoc(Xn(cv.training, :), Yc(cv.training), ...
                     "Learners", learner, "Coding", "onevsone");

    Ypred = predict(model, Xn(cv.test, :));
    Ytest = Yc(cv.test);

    classList = categories(Yc);
    perClass  = nan(numel(classList), 1);
    for c = 1:numel(classList)
        idx = Ytest == classList{c};
        if any(idx)
            perClass(c) = sum(Ypred(idx) == Ytest(idx)) / sum(idx) * 100;
        end
    end

    result = struct( ...
        "Model",            model, ...
        "Accuracy",         sum(Ypred == Ytest) / numel(Ytest) * 100, ...
        "Classes",          {classList}, ...
        "PerClassAccuracy", perClass, ...
        "TestIndices",      cv.test);
end
