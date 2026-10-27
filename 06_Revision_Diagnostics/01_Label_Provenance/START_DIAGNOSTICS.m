% AI-assisted diagnostic code, prepared for author review and execution.
% Open this file in MATLAB and press Run. Original experiments are read-only.
opts=struct;
scriptDirectory=fileparts(mfilename('fullpath'));
repositoryDirectory=fileparts(fileparts(scriptDirectory));
opts.dataDirectory=fullfile(repositoryDirectory,'04_Method_Comparison','02_Raw_Data', ...
    'Six_Models_360_Runs','outputs_sampled_forward_full_20261018_204956_915');
opts.outputRoot=fullfile(scriptDirectory,'results');

% Inventory all 90 saved runs. Default: three underestimated runs per model.
opts.selection="representative"; % Alternative: "all_underestimated"
opts.independentValidation=true;
opts.horizonFactors=[2,10];
opts.validationRelTol=[1e-10,1e-12];
opts.validationAbsTol=[1e-12,1e-13];
opts.validationMaxStep=[0.2,0.1];
opts.safetyStateLimit=50;
% Stop after >=200 time units if a model-specific energy trap is established.
% Set false to continue to the full horizon (unless the safety event fires).
opts.stopAtEnergyCertificate=true;
opts.minimumValidationTime=200;
opts.maxValidationQueriesPerCase=Inf;
opts.verboseEvery=250;

addpath(scriptDirectory);
outputDirectory=diagnose_lim_2d(opts);
fprintf('\nResults saved in:\n%s\n',outputDirectory);
