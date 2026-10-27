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
% Experiment C: build a parameter-transfer rule for the original DynIn GA.
% Run one stage at a time. Read the pilot audit before freezing tfinal.

model = 'vdp_tmd';          % 'vdp_tmd' (4-D) or 'four_mass' (8-D)
caseValue = 0.075;          % mu1 for 4-D; lr for 8-D (normally 2.0)
stage = 'pilot';            % pilot, grid, Ts, periodic, budget, diagnostic, validate
seedList = 1:10;            % use 31:60 for independent validation
resumeDir = '';             % set to a previous output directory to resume

cfg = struct();
cfg.discr = 701;            % freeze after the grid stage
cfg.k = 3;                  % target-cell count; never below 3 here
cfg.Ts = 0.05;              % freeze after the Ts stage
cfg.tfinal = 2000;          % replace using a PASSED pilot; not a reference LIM
cfg.rep_periodic = 10;     % freeze after the periodic stage
cfg.number_of_steps = 40;  % freeze after the budget stage
cfg.pilot_max_T = 4000;    % raise if the first pilot is inconclusive
cfg.pilot_multiplier = 1;  % 2 doubles both pilot horizons

% The 8-D model starts with a larger grid and search budget. These are
% initial test controls, not parameters claimed to be reported by Habib.
if strcmp(model,'four_mass')
    caseValue = 2.0;
    cfg.discr = 1001;
    cfg.number_of_steps = 100;
end

outDir = run_experiment_C_transfer_rule(model,caseValue,stage,seedList,cfg,resumeDir);
fprintf('\nExperiment C output:\n%s\n',outDir);
