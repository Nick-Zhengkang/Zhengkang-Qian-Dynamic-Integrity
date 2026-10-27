% Open this file in MATLAB and press Run. No original DynIn files are changed.
here=fileparts(mfilename('fullpath'));
addpath(here);

mode='develop';             % develop: seeds 1:10; confirm: 31:60; smoke: 1
alphaValues=[0.2 0.7 1.0];  % Use 0.7 alone to run just one damping case.
resumeDir='';               % Paste this suite's output directory to resume.

outDir=run_experiment_C_duffing_transfer(mode,alphaValues,resumeDir);
fprintf('\nDuffing transfer output:\n%s\n',outDir);
