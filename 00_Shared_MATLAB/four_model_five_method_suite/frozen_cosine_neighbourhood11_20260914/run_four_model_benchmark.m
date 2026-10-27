function outDir=run_four_model_benchmark(benchmark_name,alpha_list,seed_list)
% Full-method comparison: preserve legacy GA, DynIn bisection and energy.
% Only the old proposed block is replaced by frozen adaptive-angle v1.
% Run test_one_model.m for the editable model selector and 30-seed defaults.
% Classifiers are intentionally NOT unified. See ORIGINAL_COMPARISON.md.
if nargin<1, benchmark_name='quadratic_cubic'; end
benchmark_name=char(benchmark_name);
assert(ismember(string(benchmark_name),["quadratic_cubic","bistable_duffing", ...
    "paper_unforced_duffing","genda_cosine_quadratic_drag"]),'Unknown benchmark.');
if nargin<2 || isempty(alpha_list)
    switch benchmark_name
        case 'quadratic_cubic', alpha_list=0.1:0.1:0.9;
        case 'bistable_duffing', alpha_list=0.1:0.1:1.0;
        otherwise, alpha_list=0.05;
    end
end
if nargin<3 || isempty(seed_list), seed_list=1:30; end
validateattributes(alpha_list,{'numeric'},{'vector','finite','positive'});
validateattributes(seed_list,{'numeric'},{'vector','integer','nonnegative','finite'});
alpha_list=alpha_list(:).'; seed_list=seed_list(:).';
if any(strcmp(benchmark_name,{'paper_unforced_duffing','genda_cosine_quadratic_drag'}))
    assert(isscalar(alpha_list) && abs(alpha_list-.05)<1e-12, ...
        'This fixed-paper benchmark uses damping parameter 0.05 only.');
elseif strcmp(benchmark_name,'quadratic_cubic')
    assert(all(alpha_list>=.1 & alpha_list<=.95),'Verified reference range: [0.1,0.95].');
else
    assert(all(alpha_list>=.1 & alpha_list<=1),'Verified reference range: [0.1,1].');
end
originalPath=path;
pathCleanup=onCleanup(@()path(originalPath)); %#ok<NASGU>

% Original DynIn pure-GA functions folder.
originalFunctionsDir = fullfile(fileparts(mfilename('fullpath')),'dynin_original');

% Baseline hyperparameters calibrated from earlier study.
coarse_discr = 169;
coarse_eq_cells = 15;

% Fine-GA baseline: globally reduce cell width by factor 4.
fine_refine_factor = 4;
fine_discr = (coarse_discr - 1)*fine_refine_factor + 1;
fine_eq_cells = coarse_eq_cells*fine_refine_factor;

% Shared GA and integration settings.
number_of_steps = 100;
Ts = 0.2;
tfinal = 1000;
num_gen = 10;

% Legacy correction constants retained for the unchanged energy classifier/helper settings.
correction_iter = 8;
correction_tfinal = 400;
correction_Ts = Ts;
correction_target_tol = 2e-2;
max_candidates_to_check = 12;
proposed_candidate_mode = 'LIM_critical_trajectory';

% Energy-informed active method settings.
energy_initial_queries = 24;
energy_active_queries = 50;
energy_candidate_pool_size = 4000;
energy_local_bisection_iter = 8;
energy_tfinal = tfinal;
energy_Ts = 0.1;
if strcmp(benchmark_name,'paper_unforced_duffing')
    energy_tfinal = 2000;
end

% The cosine benchmark from Genda's manuscript has a larger natural length
% scale than the polynomial examples because the neighboring saddles are at
% x = +/-pi.  These settings keep the original DynIn roles but adapt the
% search box and integration step to the pendulum-type phase plane.
if strcmp(benchmark_name,'genda_cosine_quadratic_drag')
    coarse_discr = 201;
    coarse_eq_cells = 7;
    fine_refine_factor = 3;
    fine_discr = (coarse_discr - 1)*fine_refine_factor + 1;
    fine_eq_cells = coarse_eq_cells*fine_refine_factor;
    number_of_steps = 120;
    Ts = 0.05;
    tfinal = 1200;
    num_gen = 10;
    correction_tfinal = 600;
    correction_Ts = Ts;
    correction_target_tol = 2e-2;
    max_candidates_to_check = 16;
    energy_tfinal = tfinal;
    energy_Ts = Ts;
    energy_candidate_pool_size = 5000;
end

% If true, continue after failed runs and store the failure message.
continue_on_failure = true;

%% -------------------- Paths and benchmark setup --------------------

if ~exist(fullfile(originalFunctionsDir,'compute_LIM_FP.m'),'file')
    error('Cannot find original DynIn compute_LIM_FP.m. Check originalFunctionsDir.');
end

scriptRoot = fileparts(mfilename('fullpath'));
if isempty(scriptRoot)
    scriptRoot = pwd;
end

timestamp = datestr(now,'yyyymmdd_HHMMSS_FFF');
outDir = fullfile(scriptRoot, ...
    ['outputs_four_model_five_method_' benchmark_name '_' timestamp]);
if ~isfolder(outDir)
    mkdir(outDir);
end

[xe0,spaceboundary,benchmarkLabel,saddleX] = benchmark_settings(benchmark_name);
weight = benchmark_weight(benchmark_name);

modelDir = fullfile(outDir,'model');
if ~isfolder(modelDir)
    mkdir(modelDir);
end
write_sistema_file(modelDir,benchmark_name);

restoredefaultpath;
rehash toolboxcache;
addpath(modelDir,'-begin');
addpath(originalFunctionsDir,'-begin');
addpath(fullfile(scriptRoot,'functions'),'-begin');
limbench.verify_freeze();
proposedCfg=limbench.defaults();
if strcmp(benchmark_name,'paper_unforced_duffing')
    proposedCfg.timeStages=[100 400 1200 2000];
end
save(fullfile(outDir,'proposed_frozen_settings.mat'),'proposedCfg');
baselineFiles=dir(fullfile(originalFunctionsDir,'*.m'));
baselineHashes=cell(numel(baselineFiles),2);
for k=1:numel(baselineFiles)
    p=fullfile(originalFunctionsDir,baselineFiles(k).name);
    baselineHashes(k,:)={baselineFiles(k).name,file_sha256(p)};
end
writetable(cell2table(baselineHashes,'VariableNames',{'file','sha256'}), ...
    fullfile(outDir,'dynin_source_hashes.csv'));

computePath = which('compute_LIM_FP');
sistemaPath = which('sistema');
fprintf('\n=== Full original baselines vs frozen adaptive-angle proposed ===\n');
fprintf('Benchmark: %s\n',benchmarkLabel);
fprintf('Original DynIn compute_LIM_FP:\n%s\n',computePath);
fprintf('sistema:\n%s\n',sistemaPath);
fprintf('Output folder:\n%s\n\n',outDir);

