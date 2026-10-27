% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
function test_experiment_C_domain_read_table()
% Regression for a three-row manifest whose header was auto-detected wrongly.
file=[tempname '.csv']; cleanup=onCleanup(@()delete(file));
case_index=(1:3)'; alpha=[.2;.7;1];
case_directory=["C:\case_01";"C:\case_02";"C:\case_03"];
n_runs=[50;50;50]; n_completed=n_runs;
time_first_classifier_eligible=zeros(3,1); n_timing_review_flags=[0;1;0];
expected=table(case_index,alpha,case_directory,n_runs,n_completed, ...
    time_first_classifier_eligible,n_timing_review_flags);
writetable(expected,file);
actual=experiment_C_domain_read_table(file, ...
    ["case_index","alpha","case_directory"],["case_index","alpha"]);
assert(height(actual)==3 && isequal(actual.alpha,alpha));
assert(isequal(string(actual.case_directory),case_directory));
assert(isequal(actual.Properties.VariableNames,expected.Properties.VariableNames));
try
    experiment_C_domain_read_table(file,"missing_column");
    error('Test:MissingError','Missing-column validation did not fail.');
catch ME
    assert(strcmp(ME.identifier,'DynInDomain:CSVSchema'));
end
here=fileparts(mfilename('fullpath'));
realFile=fullfile(here,'outputs_duffing_transfer_20260923_003027_851','case_manifest.csv');
if isfile(realFile)
    actual=experiment_C_domain_read_table(realFile, ...
        ["case_index","alpha","case_directory"],["case_index","alpha"]);
    assert(height(actual)==3 && isequal(actual.alpha,alpha));
end
fprintf('CSV header, damping values, paths and schema checks passed.\n');
end
