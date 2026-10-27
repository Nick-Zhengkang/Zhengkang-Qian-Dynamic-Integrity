% Original DynIn GA versus adaptive angular/radial search.
% Same sampled classification rules; Proposed uses one ode45 per trajectory.
% Original DynIn unchanged. NO energy tests or backward integration.
mode="full";                  % "pilot": 3 seeds; "full": 30; "smoke": 1
benchmark="all";               % or one model ID from the list below
resumeDirectory="";            % paste this study's output folder to resume
% quadratic_cubic
% bistable_duffing
% habib_unforced_duffing
% genda_cosine_quadratic_drag
% habib_vdp_tmd_4d
% separable_qc_bd_4d

root=fileparts(mfilename('fullpath'));
addpath(root,'-begin');
clear('run_sampled_forward_comparison','sampled_forward_options');
options=sampled_forward_options(mode);
options.benchmarks=benchmark;
% Use odd refinement factors; both methods receive the same values.
options.refinement2D=1;
options.refinement4D=1;
outputDirectory=run_sampled_forward_comparison(options,resumeDirectory);
fprintf('\nSampled single-ODE comparison output:\n%s\n',outputDirectory);

