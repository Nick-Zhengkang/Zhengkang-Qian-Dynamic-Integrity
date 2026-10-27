% Domain-only regression diagnostics; original DynIn classification is unchanged.
here=fileparts(mfilename('fullpath'));
addpath(here);
sourceDir=fullfile(here,'outputs_duffing_transfer_20260923_003027_851');
alphaValues=[0.2 0.7 1.0]; % Set 0.7 to diagnose one case first.
resumeDir='';             % This new diagnostic output root, when resuming.
outDir=run_experiment_C_domain_diagnostics(sourceDir,alphaValues,resumeDir);
fprintf('\nDomain diagnostic output:\n%s\n',outDir);
