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
% Two-dimensional, physics-guided transfer study for the original DynIn GA.
% Run pilot first. Then use one stage at a time, keeping the previous
% choices frozen. Change model and alpha only after the rule is frozen.

model = 'quadratic_cubic'; % quadratic_cubic, bistable_duffing, cosine_quadratic_drag
alpha = 0.4;
stage = 'grid';           % pilot, grid, belt, Ts, periodic, budget, validate
seeds = 1:10;             % validation: use fresh seeds, e.g. 31:60
resumeDir = '';           % previous output folder to resume this exact run

cfg = struct();
cfg.beta = 0.005;         % fraction of the potential barrier for target cells
cfg.eta = 0.005;          % maximum normalized grid width
cfg.samplesPerPeriod = 125;
cfg.domainMargin = 0.20;
cfg.pilotMultiplier = 1; % raise to 2 if T -> 2T changes target labels
cfg.pilotConfirmed = true; % set true only after inspecting pilot_audit.csv
cfg.tfinal = 600;         % replace with a checked horizon from the pilot
cfg.repPeriodic = 10;
cfg.numberOfSteps = 100;
cfg.diagnosticAngles = 16;

outDir = run_experiment_C_2d_rule(model,alpha,stage,seeds,cfg,resumeDir);
fprintf('\nOutput directory:\n%s\n',outDir);
