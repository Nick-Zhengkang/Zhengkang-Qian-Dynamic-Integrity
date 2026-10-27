% Start with pilot. Change only mode to 'full' for the full preregistered budget.
scriptRoot=fileparts(mfilename('fullpath'));
addpath(scriptRoot);
options=ma_options('full');
options.useParallel=true;
options.numWorkers=[]; % Existing local process pool or local profile capacity.
resumeDirectory='';   % Paste an interrupted output folder here to resume.
selftest_multi_alpha_bayes;
outputDirectory=run_multi_alpha_bayes(options,resumeDirectory);
fprintf('\nMulti-alpha Bayesian output:\n%s\n',outputDirectory);
