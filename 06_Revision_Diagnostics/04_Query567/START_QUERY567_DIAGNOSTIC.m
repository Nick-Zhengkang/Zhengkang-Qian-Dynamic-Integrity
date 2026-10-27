% AI-assisted read-only diagnosis. No classification rule or threshold is changed.
packageDirectory=fileparts(mfilename('fullpath'));
options=struct;
repositoryDirectory=fileparts(fileparts(packageDirectory));
options.sourceResults=fullfile(fileparts(packageDirectory),'03_Negative_Cache_90', ...
    'results','20261028_040701_540');
options.originalArchive=fullfile(repositoryDirectory,'04_Method_Comparison','02_Raw_Data', ...
    'Six_Models_360_Runs','outputs_sampled_forward_full_20261018_204956_915');
options.outputRoot=fullfile(packageDirectory,'results');
options.queryId=567;
addpath(packageDirectory);
outputDirectory=diagnose_query567(options);
fprintf('\nResults saved in:\n%s\n',outputDirectory);
