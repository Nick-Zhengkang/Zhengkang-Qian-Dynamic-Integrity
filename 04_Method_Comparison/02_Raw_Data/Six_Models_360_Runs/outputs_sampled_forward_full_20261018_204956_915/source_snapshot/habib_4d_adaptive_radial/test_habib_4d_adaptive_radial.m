%% Habib 4D Duffing-van der Pol + TMD benchmark
% Start with "pilot". Use "full" only after the pilot has no systematic
% unresolved classifications.

clear;
clc;

runMode = "pilot";   % "pilot" = 3 seeds, "full" = 30 seeds
mu1Values = 0.075;   % Habib example; e.g. [0.065 0.075 0.095]

if runMode == "full"
    seedList = 1:30;
else
    seedList = 1:3;
end

resumeDirectory = ""; % Put an existing output folder here to resume it.

outputDirectory = run_habib_4d_adaptive_radial_benchmark( ...
    runMode,mu1Values,seedList,resumeDirectory);

fprintf('\nExperiment output:\n%s\n',outputDirectory);

