% Runs the test classes that need neither Simulink, Simscape nor the bulk
% .mat run data, so they are safe on a clean checkout and in CI.
%
% The bulk runs are excluded by .gitignore with one sample kept per category,
% so anything that loads a dataset cannot run here. What is left is the pure
% computation: the trajectory generator and the feature extractor.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
cd(projectRoot);

% Path order matters here and is deliberate. addpath PREPENDS, so the LAST
% call wins. quintic_traj.m exists in four identical copies (the repository
% root plus models/FullSystem, models/Physical and models/Virtual, one beside
% each Simulink model). Adding the root last makes the root copy the one under
% test, rather than letting the resolution depend on the order of these lines.
% TestQuinticTrajCopiesAgree guards the copies against drifting apart.
addpath(fullfile(projectRoot, "models", "FullSystem"));
addpath(projectRoot);

testFiles = [
    "tests/TestQuinticTraj.m"
    "tests/TestQuinticTrajCopiesAgree.m"
    "tests/TestExtractFeaturesWindowed.m"
];

suites = cell(numel(testFiles), 1);
for idx = 1:numel(testFiles)
    suites{idx} = matlab.unittest.TestSuite.fromFile(fullfile(projectRoot, testFiles(idx)));
end

suite = [suites{:}];
results = run(suite);
assertSuccess(results);
