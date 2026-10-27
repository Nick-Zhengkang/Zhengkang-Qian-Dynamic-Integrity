% AI-assisted parfor diagnostic driver. Original experiment files are read-only.
% Open this script in MATLAB and press Run. No existing workspace is cleared.
options=struct;
packageDirectory=fileparts(mfilename('fullpath'));
repositoryDirectory=fileparts(fileparts(packageDirectory));
options.dataDirectory=fullfile(repositoryDirectory,'04_Method_Comparison','02_Raw_Data', ...
    'Six_Models_360_Runs','outputs_sampled_forward_full_20261018_204956_915');
options.outputRoot=fullfile(packageDirectory,'results');
% Three models x seeds 1:30; original control + ablation = 180 searches.
% Parallelism is across independent cases, never within a search or cache.
options.numWorkers=[]; % Use the existing local process pool, or profile default.
options.runBaselineControl=true;
% Post-search validation is outside the timed search and cannot update LIM.
options.independentValidation=true;
options.horizonFactors=[2,10];
options.validationRelTol=[1e-10,1e-12];
options.validationAbsTol=[1e-12,1e-13];
options.validationMaxStep=[0.2,0.1];
options.safetyStateLimit=50;
options.stopAtEnergyCertificate=true;
options.minimumValidationTime=200;
options.maxValidationQueriesPerCase=Inf;
addpath(packageDirectory);
outputDirectory=run_all90_parfor(options);
fprintf('\nResults saved in:\n%s\n',outputDirectory);