assert(strcmpi(strrep(computePath,'/','\'), ...
    strrep(fullfile(originalFunctionsDir,'compute_LIM_FP.m'),'/','\')), ...
    'Wrong compute_LIM_FP resolved: %s',computePath);

%% -------------------- Common DynIn arguments --------------------

args = struct();
args.tfinal = tfinal;
args.Ts = Ts;
args.weight = weight;
args.type_x0 = 1;
args.reltol = 1e-8;
args.abstol = 1e-8;
args.number_of_steps = number_of_steps;
args.num_fig = 9501;
args.plot_results = 0;
args.plot_results_final = 0;
args.spaceboundary = spaceboundary;
args.automatic = 1;
args.var1 = 1;
args.var2 = 2;
args.rep_fix_point = 40;
args.rep_periodic = 10;
args.min_periodic_radius = 0.005;
args.check_min_periodic = 0;
args.check_equilibrium = 1;
args.max_check_step = 10000;
args.divR = 40;
args.num_gen = num_gen;
args.num_crossover = 9;
args.selected_opt = 3;
args.newcomers = 8;
args.num_almost_clones = 2;
args.bis_iter_max = 5;
args.use_adaptive_grid = 0;
args.use_adaptive_refinement = 0;
args.use_boundary_bisection = 0;

%% -------------------- Run paired benchmark --------------------

rawRows = {};
runCounter = 0;
totalRuns = numel(alpha_list)*numel(seed_list);

originalPwd = pwd;
cleanupObj = onCleanup(@() cd(originalPwd)); %#ok<NASGU>
cd(originalFunctionsDir);
assert(strcmpi(strrep(which('sistema'),'/','\'), ...
    strrep(fullfile(modelDir,'sistema.m'),'/','\')), ...
    'Wrong sistema resolved after changing directory: %s',which('sistema'));
fprintf('Full-method comparison: original classifiers retained, no shared 3-second cap.\n');
fprintf('Only proposed uses its frozen internal budget and stopping rules.\n');

for ia = 1:numel(alpha_list)
    alpha = alpha_list(ia);
    par.alpha = alpha;
    par.a = 1;
    [reference,referenceAudit]=fourbench.reference(benchmark_name,alpha);
    R_ref=reference.R;
    writetable(referenceAudit,fullfile(outDir,sprintf('reference_audit_alpha_%g.csv',alpha)));
    proposedModel=fourbench.model(benchmark_name,alpha);
    assert(isequal(proposedModel.target,xe0) && isequal(proposedModel.weight,weight));
    save(fullfile(outDir,sprintf('model_settings_alpha_%g.mat',alpha)), ...
        'args','benchmark_name','alpha','reference','proposedCfg','proposedModel', ...
        'coarse_discr','fine_discr','coarse_eq_cells','fine_eq_cells');

    effectiveDynin=dynin_original_bisection_args(args,benchmark_name);
    save(fullfile(outDir,sprintf('effective_dynin_alpha_%g.mat',alpha)), ...
        'effectiveDynin','reference');
    fprintf('Reference type: %s\nSource: %s\n',reference.kind,reference.source);
    fprintf('\n===== alpha %.8f (%d/%d), reference LIM %.10f =====\n', ...
        alpha,ia,numel(alpha_list),R_ref);

    for iseed = 1:numel(seed_list)
        seed = seed_list(iseed);
        runCounter = runCounter + 1;
        fprintf('\n--- paired seed %d (%d/%d) ---\n',seed,runCounter,totalRuns);

        coarseFailure = '';
        fineFailure = '';
        dyninFailure = '';
        proposedFailure = '';
        energyFailure = '';
        OutL_coarse=struct(); OutL_fine=struct(); OutL_dynin=struct();

        %% Method 1: coarse_GA
        args_coarse = args;
        args_coarse.discr = coarse_discr;
        args_coarse.num_of_cell_around_equilibrium = coarse_eq_cells;
        args_coarse.num_fig = 10000 + runCounter;

        rng(seed,'twister');
        tStart = tic;
        try
            [R_coarse,OutL_coarse,OutH_coarse] = call_compute_LIM_FP_original(xe0,par,args_coarse); %#ok<ASGLU>
            runtime_coarse = toc(tStart);
            trajEval_coarse = estimate_trajectory_evaluations(OutL_coarse);
            coarseSuccess = isfinite(R_coarse);
        catch ME
            runtime_coarse = toc(tStart);
            R_coarse = NaN;
            OutL_coarse = struct();
            trajEval_coarse = NaN;
            coarseSuccess = false;
            coarseFailure = ME.message;
            fprintf('coarse_GA failed: %s\n',coarseFailure);
            if ~continue_on_failure
                rethrow(ME);
            end
        end

        rawRows(end+1,:) = make_raw_row(benchmark_name,alpha,seed,'coarse_GA', ...
            R_coarse,R_ref,runtime_coarse,trajEval_coarse,coarseSuccess,coarseFailure, ...
            coarse_discr,coarse_eq_cells,number_of_steps,Ts,num_gen,0,0, ...
            'none','none',false); %#ok<SAGROW>

        %% Method 2: fine_GA
        args_fine = args;
        args_fine.discr = fine_discr;
        args_fine.num_of_cell_around_equilibrium = fine_eq_cells;
        args_fine.num_fig = 20000 + runCounter;

        rng(seed,'twister');
        tStart = tic;
        try
            [R_fine,OutL_fine,OutH_fine] = call_compute_LIM_FP_original(xe0,par,args_fine); %#ok<ASGLU>
            runtime_fine = toc(tStart);
            trajEval_fine = estimate_trajectory_evaluations(OutL_fine);
            fineSuccess = isfinite(R_fine);
        catch ME
            runtime_fine = toc(tStart);
            R_fine = NaN;
            trajEval_fine = NaN;
            fineSuccess = false;
            fineFailure = ME.message;
            fprintf('fine_GA failed: %s\n',fineFailure);
            if ~continue_on_failure
                rethrow(ME);
            end
        end

        rawRows(end+1,:) = make_raw_row(benchmark_name,alpha,seed,'fine_GA', ...
            R_fine,R_ref,runtime_fine,trajEval_fine,fineSuccess,fineFailure, ...
            fine_discr,fine_eq_cells,number_of_steps,Ts,num_gen,0,0, ...
            'none','global_uniform_refinement',false); %#ok<SAGROW>

        %% Method 3: dynin_original_bisection
        args_dynin = dynin_original_bisection_args(args,benchmark_name);
        args_dynin.num_fig = 30000 + runCounter;
        save(fullfile(outDir,sprintf('baseline_args_alpha_%g_seed_%02d.mat',alpha,seed)), ...
            'args_coarse','args_fine','args_dynin');

        rng(seed,'twister');
        tStart = tic;
        try
            [R_dynin,OutL_dynin,OutH_dynin] = call_compute_LIM_FP_original(xe0,par,args_dynin); %#ok<ASGLU>
            runtime_dynin = toc(tStart);
            trajEval_dynin = estimate_trajectory_evaluations(OutL_dynin);
            dyninSuccess = isfinite(R_dynin);
        catch ME
            runtime_dynin = toc(tStart);
            R_dynin = NaN;
            trajEval_dynin = NaN;
            dyninSuccess = false;
            dyninFailure = ME.message;
            fprintf('dynin_original_bisection failed: %s\n',dyninFailure);
            if ~continue_on_failure
                rethrow(ME);
            end
        end

        rawRows(end+1,:) = make_raw_row(benchmark_name,alpha,seed,'dynin_original_bisection', ...
            R_dynin,R_ref,runtime_dynin,trajEval_dynin,dyninSuccess,dyninFailure, ...
            args_dynin.discr,args_dynin.num_of_cell_around_equilibrium, ...
            args_dynin.number_of_steps,args_dynin.Ts,args_dynin.num_gen,args_dynin.bis_iter_max,0, ...
            'DynIn_type_x0_2','original_DynIn_bisection',false); %#ok<SAGROW>

        %% Method 4: proposed_method (independent frozen angular search)
        rng(seed,'twister');
        tStart=tic;
        try
            [proposedResult,proposedHistory,proposedQueries]=limbench.proposed_four_models(proposedModel,proposedCfg);
            runtime_proposed_total=toc(tStart);
            R_proposed=proposedResult.R;
            trajEval_proposed=proposedResult.queries;
            proposedSuccess=isfinite(R_proposed);
            if ~proposedSuccess, proposedFailure=proposedResult.reason; end
        catch ME
            runtime_proposed_total=toc(tStart);
            R_proposed=NaN; trajEval_proposed=NaN; proposedSuccess=false;
            proposedFailure=ME.message;
            fprintf('proposed_method failed: %s\n',proposedFailure);
            if ~continue_on_failure, rethrow(ME); end
        end
        rawRows(end+1,:)=make_raw_row(benchmark_name,alpha,seed,'proposed_method', ...
            R_proposed,R_ref,runtime_proposed_total,trajEval_proposed,proposedSuccess,proposedFailure, ...
            NaN,NaN,proposedCfg.queryBudget,NaN,NaN,0,proposedCfg.maxDirections, ...
            'frozen_adaptive_angle_v1','near_origin_radial_bracketing',false); %#ok<SAGROW>
        if exist('proposedHistory','var')
            save(fullfile(outDir,sprintf('proposed_alpha_%g_seed_%02d.mat',alpha,seed)), ...
                'proposedResult','proposedHistory','proposedQueries','proposedCfg');
            writetable(proposedHistory,fullfile(outDir,sprintf('proposed_history_alpha_%g_seed_%02d.csv',alpha,seed)));
            writetable(proposedQueries,fullfile(outDir,sprintf('proposed_queries_alpha_%g_seed_%02d.csv',alpha,seed)));
            clear proposedHistory proposedQueries proposedResult
        end

        %% Method 5: energy_informed_method
        rng(seed,'twister');
        tStart = tic;
        energyInfo = default_correction_info();
        try
            [R_energy,energyInfo] = energy_informed_search( ...
                par,xe0,weight,benchmark_name,spaceboundary,saddleX, ...
                energy_tfinal,energy_Ts,correction_target_tol, ...
                energy_initial_queries,energy_active_queries,energy_candidate_pool_size,energy_local_bisection_iter);
            runtime_energy = toc(tStart);
            trajEval_energy = energyInfo.trajectory_evaluations;
            energySuccess = isfinite(R_energy);
            if ~energySuccess
                energyFailure = energyInfo.failure_message;
            end
        catch ME
            runtime_energy = toc(tStart);
            R_energy = NaN;
            trajEval_energy = NaN;
            energySuccess = false;
            energyFailure = ME.message;
            fprintf('energy_informed_method failed: %s\n',energyFailure);
            if ~continue_on_failure
                rethrow(ME);
            end
        end

        rawRows(end+1,:) = make_raw_row(benchmark_name,alpha,seed,'energy_informed_method', ...
            R_energy,R_ref,runtime_energy,trajEval_energy,energySuccess,energyFailure, ...
            coarse_discr,coarse_eq_cells,number_of_steps,Ts,num_gen,energy_local_bisection_iter,energy_candidate_pool_size, ...
            'saddle_energy_active_sampling','energy_layer_plus_boundary_uncertainty',false); %#ok<SAGROW>

        fprintf('seed %d summary: coarse %.6f, fine %.6f, dynin %.6f, proposed %.6f, energy %.6f, ref %.6f\n', ...
            seed,R_coarse,R_fine,R_dynin,R_proposed,R_energy,R_ref);
        checkpoint=fourbench.annotate(raw_rows_to_table(rawRows),reference);
        writetable(checkpoint,fullfile(outDir,'raw_data_all_runs.csv'));
        save(fullfile(outDir,sprintf('baseline_trace_alpha_%g_seed_%02d.mat',alpha,seed)), ...
            'OutL_coarse','OutL_fine','OutL_dynin','args_coarse','args_fine','args_dynin');
    end

    % Save a checkpoint after each alpha.
    rawDataCheckpoint = raw_rows_to_table(rawRows);
    writetable(rawDataCheckpoint,fullfile(outDir,'raw_data_checkpoint.csv'));
    save(fullfile(outDir,'checkpoint.mat'),'rawDataCheckpoint','alpha_list','seed_list','benchmark_name');
end

%% -------------------- Save raw data and summary --------------------

rawData = fourbench.annotate(raw_rows_to_table(rawRows),reference);
rawCsv = fullfile(outDir,'raw_data_all_runs.csv');
writetable(rawData,rawCsv);

summaryByMethod = fourbench.summarize(rawData,false);
summaryCsv = fullfile(outDir,'summary_by_method.csv');
writetable(summaryByMethod,summaryCsv);

summaryByAlphaMethod = fourbench.summarize(rawData,true);
summaryAlphaCsv = fullfile(outDir,'summary_by_alpha_and_method.csv');
writetable(summaryByAlphaMethod,summaryAlphaCsv);

save(fullfile(outDir,'genda_five_method_four_benchmark_results.mat'), ...
    'rawData','summaryByMethod','summaryByAlphaMethod','alpha_list','seed_list', ...
    'benchmark_name','args','coarse_discr','fine_discr','coarse_eq_cells','fine_eq_cells');

%% -------------------- Figures --------------------

figDir = fullfile(outDir,'figures');
if ~isfolder(figDir)
    mkdir(figDir);
end

fourbench.plot_results(rawData,summaryByAlphaMethod,figDir,benchmarkLabel);
fourbench.habib_check(rawData,outDir);

fprintf('\nDone.\n');
fprintf('Raw data:\n%s\n',rawCsv);
fprintf('Summary by method:\n%s\n',summaryCsv);
fprintf('Summary by alpha and method:\n%s\n',summaryAlphaCsv);
fprintf('Figures folder:\n%s\n',figDir);

%% =====================================================================
%% Local functions
%% =====================================================================

end

function [xe0,spaceboundary,label,saddleX] = benchmark_settings(benchmark_name)
    switch benchmark_name
        case 'quadratic_cubic'
            xe0 = [0 0];
            spaceboundary = [-1 -1 1 1];
            label = 'Quadratic-cubic potential';
            saddleX = 1.0;
        case 'bistable_duffing'
            xe0 = [-1 0];
            spaceboundary = [-2 -2 1 2];
            label = 'Bistable Duffing potential';
            saddleX = 0.0;
        case 'paper_unforced_duffing'
            a = 1;
            xe0 = [-1/sqrt(a) 0];
            spaceboundary = [-2 -2 2 2];
            label = 'Unforced Duffing oscillator from DynIn paper';
            saddleX = 0.0;
        case 'genda_cosine_quadratic_drag'
            xe0 = [0 0];
            spaceboundary = [-pi -8 pi 8];
            label = 'Genda cosine potential with quadratic drag';
            saddleX = pi;
        otherwise
            error('Unknown benchmark_name.');
    end
end

function weight = benchmark_weight(benchmark_name)
    switch benchmark_name
        case 'paper_unforced_duffing'
            weight = [4 1];
        case 'genda_cosine_quadratic_drag'
            weight = [1 1];
        otherwise
            weight = [1 1];
    end
end

function write_sistema_file(modelDir,benchmark_name)
    fid = fopen(fullfile(modelDir,'sistema.m'),'w');
    if fid < 0
        error('Could not create sistema.m.');
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

    switch benchmark_name
        case 'genda_cosine_quadratic_drag'
            fprintf(fid,'function xprime = sistema(~, x, par)\n');
            fprintf(fid,'    xprime = zeros(2,1);\n');
            fprintf(fid,'    xprime(1) = x(2);\n');
            fprintf(fid,'    xprime(2) = -par.alpha * abs(x(2)) * x(2) - sin(x(1));\n');
            fprintf(fid,'end\n');
            return
        case 'quadratic_cubic'
            fprintf(fid,'function xprime = sistema(~, x, par)\n');
            fprintf(fid,'    xprime = zeros(2,1);\n');
            fprintf(fid,'    xprime(1) = x(2);\n');
            fprintf(fid,'    xprime(2) = -par.alpha * abs(x(2)) * x(2) - x(1) + x(1)^2;\n');
        case 'bistable_duffing'
            fprintf(fid,'function xprime = sistema(~, x, par)\n');
            fprintf(fid,'    xprime = zeros(2,1);\n');
            fprintf(fid,'    xprime(1) = x(2);\n');
            fprintf(fid,'    xprime(2) = -par.alpha * abs(x(2)) * x(2) + x(1) - x(1)^3;\n');
        case 'paper_unforced_duffing'
            fprintf(fid,'function xprime = sistema(~, x, par)\n');
            fprintf(fid,'    xprime = zeros(2,1);\n');
            fprintf(fid,'    xprime(1) = x(2);\n');
            fprintf(fid,'    if ~isfield(par,''a''), par.a = 1; end\n');
            fprintf(fid,'    xprime(2) = -2 * par.alpha * x(2) + x(1) - par.a * x(1)^3;\n');
    end
    fprintf(fid,'end\n');
end

function [R_final,OutL,OutH] = call_compute_LIM_FP_original(xe0,par,args)
    vals = struct_to_name_value_pairs(args);
    [R_final,OutL,OutH] = compute_LIM_FP(xe0,par,vals{:});
end

function args_dynin = dynin_original_bisection_args(args,benchmark_name)
    args_dynin = args;
    args_dynin.type_x0 = 2;

    % type_x0 = 2 is sensitive to the model scale.  These settings keep the
    % original DynIn logic, but tune the grid/equilibrium belt/integration
    % window separately for each benchmark.
    switch benchmark_name
        case 'quadratic_cubic'
            args_dynin.number_of_steps = 120;
            args_dynin.discr = 401;
            args_dynin.num_of_cell_around_equilibrium = 12;
            args_dynin.tfinal = 1200;
            args_dynin.Ts = 0.05;
            args_dynin.divR = 55;
            args_dynin.num_gen = 8;
            args_dynin.bis_iter_max = 8;
            args_dynin.automatic = 1;
            args_dynin.reltol = 1e-8;
            args_dynin.abstol = 1e-9;
            args_dynin.check_equilibrium = 1;
            args_dynin.spaceboundary = [-1 -1 1 1];
            args_dynin.weight = [1 1];

        case 'bistable_duffing'
            args_dynin.number_of_steps = 120;
            args_dynin.discr = 401;
            args_dynin.num_of_cell_around_equilibrium = 12;
            args_dynin.tfinal = 1200;
            args_dynin.Ts = 0.05;
            args_dynin.divR = 55;
            args_dynin.num_gen = 8;
            args_dynin.bis_iter_max = 8;
            args_dynin.automatic = 1;
            args_dynin.reltol = 1e-8;
            args_dynin.abstol = 1e-9;
            args_dynin.check_equilibrium = 1;
            args_dynin.spaceboundary = [-2 -2 1 2];
            args_dynin.weight = [1 1];

        case 'paper_unforced_duffing'
            % Habib 2021 Table 1 domain, grid, Ts and ODE tolerances.
            % type_x0=2 and local budget are from the later DynIn tutorial.
            args_dynin.number_of_steps = 50;
            args_dynin.discr = 701;
            args_dynin.num_of_cell_around_equilibrium = 3;
            args_dynin.tfinal = 2000;
            args_dynin.Ts = 0.05;
            args_dynin.spaceboundary = [-2 -2 2 2];
            args_dynin.divR = 50;
            args_dynin.num_gen = 5;
            args_dynin.bis_iter_max = 5;
            args_dynin.automatic = 1;
            args_dynin.reltol = 1e-8;
            args_dynin.abstol = 1e-8;
            args_dynin.check_equilibrium = 1;

        case 'genda_cosine_quadratic_drag'
            % Original DynIn bisection aligned to the cosine-potential
            % phase-plane scale from Genda's manuscript.
            args_dynin.number_of_steps = 120;
            args_dynin.discr = 501;
            % Model-specific neighbourhood; original classification code unchanged.
            args_dynin.num_of_cell_around_equilibrium = 11;
            args_dynin.tfinal = 1200;
            args_dynin.Ts = 0.05;
            args_dynin.divR = 60;
            args_dynin.num_gen = 8;
            args_dynin.bis_iter_max = 8;
            args_dynin.automatic = 1;
            args_dynin.reltol = 1e-8;
            args_dynin.abstol = 1e-9;
            args_dynin.check_equilibrium = 1;
            args_dynin.spaceboundary = [-pi -8 pi 8];
            args_dynin.weight = [1 1];
            args_dynin.var1 = 1;
            args_dynin.var2 = 2;

        otherwise
            error('Unknown benchmark_name.');
    end

    args_dynin.use_adaptive_grid = 0;
    args_dynin.use_adaptive_refinement = 0;
    args_dynin.use_boundary_bisection = 0;
end

function vals = struct_to_name_value_pairs(args)
    f = fieldnames(args);
    vals = cell(1,2*numel(f));
    for k = 1:numel(f)
        vals{2*k-1} = f{k};
        vals{2*k} = args.(f{k});
    end
end

function vals = struct_to_original_optional_order(args,xe0)
    dim = numel(xe0);
    defaults = struct();
    defaults.tfinal = 1000;
    defaults.Ts = 0.05;
    defaults.weight = ones(1,dim);
    defaults.type_x0 = 1;
    defaults.reltol = 1e-6;
    defaults.abstol = 1e-6;
    defaults.number_of_steps = 50;
    defaults.num_of_cell_around_equilibrium = 3;
    defaults.num_fig = round(rand*10000);
    defaults.plot_results = 1;
    defaults.plot_results_final = 0;
    defaults.spaceboundary = [xe0-10,xe0+10];
    defaults.discr = 1001;
    defaults.automatic = 0;
    defaults.var1 = 1;
    defaults.var2 = 2;
    defaults.rep_fix_point = 40;
    defaults.rep_periodic = 10;
    defaults.min_periodic_radius = 0.005;
    defaults.check_min_periodic = 0;
    defaults.check_equilibrium = 1;
    defaults.max_check_step = 10000;
    defaults.divR = 40;
    defaults.num_gen = 5;
    defaults.num_crossover = 9;
    defaults.selected_opt = 3;
    defaults.newcomers = 8;
    defaults.num_almost_clones = 2;
    defaults.bis_iter_max = 5;

    f = fieldnames(args);
    for k = 1:numel(f)
        if isfield(defaults,f{k})
            defaults.(f{k}) = args.(f{k});
        end
    end

    order = {'tfinal','Ts','weight','type_x0','reltol','abstol','number_of_steps', ...
        'num_of_cell_around_equilibrium','num_fig','plot_results','plot_results_final', ...
        'spaceboundary','discr','automatic','var1','var2','rep_fix_point','rep_periodic', ...
        'min_periodic_radius','check_min_periodic','check_equilibrium','max_check_step', ...
        'divR','num_gen','num_crossover','selected_opt','newcomers','num_almost_clones','bis_iter_max'};

    vals = cell(size(order));
    for k = 1:numel(order)
        vals{k} = defaults.(order{k});
    end
end

function n = estimate_trajectory_evaluations(OutL)
    n = NaN;
    if isstruct(OutL)
        if isfield(OutL,'x0') && ~isempty(OutL.x0)
            n = size(OutL.x0,1);
        elseif isfield(OutL,'R') && ~isempty(OutL.R)
            n = numel(OutL.R);
        end
    end
end

function info = default_correction_info()
    info = struct();
    info.candidate_count = 0;
    info.trajectory_evaluations = 0;
    info.LIM_updated = false;
    info.failure_message = '';
    info.selected_iter = NaN;
    info.selected_point = [NaN NaN];
    info.closest_point = [NaN NaN];
    info.closest_distance = NaN;
end

function [R_best,info] = ordinary_radial_bisection_from_coarse(OutL,par,xe0,weight,R0,benchmark_name,spaceboundary,saddleX,nIter,tfinal,Ts,targetTol)
    info = default_correction_info();
    R_best = R0;

    if ~isfield(OutL,'tipo') || ~isfield(OutL,'x0')
        info.failure_message = 'OutL has no tipo/x0 fields';
        return;
    end

    idx = find(OutL.tipo(:)>1 & all(isfinite(OutL.x0),2));
    info.candidate_count = numel(idx);
    if isempty(idx)
        info.failure_message = 'No nonconverging initial conditions found';
        return;
    end

    X = OutL.x0(idx,:);
    d0 = sqrt(sum(((X - xe0).*sqrt(weight)).^2,2));
    [~,kbest] = min(d0);
    selectedIdx = idx(kbest);
    xOut = OutL.x0(selectedIdx,:);

    info.selected_iter = selectedIdx;
    info.selected_point = xOut;

    direction = xOut(:).' - xe0(:).';
    if norm(direction) < eps
        info.failure_message = 'Selected initial condition equals target';
        return;
    end
    direction = direction ./ normweight(direction,weight);

    rLow = 0.0;
    rHigh = normweight(xOut - xe0,weight);
    [labelHigh,~,dHigh,closestHigh] = classify_direct(xe0 + rHigh*direction,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
    info.trajectory_evaluations = info.trajectory_evaluations + 1;

    expandCount = 0;
    while labelHigh ~= 2 && expandCount < 8
        rHigh = 1.15*rHigh;
        [labelHigh,~,dHigh,closestHigh] = classify_direct(xe0 + rHigh*direction,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        info.trajectory_evaluations = info.trajectory_evaluations + 1;
        expandCount = expandCount + 1;
    end
    if labelHigh ~= 2
        info.failure_message = 'Could not bracket a nonconverging endpoint';
        return;
    end

    info.closest_point = closestHigh;
    info.closest_distance = dHigh;
    if dHigh < R_best
        R_best = dHigh;
        info.LIM_updated = true;
    end

    for it = 1:nIter
        rMid = 0.5*(rLow+rHigh);
        xMid = xe0 + rMid*direction;
        [labelMid,~,dMid,closestMid] = classify_direct(xMid,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        info.trajectory_evaluations = info.trajectory_evaluations + 1;

        if labelMid == 2
            rHigh = rMid;
            info.closest_point = closestMid;
            info.closest_distance = dMid;
            if dMid < R_best
                R_best = dMid;
                info.LIM_updated = true;
            end
        else
            rLow = rMid;
        end
    end
end

function [R_best,info] = proposed_critical_trajectory_polish_from_coarse(OutL,par,xe0,weight,R0,benchmark_name,spaceboundary,saddleX,nIter,tfinal,Ts,targetTol,maxCandidates)
    info = default_correction_info();
    R_best = R0;

    if strcmp(benchmark_name,'genda_cosine_quadratic_drag')
        [R_best,info] = proposed_cosine_first_exit_search( ...
            OutL,par,xe0,weight,R0,benchmark_name,spaceboundary,saddleX, ...
            nIter,tfinal,Ts,targetTol,maxCandidates);
        return
    end

    if ~isfield(OutL,'tipo') || ~isfield(OutL,'x0')
        info.failure_message = 'OutL has no tipo/x0 fields';
        return;
    end

    idxAll = find(OutL.tipo(:)>1 & all(isfinite(OutL.x0),2));
    info.candidate_count = numel(idxAll);
    if isempty(idxAll)
        info.failure_message = 'No nonconverging candidates found';
        return;
    end
    idx = idxAll(max(1,numel(idxAll)-maxCandidates+1):end);

    best = struct('found',false,'iter',NaN,'x0',[NaN NaN], ...
        'closest_point',[NaN NaN],'closest_distance',Inf);

    for k = 1:numel(idx)
        ii = idx(k);
        x0 = OutL.x0(ii,:);
        [label,~,dmin,closest] = classify_direct(x0,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        info.trajectory_evaluations = info.trajectory_evaluations + 1;
        if label == 2 && dmin < best.closest_distance
            best.found = true;
            best.iter = ii;
            best.x0 = x0;
            best.closest_point = closest;
            best.closest_distance = dmin;
        end
    end

    if ~best.found
        info.failure_message = 'No directly confirmed nonconverging critical candidate';
        return;
    end

    info.selected_iter = best.iter;
    info.selected_point = best.x0;
    info.closest_point = best.closest_point;
    info.closest_distance = best.closest_distance;

    direction = best.closest_point(:).' - xe0(:).';
    if norm(direction) < eps
        info.failure_message = 'Closest point equals target';
        return;
    end
    direction = direction ./ normweight(direction,weight);

    rLow = 0.80*R0;
    rHigh = R0;
    [labelLow,~,~,~] = classify_direct(xe0 + rLow*direction,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
    info.trajectory_evaluations = info.trajectory_evaluations + 1;
    [labelHigh,~,dHigh,closestHigh] = classify_direct(xe0 + rHigh*direction,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
    info.trajectory_evaluations = info.trajectory_evaluations + 1;

    expandCount = 0;
    while labelHigh ~= 2 && expandCount < 8
        rHigh = 1.15*rHigh;
        [labelHigh,~,dHigh,closestHigh] = classify_direct(xe0 + rHigh*direction,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        info.trajectory_evaluations = info.trajectory_evaluations + 1;
        expandCount = expandCount + 1;
    end
    if labelHigh ~= 2
        info.failure_message = 'Could not bracket a nonconverging endpoint';
        return;
    end

    if labelLow ~= 1
        info.failure_message = 'Low endpoint was not converging; continuing conservatively';
    end

    if dHigh < R_best
        R_best = dHigh;
        info.closest_point = closestHigh;
        info.closest_distance = dHigh;
        info.LIM_updated = true;
    end

    for it = 1:nIter
        rMid = 0.5*(rLow+rHigh);
        xMid = xe0 + rMid*direction;
        [labelMid,~,dMid,closestMid] = classify_direct(xMid,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        info.trajectory_evaluations = info.trajectory_evaluations + 1;

        if labelMid == 2
            rHigh = rMid;
            info.closest_point = closestMid;
            info.closest_distance = dMid;
            if dMid < R_best
                R_best = dMid;
                info.LIM_updated = true;
            end
        else
            rLow = rMid;
        end
    end
end

function [R_best,info] = proposed_cosine_first_exit_search(OutL,par,xe0,weight,R0,benchmark_name,spaceboundary,saddleX,nIter,tfinal,Ts,targetTol,maxCandidates)
    info = default_correction_info();
    R_best = NaN;

    rDomain = weighted_radius_to_domain_boundary(xe0,weight,spaceboundary);
    rMax = 0.98*rDomain;
    if isfinite(R0) && R0 > 0.5
        rMax = min(rMax,max(2.35,1.25*R0));
    end

    nCoarseAngles = 12;
    nFinePerBest = 7;
    nBestAngleCenters = 2;
    nCoarseBisect = max(5,nIter-2);
    nFineBisect = nIter+1;

    coarseAngles = linspace(0,2*pi,nCoarseAngles+1).';
    coarseAngles(end) = [];
    coarseAngles = coarseAngles + 2*pi*rand/nCoarseAngles;

    coarse = scan_cosine_angles(coarseAngles,rMax,par,xe0,weight,benchmark_name, ...
        spaceboundary,saddleX,nCoarseBisect,tfinal,Ts,targetTol);
    info.trajectory_evaluations = info.trajectory_evaluations + coarse.evals;
    info.candidate_count = numel(coarseAngles);

    good = find(isfinite(coarse.rcrit));
    if isempty(good)
        info.failure_message = 'No escaping direction found in coarse angular scan; returning coarse result';
        R_best = R0;
        return
    end

    [~,ord] = sort(coarse.rcrit(good),'ascend');
    nBestAngles = min(nBestAngleCenters,numel(ord));
    baseAngles = coarse.theta(good(ord(1:nBestAngles)));
    dTheta = 2*pi/nCoarseAngles;
    fineAngles = [];
    for k = 1:numel(baseAngles)
        fineAngles = [fineAngles; baseAngles(k) + linspace(-0.60*dTheta,0.60*dTheta,nFinePerBest).']; %#ok<AGROW>
    end
    fineAngles = mod(unique(round(fineAngles,12)),2*pi);

    fine = scan_cosine_angles(fineAngles,rMax,par,xe0,weight,benchmark_name, ...
        spaceboundary,saddleX,nFineBisect,tfinal,Ts,targetTol);
    info.trajectory_evaluations = info.trajectory_evaluations + fine.evals;
    info.candidate_count = info.candidate_count + numel(fineAngles);

    allTheta = [coarse.theta(:); fine.theta(:)];
    allR = [coarse.rcrit(:); fine.rcrit(:)];
    allExit = [coarse.exit_point; fine.exit_point];
    good = find(isfinite(allR));
    if isempty(good)
        info.failure_message = 'No escaping direction found after angular refinement; returning coarse result';
        R_best = R0;
        return
    end

    [R_best,kk] = min(allR(good));
    bestIdx = good(kk);
    direction = [cos(allTheta(bestIdx)),sin(allTheta(bestIdx))] ./ sqrt(weight);
    info.LIM_updated = isfinite(R0) && abs(R_best - R0) > 1e-12;
    info.selected_point = xe0 + R_best*direction;
    info.closest_point = allExit(bestIdx,:);
    info.closest_distance = R_best;
    info.failure_message = '';
end

function result = scan_cosine_angles(theta,rMax,par,xe0,weight,benchmark_name,spaceboundary,saddleX,nBisect,tfinal,Ts,targetTol)
    result.theta = theta(:);
    result.rcrit = NaN(numel(theta),1);
    result.exit_point = NaN(numel(theta),2);
    result.evals = 0;

    for k = 1:numel(theta)
        dir = [cos(theta(k)),sin(theta(k))] ./ sqrt(weight);
        rLow = 0;
        rHigh = rMax;
        [labelHigh,trajHigh] = classify_direct(xe0 + rHigh*dir,par,xe0,weight, ...
            benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        result.evals = result.evals + 1;
        if labelHigh ~= 2
            continue
        end

        exitPoint = trajHigh(end,:);
        for it = 1:nBisect
            rMid = 0.5*(rLow+rHigh);
            [labelMid,trajMid] = classify_direct(xe0 + rMid*dir,par,xe0,weight, ...
                benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
            result.evals = result.evals + 1;
            if labelMid == 2
                rHigh = rMid;
                exitPoint = trajMid(end,:);
            else
                rLow = rMid;
            end
        end

        result.rcrit(k) = rHigh;
        result.exit_point(k,:) = exitPoint;
    end
end

function [R_best,info] = energy_informed_search(par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol,nInitial,nBudget,nPool,nBisect)
    info = default_correction_info();
    info.failure_message = '';

    dim = numel(xe0);
    rDomain = weighted_radius_to_domain_boundary(xe0,weight,spaceboundary);
    rSearch = 0.95*rDomain;
    Ypool = random_weighted_ball(nPool,dim,rSearch);
    Xpool = xe0 + Ypool ./ sqrt(weight);
    keep = in_spaceboundary(Xpool,spaceboundary);
    Xpool = Xpool(keep,:);
    Ypool = Ypool(keep,:);

    labels = NaN(size(Xpool,1),1);
    dmins = NaN(size(Xpool,1),1);
    closest = NaN(size(Xpool,1),dim);
    energyPool = energy_generic(Xpool,par,benchmark_name);
    energyTarget = energy_generic(xe0,par,benchmark_name);
    energySaddle = energy_generic(saddle_state(benchmark_name,par),par,benchmark_name);

    nStructured = floor(0.60*nInitial);
    nRings = max(3,ceil(sqrt(nStructured)));
    nPerRing = max(4,ceil(nStructured/nRings));
    ringR = linspace(0.15*rSearch,0.95*rSearch,nRings);
    shellX = zeros(nRings*nPerRing,dim);
    kk = 0;
    for ir = 1:nRings
        ringY = random_sphere_directions(nPerRing,dim) * ringR(ir);
        for itheta = 1:nPerRing
            kk = kk + 1;
            shellX(kk,:) = xe0 + ringY(itheta,:) ./ sqrt(weight);
        end
    end
    shellX = shellX(1:kk,:);
    shellKeep = in_spaceboundary(shellX,spaceboundary);
    shellX = shellX(shellKeep,:);
    [~,shellIdx] = min(pdist2_local(Xpool,shellX),[],1);

    energyMismatch = abs(energyPool - energySaddle);
    [~,energyOrder] = sort(energyMismatch,'ascend');
    nEnergy = max(0,floor(0.25*nInitial));
    energyIdx = energyOrder(1:min(nEnergy,numel(energyOrder)));

    nRandom = max(0,nInitial-numel(shellIdx)-numel(energyIdx));
    randomIdx = randperm(size(Xpool,1),min(nRandom,size(Xpool,1)));
    queryIdx = unique([shellIdx(:); energyIdx(:); randomIdx(:)]);
    if numel(queryIdx) > nInitial
        queryIdx = queryIdx(1:nInitial);
    end

    for k = 1:numel(queryIdx)
        ii = queryIdx(k);
        [labels(ii),~,dmins(ii),closest(ii,:)] = classify_direct( ...
            Xpool(ii,:),par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        info.trajectory_evaluations = info.trajectory_evaluations + 1;
    end

    queried = isfinite(labels);

    for q = 1:nBudget
        safeIdx = labels == 1;
        unsafeIdx = labels == 2;
        if ~any(safeIdx) || ~any(unsafeIdx)
            ii = find(~queried,1,'first');
        else
            R_current = min(dmins(unsafeIdx),[],'omitnan');
            if ~isfinite(R_current)
                queriedR = sqrt(sum(Ypool(queried,:).^2,2));
                R_current = median(queriedR,'omitnan');
            end

            unq = find(~queried);
            if isempty(unq)
                break
            end

            pSafe = idw_safe_probability(Ypool(unq,:),Ypool(queried,:),double(labels(queried) == 1));
            pBoundary = 1 - abs(2*pSafe - 1);
            rUnq = sqrt(sum(Ypool(unq,:).^2,2));
            shellWidth = max(0.08*rSearch,0.18*R_current);
            shellScore = exp(-abs(rUnq - R_current)/shellWidth);

            energyScale = max(1e-6,0.12*max(abs(energySaddle-energyTarget),eps));
            energyScore = exp(-abs(energyPool(unq) - energySaddle)/energyScale);

            score = 0.45*energyScore + 0.35*pBoundary + 0.20*shellScore;
            [~,kk] = max(score);
            ii = unq(kk);
        end

        [labels(ii),~,dmins(ii),closest(ii,:)] = classify_direct( ...
            Xpool(ii,:),par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        info.trajectory_evaluations = info.trajectory_evaluations + 1;
        queried(ii) = true;
    end

    unsafeIdx = labels == 2 & isfinite(dmins);
    info.candidate_count = sum(isfinite(labels));
    if ~any(unsafeIdx)
        R_best = NaN;
        info.failure_message = 'No nonconverging energy-informed sample was found.';
        return
    end

    [R_best,idxBest] = min(dmins(unsafeIdx));
    unsafeList = find(unsafeIdx);
    idxUnsafe = unsafeList(idxBest);

    directionPoint = closest(idxUnsafe,:);
    yDir = (directionPoint - xe0).*sqrt(weight);
    if norm(yDir) <= eps
        return
    end
    yDir = yDir ./ norm(yDir);

    rLow = 2*targetTol;
    rHigh = sqrt(sum(((directionPoint - xe0).*sqrt(weight)).^2));
    if rHigh < rLow
        rHigh = R_best;
    end

    for it = 1:nBisect
        rMid = 0.5*(rLow+rHigh);
        xMid = xe0 + rMid*yDir./sqrt(weight);
        [labelMid,~,dMid] = classify_direct( ...
            xMid,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol);
        info.trajectory_evaluations = info.trajectory_evaluations + 1;
        if labelMid == 2
            rHigh = rMid;
            R_best = min(R_best,dMid);
            info.LIM_updated = true;
        else
            rLow = rMid;
        end
    end
end

function [label,traj,dmin,closest] = classify_direct(x0,par,xe0,weight,benchmark_name,spaceboundary,saddleX,tfinal,Ts,targetTol)
    tspan = 0:Ts:tfinal;
    opts = odeset('RelTol',1e-7,'AbsTol',1e-9, ...
        'Events',@(t,x) stop_event_generic(t,x,xe0,targetTol,saddleX,spaceboundary,benchmark_name));
    try
        [~,traj] = ode45(@(t,x) rhs_generic(t,x,par,benchmark_name),tspan,x0(:),opts);
    catch
        traj = x0(:).';
    end

    dist = sqrt(sum(((traj - xe0).*sqrt(weight)).^2,2));
    [dmin,idx] = min(dist);
    closest = traj(idx,:);

    escaped = ~in_spaceboundary(traj,spaceboundary);

    switch benchmark_name
        case 'quadratic_cubic'
            crossedWrongSide = traj(:,1) > saddleX;
        case 'bistable_duffing'
            crossedWrongSide = traj(:,1) > saddleX;
        case 'paper_unforced_duffing'
            crossedWrongSide = traj(:,1) > saddleX;
        case 'genda_cosine_quadratic_drag'
            crossedWrongSide = abs(traj(:,1)) > saddleX;
        otherwise
            crossedWrongSide = false(size(traj,1),1);
    end

    if any(escaped) || any(crossedWrongSide)
        label = 2;  % nonconverging for the selected target basin
    elseif any(dist < targetTol) || dist(end) < 2*targetTol
        label = 1;  % converging to target
    else
        if dist(end) < dist(1)
            label = 1;
        else
            label = 2;
        end
    end
end

function [value,isterminal,direction] = stop_event_generic(~,x,xe0,targetTol,saddleX,spaceboundary,benchmark_name)
    dTarget = norm(x(:).' - xe0(:).');
    switch benchmark_name
        case {'quadratic_cubic','bistable_duffing','paper_unforced_duffing'}
            sideValue = saddleX - x(1);
        case 'genda_cosine_quadratic_drag'
            sideValue = saddleX - abs(x(1));
        otherwise
            sideValue = Inf;
    end
    dim = numel(x);
    lowerValues = x(:) - spaceboundary(1:dim).';
    upperValues = spaceboundary(dim+1:2*dim).' - x(:);
    value = [dTarget - targetTol; sideValue; lowerValues; upperValues];
    isterminal = ones(numel(value),1);
    direction = -ones(numel(value),1);
end

function dx = rhs_generic(~,x,par,benchmark_name)
    switch benchmark_name
        case 'quadratic_cubic'
            dx = zeros(2,1);
            dx(1) = x(2);
            dx(2) = -par.alpha*abs(x(2))*x(2) - x(1) + x(1)^2;
        case 'bistable_duffing'
            dx = zeros(2,1);
            dx(1) = x(2);
            dx(2) = -par.alpha*abs(x(2))*x(2) + x(1) - x(1)^3;
        case 'paper_unforced_duffing'
            dx = zeros(2,1);
            dx(1) = x(2);
            if ~isfield(par,'a')
                par.a = 1;
            end
            dx(2) = -2*par.alpha*x(2) + x(1) - par.a*x(1)^3;
        case 'genda_cosine_quadratic_drag'
            dx = zeros(2,1);
            dx(1) = x(2);
            dx(2) = -par.alpha*abs(x(2))*x(2) - sin(x(1));
        otherwise
            error('Unknown benchmark_name.');
    end
end

function d = normweight(x,weight)
    d = sqrt(sum((x(:).').^2 .* weight(:).'));
end

function E = energy_generic(X,par,benchmark_name)
    if isvector(X)
        X = X(:).';
    end
    x = X(:,1);
    v = X(:,2);
    switch benchmark_name
        case 'quadratic_cubic'
            E = 0.5*v.^2 + 0.5*x.^2 - (1/3)*x.^3;
        case {'bistable_duffing','paper_unforced_duffing'}
            a = 1;
            if isfield(par,'a')
                a = par.a;
            end
            E = 0.5*v.^2 - 0.5*x.^2 + 0.25*a*x.^4;
        case 'genda_cosine_quadratic_drag'
            E = 0.5*v.^2 - cos(x);
        otherwise
            error('No energy model is defined for benchmark_name = %s',benchmark_name);
    end
end

function pSafe = idw_safe_probability(Yquery,Ytrain,labelsTrain)
    D = pdist2_local(Yquery,Ytrain);
    K = min(12,size(D,2));
    [Ds,idx] = sort(D,2,'ascend');
    Ds = Ds(:,1:K);
    idx = idx(:,1:K);
    localLabels = labelsTrain(idx);
    W = 1 ./ (Ds + 1e-9).^2;
    pSafe = sum(W.*localLabels,2) ./ sum(W,2);
end

function rDomain = weighted_radius_to_domain_boundary(xe0,weight,spaceboundary)
    dim = numel(xe0);
    lower = abs(xe0(:).' - spaceboundary(1:dim)).*sqrt(weight);
    upper = abs(spaceboundary(dim+1:2*dim) - xe0(:).').*sqrt(weight);
    rDomain = min([lower,upper]);
    if ~isfinite(rDomain) || rDomain <= 0
        rDomain = 1;
    end
end

function keep = in_spaceboundary(X,spaceboundary)
    dim = size(X,2);
    keep = true(size(X,1),1);
    for i = 1:dim
        keep = keep & X(:,i) >= spaceboundary(i) & X(:,i) <= spaceboundary(dim+i);
    end
end

function Y = random_weighted_ball(n,dim,radius)
    D = randn(n,dim);
    D = D ./ max(vecnorm(D,2,2),eps);
    rho = radius * rand(n,1).^(1/dim);
    Y = D .* rho;
end

function D = random_sphere_directions(n,dim)
    D = randn(n,dim);
    D = D ./ max(vecnorm(D,2,2),eps);
end

function xs = saddle_state(benchmark_name,par)
    switch benchmark_name
        case 'quadratic_cubic'
            xs = [1 0];
        case 'bistable_duffing'
            xs = [0 0];
        case 'paper_unforced_duffing'
            xs = [0 0];
        case 'genda_cosine_quadratic_drag'
            xs = [pi 0];
        otherwise
            error('Unknown benchmark_name.');
    end
    if nargin < 2 %#ok<INUSD>
    end
end

function D = pdist2_local(A,B)
    D = zeros(size(A,1),size(B,1));
    for j = 1:size(B,1)
        diff = A - B(j,:);
        D(:,j) = sqrt(sum(diff.^2,2));
    end
end

function R = analytical_LIM(benchmark_name,alpha)
    switch benchmark_name
        case 'quadratic_cubic'
            R = quadratic_cubic_reference_LIM(alpha);
        case 'bistable_duffing'
            [R,~,~] = bistable_duffing_reference_LIM(alpha);
        case 'paper_unforced_duffing'
            R = paper_unforced_duffing_reference_LIM(alpha);
        case 'genda_cosine_quadratic_drag'
            R = genda_cosine_quadratic_drag_reference_LIM(alpha);
        otherwise
            error('Unknown benchmark_name.');
    end
end

function row = make_raw_row(benchmark_name,alpha,seed,method,R_num,R_ref,runtime,trajectory_evaluations,success,failure_message, ...
        discr,eq_cells,number_of_steps,Ts,num_gen,correction_iterations,candidate_count,candidate_selection,correction_direction,LIM_updated)
    signed_error = R_num - R_ref;
    abs_error = abs(signed_error);
    unsafe_overestimation = signed_error > 0;
    row = {string(benchmark_name),alpha,seed,string(method),R_num,R_ref,signed_error,abs_error, ...
        runtime,trajectory_evaluations,logical(success),string(failure_message),logical(unsafe_overestimation), ...
        discr,eq_cells,number_of_steps,Ts,num_gen,correction_iterations,candidate_count, ...
        string(candidate_selection),string(correction_direction),logical(LIM_updated)};
end

function T = raw_rows_to_table(rows)
    varNames = {'benchmark','alpha','seed','method','R_num','R_ref','signed_error','absolute_error', ...
        'runtime_s','trajectory_evaluations','success','failure_message','unsafe_overestimation', ...
        'discr','num_of_cell_around_equilibrium','number_of_steps','Ts','num_gen', ...
        'correction_iterations','candidate_count','candidate_selection','correction_direction','LIM_updated'};
    if isempty(rows)
        T = cell2table(cell(0,numel(varNames)),'VariableNames',varNames);
    else
        T = cell2table(rows,'VariableNames',varNames);
    end
    T.comparison_profile=repmat("original_complete_methods",height(T),1);
    T.classifier=repmat("DynIn_original_grid",height(T),1);
    T.classifier(T.method=="energy_informed_method")="legacy_energy_direct_classifier";
    T.classifier(T.method=="proposed_method")="frozen_energy_trapping_classifier";
    T.proposed_version=repmat("",height(T),1);
    T.proposed_version(T.method=="proposed_method")="adaptive-angle-v1.0.0";
    T.timing_rule=repmat("outer_method_wall_time_no_reference_no_io",height(T),1);
end

function S = summarize_by_method(T)
    methods = unique(T.method,'stable');
    rows = {};
    for i = 1:numel(methods)
        m = methods(i);
        idx = T.method == m & T.success;
        err = T.signed_error(idx);
        abserr = T.absolute_error(idx);
        rt = T.runtime_s(idx);
        unsafe = T.unsafe_overestimation(idx);
        failRate = mean(~T.success(T.method == m));

        rows(end+1,:) = {m, sum(idx), mean(err,'omitnan'), std(err,'omitnan'), ...
            mean(abserr,'omitnan'), median(abserr,'omitnan'), sqrt(mean(err.^2,'omitnan')), ...
            max(err,[],'omitnan'), mean(unsafe,'omitnan'), mean(rt,'omitnan'), std(rt,'omitnan'), failRate}; %#ok<AGROW>
    end
    S = cell2table(rows,'VariableNames',{'method','n_success','mean_signed_error','std_signed_error', ...
        'mean_absolute_error','median_absolute_error','RMSE','max_overestimation', ...
        'unsafe_overestimation_rate','mean_runtime_s','std_runtime_s','failure_rate'});
end

function S = summarize_by_alpha_method(T)
    alphas = unique(T.alpha,'stable');
    methods = unique(T.method,'stable');
    rows = {};
    for ia = 1:numel(alphas)
        for im = 1:numel(methods)
            idxAll = T.alpha == alphas(ia) & T.method == methods(im);
            idx = idxAll & T.success;
            err = T.signed_error(idx);
            abserr = T.absolute_error(idx);
            rt = T.runtime_s(idx);
            unsafe = T.unsafe_overestimation(idx);
            rows(end+1,:) = {alphas(ia),methods(im),sum(idx), ...
                mean(T.R_ref(idx),'omitnan'), mean(T.R_num(idx),'omitnan'), ...
                mean(err,'omitnan'), mean(abserr,'omitnan'), sqrt(mean(err.^2,'omitnan')), ...
                max(err,[],'omitnan'), mean(unsafe,'omitnan'), mean(rt,'omitnan'), mean(~T.success(idxAll))}; %#ok<AGROW>
        end
    end
    S = cell2table(rows,'VariableNames',{'alpha','method','n_success','R_ref_mean','R_num_mean', ...
        'mean_signed_error','mean_absolute_error','RMSE','max_overestimation', ...
        'unsafe_overestimation_rate','mean_runtime_s','failure_rate'});
end

function plot_benchmark_figures(rawData,summaryAlpha,figDir,benchmarkLabel)
    methods = unique(rawData.method,'stable');
    alphas = unique(rawData.alpha,'stable');
    colors = lines(numel(methods));

    fig1 = figure('Color','w','Position',[80 100 1400 720]);
    hold on;
    Rref = arrayfun(@(a) mean(summaryAlpha.R_ref_mean(summaryAlpha.alpha==a),'omitnan'),alphas);
    plot(alphas,Rref,'k-','LineWidth',2.8,'DisplayName','Reference');
    for im = 1:numel(methods)
        vals = NaN(size(alphas));
        for ia = 1:numel(alphas)
            idx = summaryAlpha.alpha == alphas(ia) & summaryAlpha.method == methods(im);
            vals(ia) = summaryAlpha.R_num_mean(idx);
        end
        plot(alphas,vals,'o-','LineWidth',1.8,'Color',colors(im,:), ...
            'DisplayName',char(methods(im)));
    end
    grid on; box on;
    xlabel('\alpha'); ylabel('LIM');
    title([benchmarkLabel ': mean LIM over paired seeds']);
    legend('Location','best');
    saveas(fig1,fullfile(figDir,'F01_mean_LIM_vs_alpha.png'));

    fig2 = figure('Color','w','Position',[80 100 1400 720]);
    hold on;
    for im = 1:numel(methods)
        vals = NaN(size(alphas));
        for ia = 1:numel(alphas)
            idx = summaryAlpha.alpha == alphas(ia) & summaryAlpha.method == methods(im);
            vals(ia) = summaryAlpha.mean_absolute_error(idx);
        end
        plot(alphas,vals,'o-','LineWidth',1.8,'Color',colors(im,:), ...
            'DisplayName',char(methods(im)));
    end
    grid on; box on;
    xlabel('\alpha'); ylabel('mean absolute error');
    title([benchmarkLabel ': mean absolute error']);
    legend('Location','best');
    saveas(fig2,fullfile(figDir,'F02_mean_absolute_error_vs_alpha.png'));

    fig3 = figure('Color','w','Position',[80 100 1400 720]);
    hold on;
    yline(0,'k:','LineWidth',1.2);
    for im = 1:numel(methods)
        vals = NaN(size(alphas));
        for ia = 1:numel(alphas)
            idx = summaryAlpha.alpha == alphas(ia) & summaryAlpha.method == methods(im);
            vals(ia) = summaryAlpha.mean_signed_error(idx);
        end
        plot(alphas,vals,'o-','LineWidth',1.8,'Color',colors(im,:), ...
            'DisplayName',char(methods(im)));
    end
    grid on; box on;
    xlabel('\alpha'); ylabel('mean signed error');
    title([benchmarkLabel ': signed error, positive means unsafe overestimation']);
    legend('Location','best');
    saveas(fig3,fullfile(figDir,'F03_mean_signed_error_vs_alpha.png'));

    fig4 = figure('Color','w','Position',[80 100 1400 720]);
    hold on;
    for im = 1:numel(methods)
        vals = NaN(size(alphas));
        for ia = 1:numel(alphas)
            idx = summaryAlpha.alpha == alphas(ia) & summaryAlpha.method == methods(im);
            vals(ia) = summaryAlpha.mean_runtime_s(idx);
        end
        plot(alphas,vals,'o-','LineWidth',1.8,'Color',colors(im,:), ...
            'DisplayName',char(methods(im)));
    end
    grid on; box on;
    xlabel('\alpha'); ylabel('mean runtime (s)');
    title([benchmarkLabel ': runtime']);
    legend('Location','best');
    saveas(fig4,fullfile(figDir,'F04_mean_runtime_vs_alpha.png'));

    fig5 = figure('Color','w','Position',[80 100 1400 720]);
    hold on;
    for im = 1:numel(methods)
        idx = rawData.method == methods(im) & rawData.success;
        scatter(rawData.runtime_s(idx),rawData.absolute_error(idx),45,colors(im,:),'filled', ...
            'DisplayName',char(methods(im)));
    end
    grid on; box on;
    xlabel('runtime (s)'); ylabel('absolute error');
    title([benchmarkLabel ': error-runtime tradeoff, all paired runs']);
    legend('Location','best');
    saveas(fig5,fullfile(figDir,'F05_error_runtime_tradeoff.png'));

    fig6 = figure('Color','w','Position',[80 100 1400 720]);
    unsafeRates = NaN(numel(methods),1);
    for im = 1:numel(methods)
        idx = rawData.method == methods(im) & rawData.success;
        unsafeRates(im) = mean(rawData.unsafe_overestimation(idx),'omitnan');
    end
    bar(categorical(methods),unsafeRates);
    grid on; box on;
    ylabel('unsafe overestimation rate');
    title([benchmarkLabel ': fraction of runs with R_{num} > R_{ref}']);
    ylim([0 1]);
    saveas(fig6,fullfile(figDir,'F06_unsafe_overestimation_rate.png'));
end

%% -------------------- Analytical references --------------------

function R = quadratic_cubic_reference_LIM(alpha)
    alpha = double(alpha);
    r_int = interior_radius_quadratic_cubic(alpha);
    if alpha < 1
        r_end = endpoint_radius_quadratic_cubic(alpha);
        R = min(r_end,r_int);
    else
        R = r_int;
    end
end

function r = interior_radius_quadratic_cubic(alpha)
    f = @(x) alpha*p_plus_quadratic_cubic(x,alpha) - x.^2;
    xs = linspace(1e-8,1-1e-8,1200);
    fs = arrayfun(f,xs);
    idx = find(fs(1:end-1).*fs(2:end) <= 0,1,'first');
    if isempty(idx)
        [~,idx0] = min(abs(fs));
        xstar = xs(idx0);
    else
        xstar = fzero(f,[xs(idx),xs(idx+1)]);
    end
    pstar = p_plus_quadratic_cubic(xstar,alpha);
    r = sqrt(xstar.^2 + pstar);
end

function r = endpoint_radius_quadratic_cubic(alpha)
    f = @(x) p_plus_quadratic_cubic(x,alpha);
    xs = linspace(-4,-1e-8,2000);
    fs = arrayfun(f,xs);
    idx = find(fs(1:end-1).*fs(2:end) <= 0,1,'last');
    if isempty(idx)
        [~,idx0] = min(abs(fs));
        xL = xs(idx0);
    else
        xL = fzero(f,[xs(idx),xs(idx+1)]);
    end
    r = -xL;
end

function p = p_plus_quadratic_cubic(x,alpha)
    k = 2*alpha;
    A = (2*x.^2 - 2*x)/k + (-4*x + 2)/k^2 + 4/k^3;
    A1 = -2/k^2 + 4/k^3;
    p = A - exp(k*(1-x))*A1;
end

function [R,Rend,Rint] = bistable_duffing_reference_LIM(alpha)
    Rend = endpoint_radius_bistable(alpha);
    Rint = interior_radius_bistable(alpha);
    candidates = [Rend Rint];
    candidates = candidates(isfinite(candidates) & candidates >= 0);
    if isempty(candidates)
        R = NaN;
    else
        R = min(candidates);
    end
end

function r = endpoint_radius_bistable(alpha)
    if alpha >= sqrt(3/2)
        r = Inf;
        return
    end
    f = @(x) p_plus_bistable(x,alpha);
    xs = linspace(-8,-1e-8,4000);
    fs = arrayfun(f,xs);
    idxs = find(fs(1:end-1).*fs(2:end) <= 0);
    if isempty(idxs)
        r = Inf;
        return
    end
    roots = NaN(size(idxs));
    for k = 1:numel(idxs)
        try
            roots(k) = fzero(f,[xs(idxs(k)),xs(idxs(k)+1)]);
        catch
            roots(k) = NaN;
        end
    end
    roots = roots(isfinite(roots) & roots < -1e-7);
    if isempty(roots)
        r = Inf;
        return
    end
    xL = max(roots);
    r = abs(xL + 1);
end

function r = interior_radius_bistable(alpha)
    f = @(x) alpha*p_plus_bistable(x,alpha) - (2*x + 1 - x.^3);
    xs = linspace(-8,-1e-7,6000);
    fs = arrayfun(f,xs);
    idxs = find(isfinite(fs(1:end-1)) & isfinite(fs(2:end)) & fs(1:end-1).*fs(2:end) <= 0);
    roots = [];
    for k = 1:numel(idxs)
        try
            xr = fzero(f,[xs(idxs(k)),xs(idxs(k)+1)]);
            if xr < -1e-7 && p_plus_bistable(xr,alpha) >= -1e-8
                roots(end+1) = xr; %#ok<AGROW>
            end
        catch
        end
    end
    if isempty(roots)
        r = Inf;
        return
    end
    roots = unique(round(roots,12));
    radii = Inf(size(roots));
    for k = 1:numel(roots)
        x = roots(k);
        p = p_plus_bistable(x,alpha);
        if p >= -1e-8
            p = max(p,0);
            radii(k) = sqrt((x+1).^2 + p);
        end
    end
    r = min(radii);
end

function p = p_plus_bistable(x,alpha)
    a = alpha;
    p = ( ...
        -4*a^3.*x.^3 + 6*a^2.*x.^2 + (4*a^3 - 6*a).*x + ...
        (3 - 2*a^2) - (3 - 2*a^2).*exp(-2*a.*x) ) ./ (4*a^4);
end

function R = paper_unforced_duffing_reference_LIM(alpha)
    % Published reference for the original DynIn paper's 2D Duffing example:
    % x'' + 0.1*x' - x + x^3 = 0, with zeta = alpha = 0.05 and a = 1.
    % The paper reports LIM = 0.7683 in Fig. 1. Therefore this benchmark is
    % intentionally restricted to alpha = 0.05, instead of using a parameter
    % sweep with an independently generated numerical reference.
    if abs(alpha - 0.05) > 1e-12
        error(['paper_unforced_duffing is a fixed single-parameter benchmark. ', ...
            'Use alpha = 0.05, where the original DynIn paper reports LIM = 0.7683.']);
    end
    R = 0.7683;
end

function R = genda_cosine_quadratic_drag_reference_LIM(alpha)
    % Reference LIM for Genda's cosine-potential benchmark:
    %
    %     x'' + alpha*abs(x')*x' + sin(x) = 0.
    %
    % The paper gives the right saddle separatrix approaching x = pi as
    %
    %     vcrit^2(x;alpha) =
    %       2/(4*alpha^2+1) * (cos(x) - 2*alpha*sin(x)
    %       + exp(2*alpha*(pi-x))).
    %
    % The LIM is the minimum distance from the stable equilibrium (0,0) to
    % this separatrix.  The left boundary gives the same distance by symmetry.
    obj = @(x) x.^2 + max(0,genda_cosine_vcrit2(x,alpha));
    xStar = fminbnd(obj,-pi+1e-8,pi-1e-8,optimset('TolX',1e-12,'Display','off'));
    R = sqrt(obj(xStar));
end

function p = genda_cosine_vcrit2(x,alpha)
    p = 2./(4*alpha.^2 + 1) .* ...
        (cos(x) - 2*alpha.*sin(x) + exp(2*alpha.*(pi - x)));
end


function hash=file_sha256(file)
fid=fopen(file,'rb'); assert(fid>=0,'Cannot read source for audit.');
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(bytes(:),'int8'));
hash=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
