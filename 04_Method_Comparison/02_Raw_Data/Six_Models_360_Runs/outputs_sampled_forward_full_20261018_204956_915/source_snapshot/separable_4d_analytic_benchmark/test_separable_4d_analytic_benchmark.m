%% Separable 4D benchmark with an exact analytical LIM

clear;
clc;

scriptDirectory = fileparts(mfilename('fullpath'));
addpath(scriptDirectory,'-begin');

runMode = "pilot";       % "pilot" = 3 seeds, "full" = 30 seeds
alphaQC = 0.4;
alphaBD = 0.7;

if runMode == "full"
    seedList = 1:30;
else
    seedList = 1:3;
end

resumeDirectory = "";

outputDirectory = run_separable_4d_analytic_benchmark( ...
    runMode,alphaQC,alphaBD,seedList,resumeDirectory);

fprintf('\nExperiment output:\n%s\n',outputDirectory);
