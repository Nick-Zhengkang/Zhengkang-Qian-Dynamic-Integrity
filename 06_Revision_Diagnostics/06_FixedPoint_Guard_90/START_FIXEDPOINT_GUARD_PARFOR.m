% AI-assisted diagnostic driver. Open this file in MATLAB and press Run.
% Original experiment and previous diagnostic results are read-only inputs.
packageDirectory=fileparts(mfilename('fullpath'));
options=struct;
options.previousResults=fullfile(fileparts(packageDirectory), ...
    '03_Negative_Cache_90','results','20261028_040701_540');
options.outputRoot=fullfile(packageDirectory,'results');
options.numWorkers=4; % Existing local process pools are reused.
options.horizonFactors=[2,10];
options.validationRelTol=[1e-10,1e-12];
options.validationAbsTol=[1e-12,1e-13];
options.validationMaxStep=[0.2,0.1];
options.safetyStateLimit=50;
options.stopAtEnergyCertificate=true;
options.minimumValidationTime=200;
options.maxValidationQueriesPerCase=Inf;
addpath(packageDirectory);
outputDirectory=fpguard_launch(packageDirectory,options);
fprintf('\nResults saved in:\n%s\n',outputDirectory);
