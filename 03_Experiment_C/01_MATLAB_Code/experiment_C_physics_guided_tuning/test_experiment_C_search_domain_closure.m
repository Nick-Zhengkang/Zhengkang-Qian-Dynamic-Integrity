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
% First close the domain/search-range loop, then inspect the decision CSV.
here=fileparts(mfilename('fullpath')); addpath(here);
domainDiagnosticDir=fullfile(here,'outputs_domain_diagnostics_20260923_202423_727');
alphaValues=[0.2 0.7 1.0];
mode='validate'; % 'audit': geometry only; 'validate': geometry + trajectory probes.
resumeDir='';   % Paste outputs_search_domain_closure_* to resume.
outDir=run_experiment_C_search_domain_closure(domainDiagnosticDir,alphaValues,mode,resumeDir);
fprintf('\nSearch-domain closure output:\n%s\n',outDir);
