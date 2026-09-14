% Structural checks on the Simulink model.
%
% Separate from scripts/run_public_ci_checks.m because these need Simulink,
% Simscape and Simscape Multibody, which take several minutes to install on a
% CI runner. The public suite stays fast and product-free; this one guards the
% model interface that the dataset build depends on.
%
% The model is loaded, not simulated. A 20 s ode15s run over a Simscape
% Multibody arm costs minutes of CPU and would not add much confidence.

projectRoot = fileparts(fileparts(mfilename("fullpath")));
cd(projectRoot);
addpath(fullfile(projectRoot, "models", "FullSystem"));
addpath(projectRoot);

suite   = matlab.unittest.TestSuite.fromFile(fullfile(projectRoot, "tests/TestSimulinkModel.m"));
results = run(suite);
assertSuccess(results);
