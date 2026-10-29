% AI-assisted test harness implementing the author's targeted repair request.
% Runs only this independent package; original experiments are never written.
root=fileparts(mfilename('fullpath'));
addpath(root,'-begin');
options=struct;
options.seeds=1:30;
options.numWorkers=4;
options.verboseEvery=100;
options.validationHorizons=[2400,12000];
options.validationRelTol=[1e-10,1e-12];
options.validationAbsTol=[1e-12,1e-13];
options.validationMaxStep=[0.2,0.1];
options.minimumValidationTime=200;
options.safetyStateLimit=50;
outputDirectory=run_retest4d(root,options);

