% Frozen quadratic-cubic BO candidate transferred to bistable Duffing.
root=fileparts(mfilename('fullpath'));
addpath(root);
selftest_duffing_transfer;
mode='pilot'; % pilot: 10 seeds/alpha; full: 100 seeds/alpha.
resumeDirectory=''; % Paste an interrupted output folder here to resume.
outputDirectory=run_duffing_transfer(mode,resumeDirectory);
fprintf('\nDuffing transfer output:\n%s\n',outputDirectory);
