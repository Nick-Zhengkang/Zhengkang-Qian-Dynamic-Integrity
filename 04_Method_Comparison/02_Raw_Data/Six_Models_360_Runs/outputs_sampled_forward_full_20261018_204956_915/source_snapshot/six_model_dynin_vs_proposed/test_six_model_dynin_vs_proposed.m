%% DynIn GA versus proposed adaptive-angle method on six benchmarks

clear;
clc;

scriptDirectory = fileparts(mfilename('fullpath'));
addpath(scriptDirectory,'-begin');

runMode = "full";  % "pilot" = 3 paired seeds, "full" = 30 paired seeds
if runMode == "full"
    seedList = 1:30;
else
    seedList = 1:3;
end

resumeDirectory = "";

outputDirectory = run_six_model_dynin_vs_proposed( ...
    runMode,seedList,resumeDirectory);

fprintf('\nSix-model comparison output:\n%s\n',outputDirectory);
