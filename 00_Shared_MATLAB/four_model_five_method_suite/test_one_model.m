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
% EDIT THIS MODEL NAME, then press Run. Exactly one model per invocation.
benchmark_name = 'genda_cosine_quadratic_drag';
% Choices: 'quadratic_cubic', 'bistable_duffing',
%          'paper_unforced_duffing', 'genda_cosine_quadratic_drag'
seed_list = 1:3;
switch benchmark_name
    case 'quadratic_cubic'
        alpha_list = 0.1:0.1:0.9;
    case 'bistable_duffing'
        alpha_list = 0.1:0.1:1.0;
    case {'paper_unforced_duffing','genda_cosine_quadratic_drag'}
        alpha_list = 0.05;
    otherwise
        error('Unknown benchmark_name.');
end
suite_dir = fileparts(mfilename('fullpath'));
addpath(suite_dir,'-begin');
outDir = run_four_model_benchmark(benchmark_name,alpha_list,seed_list);
fprintf('\nSend this file for analysis:\n%s\n',fullfile(outDir,'raw_data_all_runs.csv'));
