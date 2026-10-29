% AI-assisted diagnostic code, written to the author's diagnostic specification.
% Only replays frozen queries and independently checks selected states.
% No original search, classifier, settings or numerical records are modified.
root = fileparts(mfilename('fullpath'));
addpath(root);
options = struct;
options.seeds = 1:30;
options.useParallel = true;
options.numWorkers = 4;
options.validateEndpoints = true;
options.validateLabelChain = true;
options.verboseEvery = 50;
options.validationHorizons = [2400,12000];
options.validationRelTol = [1e-10,1e-12];
options.validationAbsTol = [1e-12,1e-13];
options.validationMaxStep = [0.2,0.1];
options.minimumValidationTime = 200;
options.safetyStateLimit = 50;
run_separable4d_diagnostic(root,options);
