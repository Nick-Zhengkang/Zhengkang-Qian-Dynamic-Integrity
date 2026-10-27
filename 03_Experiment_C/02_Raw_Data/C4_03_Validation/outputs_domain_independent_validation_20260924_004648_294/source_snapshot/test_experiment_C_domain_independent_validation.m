% Fresh, independent validation of the frozen energy-envelope domain rule.
here=fileparts(mfilename('fullpath'));
addpath(here);

domainDiagnosticDir=fullfile(here, ...
    'outputs_domain_diagnostics_20260923_041604_919');
alphaValues=[0.2 0.7 1.0];
resumeDir=''; % Set to an existing outputs_domain_independent_validation_* folder.

outDir=run_experiment_C_domain_independent_validation( ...
    domainDiagnosticDir,alphaValues,resumeDir);
fprintf('\nIndependent domain-validation output:\n%s\n',outDir);

