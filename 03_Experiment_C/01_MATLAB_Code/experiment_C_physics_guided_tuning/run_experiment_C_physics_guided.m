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
function outDir = run_experiment_C_physics_guided(benchmarkName, seedList, runMode, resumeDir)
%RUN_EXPERIMENT_C_PHYSICS_GUIDED Physics-guided tuning of DynIn GA.
%
% Screen cumulative parameter blocks with 10 paired seeds:
%   run_experiment_C_physics_guided('quadratic_cubic',1:10,'screening')
%
% Confirm frozen physics rules with 30 paired seeds:
%   run_experiment_C_physics_guided('quadratic_cubic',1:30,'confirmation')
%
% Quick path check, or write the design without running DynIn:
%   run_experiment_C_physics_guided('quadratic_cubic',1,'smoke')
%   run_experiment_C_physics_guided('quadratic_cubic',1:10,'design')
%
% Resume an interrupted run:
%   run_experiment_C_physics_guided('quadratic_cubic',1:10,'screening', ...
%       'C:\path\to\outputs_experiment_C_...')
%
% The original DynIn v1.1.0 GA branch is used unchanged (type_x0 = 1).
% Hyperparameters are estimated from equilibria, potential barriers, local
% frequency and quadratic-damping decay. Analytical LIM references are
% used only after a run for scoring and independent diagnostics.

    if nargin < 1 || isempty(benchmarkName)
        benchmarkName = 'quadratic_cubic';
    end
    if nargin < 2 || isempty(seedList)
        seedList = 1:10;
    end
    if nargin < 3 || isempty(runMode)
        runMode = 'screening';
    end
    if nargin < 4
        resumeDir = '';
    end

    benchmarkName = validatestring(char(benchmarkName), ...
        {'quadratic_cubic','bistable_duffing', ...
         'cosine_quadratic_drag','tilted_washboard'});
    runMode = validatestring(runMode, ...
        {'screening','confirmation','smoke','design'});
    seedList = unique(seedList(:).', 'stable');
    validateattributes(seedList, {'numeric'}, ...
        {'integer','positive','finite','nonempty'});
    if strcmp(runMode, 'smoke')
        seedList = seedList(1);
    end

    scriptRoot = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(scriptRoot);
    originalFunctionsDir = fullfile(repoRoot, 'work', 'DynIn', ...
        'DynIn_v1.1.0', 'functions');
    assert(isfile(fullfile(originalFunctionsDir, 'compute_LIM_FP.m')), ...
        'Original DynIn compute_LIM_FP.m was not found at %s', ...
        originalFunctionsDir);

    if isempty(resumeDir)
        stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
        outDir = fullfile(scriptRoot, ...
            ['outputs_physics_guided_C_' benchmarkName '_' stamp]);
        mkdir(outDir);
    else
        outDir = char(resumeDir);
        assert(isfolder(outDir), 'Resume directory does not exist: %s', outDir);
    end

    modelDir = fullfile(outDir, 'model');
    if ~isfolder(modelDir)
        mkdir(modelDir);
    end
    write_sistema_file(modelDir, benchmarkName);

    previousPath = path;
    pathCleanup = onCleanup(@() path(previousPath)); %#ok<NASGU>
    restoredefaultpath;
    rehash toolboxcache;
    addpath(scriptRoot, '-begin');
    addpath(modelDir, '-begin');
    addpath(originalFunctionsDir, '-begin');
    assert_same_file(which('compute_LIM_FP'), ...
        fullfile(originalFunctionsDir, 'compute_LIM_FP.m'), 'compute_LIM_FP');
    assert_same_file(which('sistema'), ...
        fullfile(modelDir, 'sistema.m'), 'sistema');

    cases = build_benchmark_cases(benchmarkName);
    if strcmp(runMode, 'smoke')
        cases = cases(1,:);
    end
    [design,parameterAudit] = build_physics_guided_design(cases,runMode);
    scheduleSeed = 20260920;
    schedule = build_randomized_schedule(design, seedList, scheduleSeed);

    designPath = fullfile(outDir, 'experiment_C_physics_guided_design.csv');
    parameterAuditPath = fullfile(outDir, 'parameter_estimation_audit.csv');
    schedulePath = fullfile(outDir, 'randomized_execution_schedule.csv');
    referencePath = fullfile(outDir, 'reference_audit.csv');
    rawPath = fullfile(outDir, 'raw_data_all_runs.csv');
    diagnosticPath = fullfile(outDir, 'fixed_diagnostic_set.csv');
    checkpointPath = fullfile(outDir, 'checkpoint.mat');
    manifestPath = fullfile(outDir, 'run_manifest.txt');

    writetable(design, designPath);
    writetable(parameterAudit, parameterAuditPath);
    writetable(build_reference_audit(cases), referencePath);
    if isfile(schedulePath)
        oldSchedule = readtable(schedulePath, 'TextType', 'string');
        assert(isequal(string(oldSchedule.run_key), string(schedule.run_key)), ...
            'Resume schedule differs from the stored schedule.');
    else
        writetable(schedule, schedulePath);
    end
    write_manifest(manifestPath, benchmarkName, runMode, seedList, ...
        originalFunctionsDir, modelDir, scheduleSeed, cases, design);

    if strcmp(runMode, 'design')
        fprintf('Experiment C physics-guided design written:\n%s\n%s\n%s\n%s\n', ...
            designPath, parameterAuditPath, schedulePath, referencePath);
        return
    end

    if strcmp(runMode, 'smoke')
        plannedDiagnosticPoints = height(cases)*8*2;
    else
        plannedDiagnosticPoints = height(cases)*24*3;
    end
    fprintf('Planned progress: %d diagnostic classifications, then %d DynIn runs.\n', ...
        plannedDiagnosticPoints,height(schedule));

    if isfile(rawPath)
        raw = readtable(rawPath, 'TextType', 'string');
        fprintf('Resuming from %d completed runs in:\n%s\n\n', height(raw), outDir);
    else
        raw = table();
    end

    if isfile(diagnosticPath)
        diagnostic = readtable(diagnosticPath, 'TextType', 'string');
    else
        fprintf('Building fixed independent diagnostic sets ...\n');
        if strcmp(runMode, 'smoke')
            diagnostic = build_all_diagnostic_sets(cases, 8, [0.90 1.10]);
        else
            diagnostic = build_all_diagnostic_sets(cases, 24, [0.85 1.00 1.15]);
        end
        writetable(diagnostic, diagnosticPath);
        fprintf('Diagnostic points: %d; unresolved truth labels: %d.\n\n', ...
            height(diagnostic), nnz(diagnostic.true_label == 0));
    end

    completedKeys = completed_run_keys(raw);
    totalRuns = height(schedule);
    runCounter = numel(completedKeys);

    fprintf('DynIn Experiment C (physics-guided): %s / %s mode\n', ...
        benchmarkName, upper(runMode));
    fprintf('Original GA branch: type_x0 = 1\n');
    fprintf('Cases: %d; profiles: %d; paired seeds: %d; runs: %d\n', ...
        height(cases), numel(unique(design.profile_id)),numel(seedList),totalRuns);
    fprintf('Output directory:\n%s\n\n', outDir);

    for iRun = 1:height(schedule)
        key = string(schedule.run_key(iRun));
        if any(completedKeys == key)
            continue
        end

        designRow = design(design.design_id == schedule.design_id(iRun), :);
        assert(height(designRow) == 1, 'Unknown design row in schedule: %s', key);
        cfg = table_row_to_struct(designRow);
        seed = schedule.seed(iRun);
        runCounter = runCounter + 1;
        fprintf('[run %d/%d] START  case=%s, seed=%d, profile=%s\n', ...
            runCounter, totalRuns, ...
            cfg.case_id, seed, cfg.profile_id);

        rng(schedule.algorithm_rng_seed(iRun), 'twister');
        [result, OutH] = execute_one_run(cfg);
        caseDiagnostic = diagnostic(diagnostic.case_id == cfg.case_id, :);
        if result.success
            diagTimer = tic;
            metrics = evaluate_learned_classifier(caseDiagnostic, OutH, cfg);
            result.diagnostic_runtime_s = toc(diagTimer);
            fprintf('[run %d/%d] DONE   R=%.6f, rel.err=%.3g, wall=%.2fs\n', ...
                runCounter, totalRuns, ...
                result.R_hat, result.relative_error, result.wall_runtime_s);
        else
            metrics = empty_diagnostic_metrics();
            result.diagnostic_runtime_s = NaN;
            fprintf('[run %d/%d] FAILED %s\n', ...
                runCounter, totalRuns, result.error_message);
        end

        row = assemble_raw_row(cfg, seed, key, schedule.execution_order(iRun), ...
            schedule.algorithm_rng_seed(iRun), result, metrics);
        if isempty(raw)
            raw = struct2table(row, 'AsArray', true);
        else
            raw = [raw; struct2table(row, 'AsArray', true)]; %#ok<AGROW>
        end
        atomic_write_table(raw, rawPath);
        save(checkpointPath, 'raw', 'design', 'parameterAudit', ...
            'schedule', 'diagnostic','cases','seedList','runMode','-v7.3');
        completedKeys(end+1,1) = key; %#ok<AGROW>
        clear OutH
    end

    summary = summarize_results(raw);
    contrasts = summarize_paired_contrasts(raw,design);
    passMatrix = build_physics_pass_matrix(summary);
    writetable(summary, fullfile(outDir, 'summary_by_case_and_profile.csv'));
    writetable(contrasts, fullfile(outDir, ...
        'paired_contrasts_cumulative_blocks.csv'));
    writetable(passMatrix, fullfile(outDir, 'physics_profile_pass_matrix.csv'));

    fprintf('\nExperiment C finished.\n');
    fprintf('Raw runs: %s\n', rawPath);
    fprintf('Summary:  %s\n', fullfile(outDir, 'summary_by_case_and_profile.csv'));
    fprintf('Contrasts: %s\n', fullfile(outDir, ...
        'paired_contrasts_cumulative_blocks.csv'));
end

function cases = build_benchmark_cases(name)
    rows = cell(0,1);
    switch name
        case 'quadratic_cubic'
            values = [0.2 0.4 0.8];
            for i = 1:numel(values)
                rows{end+1,1} = make_case(name, values(i), NaN, NaN); %#ok<AGROW>
            end
        case 'bistable_duffing'
            values = [0.2 0.5 0.7 1.0];
            for i = 1:numel(values)
                rows{end+1,1} = make_case(name, values(i), NaN, NaN); %#ok<AGROW>
            end
        case 'cosine_quadratic_drag'
            values = [0.01 0.02 0.05 0.10 0.15];
            for i = 1:numel(values)
                rows{end+1,1} = make_case(name, values(i), NaN, NaN); %#ok<AGROW>
            end
        case 'tilted_washboard'
            Fvalues = [0.2 0.5 0.8];
            ratios = [0.8 1.0 1.2];
            for iF = 1:numel(Fvalues)
                acrit = Fvalues(iF) / (2*sqrt(1-Fvalues(iF)^2));
                for iRatio = 1:numel(ratios)
                    rows{end+1,1} = make_case(name, ...
                        ratios(iRatio)*acrit, Fvalues(iF), ratios(iRatio)); %#ok<AGROW>
                end
            end
    end
    cases = struct2table(vertcat(rows{:}));
    cases.case_order = (1:height(cases)).';
    cases = movevars(cases, 'case_order', 'Before', 1);
end

function row = make_case(name, alpha, F, alphaRatio)
    spec = model_spec(name, alpha, F);
    [reference, referenceSource, referenceResidual] = ...
        analytical_reference(name, alpha, F);
    if strcmp(name, 'tilted_washboard')
        caseId = sprintf('F_%0.2f_ratio_%0.1f', F, alphaRatio);
        parameterLabel = sprintf('F=%.2f; alpha/alpha_crit=%.1f', F, alphaRatio);
    else
        caseId = sprintf('alpha_%0.3f', alpha);
        parameterLabel = sprintf('alpha=%.3f', alpha);
    end
    row = struct();
    row.benchmark_name = string(name);
    row.case_id = string(caseId);
    row.parameter_label = string(parameterLabel);
    row.alpha = alpha;
    row.F = F;
    row.alpha_over_alpha_crit = alphaRatio;
    row.reference_LIM = reference;
    row.reference_source = string(referenceSource);
    row.reference_residual = referenceResidual;
    row.target_x = spec.target(1);
    row.target_v = spec.target(2);
    row.weight_x = spec.weight(1);
    row.weight_v = spec.weight(2);
    row.domain_x_min = spec.domain(1);
    row.domain_v_min = spec.domain(2);
    row.domain_x_max = spec.domain(3);
    row.domain_v_max = spec.domain(4);
    row.x_scale = spec.xScale;
    row.v_scale = spec.vScale;
end

function [design,auditTable] = build_physics_guided_design(cases,runMode)
    rows = cell(0,1);
    auditRows = cell(height(cases),1);
    for iCase = 1:height(cases)
        c = table_row_to_struct(cases(iCase,:));
        [estimated,audit] = estimate_dynin_parameters_from_physics( ...
            c.benchmark_name,c.alpha,c.F);
        audit.case_id = c.case_id;
        audit.parameter_label = c.parameter_label;
        auditRows{iCase} = audit;
        base = habib_baseline();

        essential = base;
        essential.profile_id = "essential_only";
        essential.profile_label = "Correct target, metric and physics-derived domain";
        essential.profile_order = 1;
        essential.physics_rule_complete = false;
        essential.weight = estimated.weight;
        essential.domain = estimated.domain;

        geometry = essential;
        geometry.profile_id = "geometry_scaled";
        geometry.profile_label = "Add grid and target belt from physical scales";
        geometry.profile_order = 2;
        geometry.discr = estimated.discr;
        geometry.num_of_cell_around_equilibrium = ...
            estimated.num_of_cell_around_equilibrium;

        decay = geometry;
        decay.profile_id = "decay_time_scaled";
        decay.profile_label = "Add horizon and sampling from local decay";
        decay.profile_order = 3;
        decay.tfinal = estimated.tfinal;
        decay.Ts = estimated.Ts;

        physics100 = decay;
        physics100.profile_id = "physics_N100";
        physics100.profile_label = "Add decay-aware periodic threshold; N=100";
        physics100.profile_order = 4;
        physics100.physics_rule_complete = true;
        physics100.rep_periodic = estimated.rep_periodic;
        physics100.reltol = estimated.reltol;
        physics100.abstol = estimated.abstol;
        physics100.number_of_steps = 100;

        physics50 = physics100;
        physics50.profile_id = "physics_N50";
        physics50.profile_label = "Complete physics rules; N=50";
        physics50.profile_order = 5;
        physics50.number_of_steps = 50;

        physics200 = physics100;
        physics200.profile_id = "physics_N200";
        physics200.profile_label = "Complete physics rules; N=200";
        physics200.profile_order = 6;
        physics200.number_of_steps = 200;

        if strcmp(runMode,'confirmation')
            profiles = {physics50,physics100,physics200};
        elseif strcmp(runMode,'smoke')
            profiles = {essential,geometry,decay,physics100};
        else
            profiles = {essential,geometry,decay,physics100,physics50,physics200};
        end
        for iProfile = 1:numel(profiles)
            rows{end+1,1} = design_row(c,profiles{iProfile}); %#ok<AGROW>
        end
    end
    design = struct2table(vertcat(rows{:}));
    design.design_id = (1:height(design)).';
    design = movevars(design, 'design_id', 'Before', 1);
    auditTable = struct2table(vertcat(auditRows{:}));
end

function base = habib_baseline()
    base = struct();
    base.profile_id = "";
    base.profile_label = "";
    base.formal_accuracy_comparable = true;
    base.weight = [4 1];
    base.domain = [-3 -2 3 4];
    base.discr = 701;
    base.num_of_cell_around_equilibrium = 3;
    base.tfinal = 2000;
    base.Ts = 0.05;
    base.reltol = 1e-8;
    base.abstol = 1e-8;
    base.number_of_steps = 100;
    base.rep_fix_point = 40;
    base.rep_periodic = 10;
    base.divR = 40;
    base.num_gen = 5;
    base.num_crossover = 9;
    base.selected_opt = 3;
    base.newcomers = 8;
    base.num_almost_clones = 2;
    base.profile_order = NaN;
    base.physics_rule_complete = false;
end

function row = design_row(c, cfg)
    row = c;
    row.profile_id = cfg.profile_id;
    row.profile_label = cfg.profile_label;
    row.profile_order = cfg.profile_order;
    row.physics_rule_complete = cfg.physics_rule_complete;
    row.formal_accuracy_comparable = cfg.formal_accuracy_comparable;
    row.weight_x = cfg.weight(1);
    row.weight_v = cfg.weight(2);
    row.domain_x_min = cfg.domain(1);
    row.domain_v_min = cfg.domain(2);
    row.domain_x_max = cfg.domain(3);
    row.domain_v_max = cfg.domain(4);
    row.discr = cfg.discr;
    row.num_of_cell_around_equilibrium = cfg.num_of_cell_around_equilibrium;
    row.tfinal = cfg.tfinal;
    row.Ts = cfg.Ts;
    row.reltol = cfg.reltol;
    row.abstol = cfg.abstol;
    row.number_of_steps = cfg.number_of_steps;
    row.rep_fix_point = cfg.rep_fix_point;
    row.rep_periodic = cfg.rep_periodic;
    row.divR = cfg.divR;
    row.num_gen = cfg.num_gen;
    row.num_crossover = cfg.num_crossover;
    row.selected_opt = cfg.selected_opt;
    row.newcomers = cfg.newcomers;
    row.num_almost_clones = cfg.num_almost_clones;
    row.population_size = 1 + cfg.num_crossover + cfg.newcomers + ...
        cfg.num_almost_clones;
end

function schedule = build_randomized_schedule(design, seedList, scheduleSeed)
    n = height(design)*numel(seedList);
    designId = zeros(n,1);
    seed = zeros(n,1);
    algorithmSeed = zeros(n,1);
    runKey = strings(n,1);
    k = 0;
    for iSeed = 1:numel(seedList)
        for iDesign = 1:height(design)
            k = k + 1;
            designId(k) = design.design_id(iDesign);
            seed(k) = seedList(iSeed);
            algorithmSeed(k) = 100000 + seedList(iSeed);
            runKey(k) = make_run_key(design.case_id(iDesign), ...
                design.profile_id(iDesign), seedList(iSeed));
        end
    end
    stream = RandStream('mt19937ar', 'Seed', scheduleSeed);
    order = randperm(stream, n).';
    schedule = table(designId(order), seed(order), algorithmSeed(order), ...
        runKey(order), 'VariableNames', ...
        {'design_id','seed','algorithm_rng_seed','run_key'});
    schedule.execution_order = (1:n).';
    schedule = movevars(schedule, 'execution_order', 'Before', 1);
end

function [result, OutH] = execute_one_run(cfg)
    result = empty_result();
    OutH = struct();
    args = struct();
    args.tfinal = cfg.tfinal;
    args.Ts = cfg.Ts;
    args.weight = [cfg.weight_x cfg.weight_v];
    args.type_x0 = 1;
    args.reltol = cfg.reltol;
    args.abstol = cfg.abstol;
    args.number_of_steps = cfg.number_of_steps;
    args.num_of_cell_around_equilibrium = cfg.num_of_cell_around_equilibrium;
    args.num_fig = 1001;
    args.plot_results = 0;
    args.plot_results_final = 0;
    args.spaceboundary = [cfg.domain_x_min cfg.domain_v_min ...
                          cfg.domain_x_max cfg.domain_v_max];
    args.discr = cfg.discr;
    args.automatic = 1;
    args.var1 = 1;
    args.var2 = 2;
    args.rep_fix_point = cfg.rep_fix_point;
    args.rep_periodic = cfg.rep_periodic;
    args.min_periodic_radius = 0.005;
    args.check_min_periodic = 0;
    args.check_equilibrium = 1;
    args.max_check_step = 10000;
    args.divR = cfg.divR;
    args.num_gen = cfg.num_gen;
    args.num_crossover = cfg.num_crossover;
    args.selected_opt = cfg.selected_opt;
    args.newcomers = cfg.newcomers;
    args.num_almost_clones = cfg.num_almost_clones;
    args.bis_iter_max = 5;

    target = [cfg.target_x cfg.target_v];
    par = struct('alpha',cfg.alpha,'F',cfg.F,'a',1);
    timer = tic;
    try
        vals = struct_to_original_optional_order(args, target);
        [Rhat, OutL, OutH] = compute_LIM_FP(target, par, vals{:});
        result.wall_runtime_s = toc(timer);
        result.R_hat = Rhat;
        result.relative_error = abs(Rhat-cfg.reference_LIM)/cfg.reference_LIM;
        result.signed_relative_error = (Rhat-cfg.reference_LIM)/cfg.reference_LIM;
        result.within_1pct = isfinite(result.relative_error) && ...
            result.relative_error <= 0.01;
        result.unsafe_overestimate = isfinite(result.signed_relative_error) && ...
            result.signed_relative_error > 0;
        result.algorithm_runtime_s = safe_scalar_field(OutL, 'total_time');
        result.trajectory_evaluations = count_trajectory_evaluations(OutL);
        result.processed_time_samples = sum_finite_field(OutL, 'time_steps_sim');
        result.success = isfinite(Rhat);
        if ~result.success
            result.error_message = "compute_LIM_FP returned a non-finite LIM";
        end
    catch ME
        result.wall_runtime_s = toc(timer);
        result.error_message = string(getReport(ME, 'basic', 'hyperlinks', 'off'));
    end
end

function result = empty_result()
    result = struct('success',false,'R_hat',NaN,'relative_error',NaN, ...
        'signed_relative_error',NaN,'within_1pct',false, ...
        'unsafe_overestimate',false,'wall_runtime_s',NaN, ...
        'algorithm_runtime_s',NaN,'diagnostic_runtime_s',NaN, ...
        'trajectory_evaluations',NaN,'processed_time_samples',NaN, ...
        'error_message',"");
end

function diagnostic = build_all_diagnostic_sets(cases, nAngles, factors)
    blocks = cell(height(cases),1);
    totalPoints = height(cases)*nAngles*numel(factors);
    completedPoints = 0;
    for iCase = 1:height(cases)
        [blocks{iCase},completedPoints] = build_diagnostic_set( ...
            table_row_to_struct(cases(iCase,:)),nAngles,factors, ...
            completedPoints,totalPoints);
    end
    diagnostic = vertcat(blocks{:});
end

function [diagnostic,completedPoints] = build_diagnostic_set( ...
        c,nAngles,factors,completedPoints,totalPoints)
    theta = (0:nAngles-1).'*(2*pi/nAngles);
    rows = cell(0,1);
    pointId = 0;
    for iFactor = 1:numel(factors)
        radius = c.reference_LIM*factors(iFactor);
        for iTheta = 1:numel(theta)
            weighted = radius*[cos(theta(iTheta)) sin(theta(iTheta))];
            x0 = [c.target_x c.target_v] + weighted ./ ...
                sqrt([c.weight_x c.weight_v]);
            pointId = pointId + 1;
            completedPoints = completedPoints + 1;
            fprintf('[diagnostic %d/%d] START case=%s, factor=%.2f, angle=%.1f deg\n', ...
                completedPoints,totalPoints,c.case_id,factors(iFactor), ...
                theta(iTheta)*180/pi);
            [label,eventName,elapsed] = independent_truth_label(x0,c);
            fprintf('[diagnostic %d/%d] DONE  label=%d, event=%s, wall=%.2fs\n', ...
                completedPoints,totalPoints,label,eventName,elapsed);
            row = struct('case_id',string(c.case_id),'point_id',pointId, ...
                'theta_rad',theta(iTheta),'radius_factor',factors(iFactor), ...
                'weighted_radius',radius,'x0',x0(1),'v0',x0(2), ...
                'true_label',label,'truth_event',string(eventName), ...
                'truth_runtime_s',elapsed);
            rows{end+1,1} = row; %#ok<AGROW>
        end
    end
    diagnostic = struct2table(vertcat(rows{:}));
end

function [label,eventName,elapsed] = independent_truth_label(x0,c)
    target = [c.target_x c.target_v];
    maxTime = max(6000, 2*c.reference_LIM*1000);
    truthBoundary = truth_domain(c);
    options = odeset('RelTol',1e-11,'AbsTol',1e-12, ...
        'Events',@(t,x) truth_events(t,x,target,truthBoundary));
    par = struct('alpha',c.alpha,'F',c.F,'a',1);
    timer = tic;
    [~,trajectory,~,~,eventIndex] = ode45( ...
        @(t,x) model_rhs(t,x,par,c.benchmark_name),[0 maxTime],x0(:),options);
    elapsed = toc(timer);
    label = 0;
    eventName = "unresolved";
    if ~isempty(eventIndex)
        if eventIndex(end) == 1
            label = 1;
            eventName = "target";
        else
            label = 2;
            eventName = "left_truth_domain";
        end
        return
    end
    finalState = trajectory(end,:);
    if norm(finalState-target) <= 0.02
        label = 1;
        eventName = "target_at_final_time";
    elseif converged_to_other_attractor(finalState,c)
        label = 2;
        eventName = "other_attractor";
    end
end

function boundary = truth_domain(c)
    if contains(c.case_id,'F_')
        delta = asin(c.F);
        boundary = [delta-10*pi -12 delta+10*pi 12];
    elseif c.target_x == 0 && c.domain_x_max > 3
        boundary = [-10*pi -12 10*pi 12];
    else
        boundary = [c.domain_x_min-4 c.domain_v_min-6 ...
                    c.domain_x_max+4 c.domain_v_max+6];
    end
end

function tf = converged_to_other_attractor(state,c)
    tf = false;
    if contains(c.case_id,'F_')
        delta = asin(c.F);
        k = round((state(1)-delta)/(2*pi));
        tf = k ~= 0 && norm(state-[delta+2*pi*k 0]) <= 0.03;
    elseif c.target_x == 0 && c.domain_x_max > 3
        k = round(state(1)/(2*pi));
        tf = k ~= 0 && norm(state-[2*pi*k 0]) <= 0.03;
    elseif c.target_x < 0
        tf = norm(state-[1 0]) <= 0.03;
    end
end

function [value,isterminal,direction] = truth_events(~,x,target,boundary)
    s = x(:).';
    value = [norm(s-target)-2e-3; s(1)-boundary(1); ...
        s(2)-boundary(2); boundary(3)-s(1); boundary(4)-s(2)];
    isterminal = ones(5,1);
    direction = -ones(5,1);
end

function metrics = evaluate_learned_classifier(diagnostic,OutH,cfg)
    metrics = empty_diagnostic_metrics();
    truth = diagnostic.true_label;
    resolved = truth ~= 0;
    metrics.diagnostic_truth_unresolved_rate = mean(truth == 0);
    if ~any(resolved)
        return
    end
    [safeCells,unsafeCells] = learned_cell_sets(OutH,cfg);
    predicted = zeros(height(diagnostic),1);
    for i = 1:height(diagnostic)
        if truth(i) ~= 0
            predicted(i) = classify_with_learned_grid( ...
                [diagnostic.x0(i) diagnostic.v0(i)],safeCells,unsafeCells,cfg);
        end
    end
    trueUnsafe = truth == 2;
    trueSafe = truth == 1;
    metrics.false_safe_rate = safe_ratio(predicted == 1,trueUnsafe);
    metrics.false_unsafe_rate = safe_ratio(predicted == 2,trueSafe);
    metrics.diagnostic_unresolved_rate = safe_ratio(predicted == 0,resolved);
    metrics.diagnostic_coverage = safe_ratio(predicted ~= 0,resolved);
    metrics.diagnostic_accuracy_resolved = safe_ratio( ...
        predicted == truth,resolved & predicted ~= 0);
    metrics.n_diagnostic_target = nnz(trueSafe);
    metrics.n_diagnostic_nontarget = nnz(trueUnsafe);
end

function metrics = empty_diagnostic_metrics()
    metrics = struct('false_safe_rate',NaN,'false_unsafe_rate',NaN, ...
        'diagnostic_unresolved_rate',NaN,'diagnostic_coverage',NaN, ...
        'diagnostic_accuracy_resolved',NaN, ...
        'diagnostic_truth_unresolved_rate',NaN, ...
        'n_diagnostic_target',NaN,'n_diagnostic_nontarget',NaN);
end

function [safeCells,unsafeCells] = learned_cell_sets(OutH,cfg)
    boundary = [cfg.domain_x_min cfg.domain_v_min ...
                cfg.domain_x_max cfg.domain_v_max];
    safeCells = points_to_cell_ids(safe_points_field(OutH,'vc'),cfg.discr,boundary);
    unsafeCells = [points_to_cell_ids(safe_points_field(OutH,'vd'),cfg.discr,boundary); ...
        points_to_cell_ids(safe_points_field(OutH,'vdout'),cfg.discr,boundary)];
    center = point_to_cell_coordinate([cfg.target_x cfg.target_v],cfg.discr,boundary);
    safeCells = unique([safeCells; local_target_belt(center,cfg.discr, ...
        cfg.num_of_cell_around_equilibrium)]);
    unsafeCells = unique(unsafeCells);
    conflict = intersect(safeCells,unsafeCells);
    safeCells = setdiff(safeCells,conflict);
    unsafeCells = setdiff(unsafeCells,conflict);
end

function points = safe_points_field(s,name)
    if isstruct(s) && isfield(s,name)
        points = s.(name);
    else
        points = zeros(0,2);
    end
end

function label = classify_with_learned_grid(x0,safeCells,unsafeCells,cfg)
    boundary = [cfg.domain_x_min cfg.domain_v_min ...
                cfg.domain_x_max cfg.domain_v_max];
    state = x0;
    label = lookup_cell_label(state,safeCells,unsafeCells,cfg.discr,boundary);
    if label ~= 0, return; end
    par = struct('alpha',cfg.alpha,'F',cfg.F,'a',1);
    tolerance = [cfg.reltol cfg.abstol];
    for i = 1:ceil(cfg.tfinal/cfg.Ts)
        if ~point_in_domain(state,boundary)
            label = 2; return
        end
        segment = sys_solver(cfg.Ts,state,par,tolerance);
        state = segment(end,:);
        label = lookup_cell_label(state,safeCells,unsafeCells,cfg.discr,boundary);
        if label ~= 0, return; end
    end
end

function label = lookup_cell_label(point,safeCells,unsafeCells,discr,boundary)
    id = point_to_cell_id(point,discr,boundary);
    if isnan(id), label = 2;
    elseif ismember(id,safeCells), label = 1;
    elseif ismember(id,unsafeCells), label = 2;
    else, label = 0;
    end
end

function ids = points_to_cell_ids(points,discr,boundary)
    if isempty(points) || all(isnan(points(:)))
        ids = zeros(0,1); return
    end
    points = points(all(isfinite(points),2),:);
    ids = NaN(size(points,1),1);
    for i = 1:size(points,1)
        ids(i) = point_to_cell_id(points(i,:),discr,boundary);
    end
    ids = unique(ids(isfinite(ids)));
end

function id = point_to_cell_id(point,discr,boundary)
    if ~point_in_domain(point,boundary)
        id = NaN; return
    end
    coord = point_to_cell_coordinate(point,discr,boundary);
    id = 1+(coord(1)-1)*discr+(coord(2)-1);
end

function coord = point_to_cell_coordinate(point,discr,boundary)
    lower = boundary(1:2); upper = boundary(3:4);
    dh = (upper-lower)/discr;
    coord = floor((point-lower)./dh)+1;
    coord = max(1,min(discr,coord));
end

function ids = local_target_belt(center,discr,requestedCells)
    n = max(1,floor(abs(requestedCells)));
    offsets = -floor(n/2):floor(n/2);
    ids = zeros(numel(offsets)^2,1); k = 0;
    for i = offsets
        for j = offsets
            c = center+[i j];
            if all(c >= 1) && all(c <= discr)
                k = k+1; ids(k) = 1+(c(1)-1)*discr+(c(2)-1);
            end
        end
    end
    ids = unique(ids(1:k));
end

function tf = point_in_domain(point,boundary)
    tf = all(point >= boundary(1:2)) && all(point <= boundary(3:4));
end

function row = assemble_raw_row(cfg,seed,key,executionOrder,rngSeed,result,metrics)
    row = cfg;
    row.run_key = string(key);
    row.seed = seed;
    row.execution_order = executionOrder;
    row.algorithm_rng_seed = rngSeed;
    names = fieldnames(result);
    for i = 1:numel(names), row.(names{i}) = result.(names{i}); end
    names = fieldnames(metrics);
    for i = 1:numel(names), row.(names{i}) = metrics.(names{i}); end
end

function summary = summarize_results(raw)
    caseIds = unique(raw.case_id,'stable');
    profileIds = unique(raw.profile_id,'stable');
    rows = cell(0,1);
    for iCase = 1:numel(caseIds)
        for iProfile = 1:numel(profileIds)
            g = raw(raw.case_id == caseIds(iCase) & ...
                raw.profile_id == profileIds(iProfile),:);
            if isempty(g), continue; end
            row = struct();
            row.case_id = caseIds(iCase);
            row.parameter_label = g.parameter_label(1);
            row.profile_id = profileIds(iProfile);
            row.profile_label = g.profile_label(1);
            row.profile_order = g.profile_order(1);
            row.formal_accuracy_comparable = g.formal_accuracy_comparable(1);
            row.n_runs = height(g);
            row.n_success = nnz(g.success);
            row.reference_LIM = g.reference_LIM(1);
            row.median_R_hat = median_finite(g.R_hat);
            row.median_relative_error = median_finite(g.relative_error);
            row.p95_relative_error = percentile_finite(g.relative_error,95);
            row.median_signed_relative_error = median_finite(g.signed_relative_error);
            row.unsafe_overestimate_rate = mean_finite(double(g.unsafe_overestimate));
            row.within_1pct_rate = mean_finite(double(g.within_1pct));
            row.median_wall_runtime_s = median_finite(g.wall_runtime_s);
            row.median_trajectory_evaluations = median_finite(g.trajectory_evaluations);
            row.mean_false_safe_rate = mean_finite(g.false_safe_rate);
            row.max_false_safe_rate = max_finite(g.false_safe_rate);
            row.mean_false_unsafe_rate = mean_finite(g.false_unsafe_rate);
            row.mean_diagnostic_unresolved_rate = ...
                mean_finite(g.diagnostic_unresolved_rate);
            rows{end+1,1} = row; %#ok<AGROW>
        end
    end
    summary = struct2table(vertcat(rows{:}));
    summary = sortrows(summary,{'case_id','profile_order'});
end

function contrasts = summarize_paired_contrasts(raw,design)
    caseIds = unique(raw.case_id,'stable');
    available = unique(string(design.profile_id),'stable');
    pairFrom = ["essential_only","geometry_scaled","decay_time_scaled", ...
                "physics_N100","physics_N100"];
    pairTo = ["geometry_scaled","decay_time_scaled","physics_N100", ...
              "physics_N50","physics_N200"];
    rows = cell(0,1);
    for iCase = 1:numel(caseIds)
        g = raw(raw.case_id == caseIds(iCase),:);
        for iPair = 1:numel(pairFrom)
            if ~any(available == pairFrom(iPair)) || ...
                    ~any(available == pairTo(iPair)), continue; end
            base = g(g.profile_id == pairFrom(iPair),:);
            candidate = g(g.profile_id == pairTo(iPair),:);
            [sharedSeeds,ib,it] = intersect(base.seed,candidate.seed,'stable');
            if isempty(sharedSeeds), continue; end
            row = struct();
            row.case_id = caseIds(iCase);
            row.from_profile = pairFrom(iPair);
            row.to_profile = pairTo(iPair);
            row.n_paired = numel(sharedSeeds);
            row.median_delta_relative_error = median_finite( ...
                candidate.relative_error(it)-base.relative_error(ib));
            row.median_delta_wall_runtime_s = median_finite( ...
                candidate.wall_runtime_s(it)-base.wall_runtime_s(ib));
            row.median_runtime_ratio = median_finite( ...
                candidate.wall_runtime_s(it)./base.wall_runtime_s(ib));
            row.delta_within_1pct_rate = ...
                mean_finite(double(candidate.within_1pct(it))) - ...
                mean_finite(double(base.within_1pct(ib)));
            row.delta_false_safe_rate = ...
                mean_finite(candidate.false_safe_rate(it)) - ...
                mean_finite(base.false_safe_rate(ib));
            rows{end+1,1} = row; %#ok<AGROW>
        end
    end
    if isempty(rows), contrasts = table();
    else, contrasts = struct2table(vertcat(rows{:})); end
end

function pass = build_physics_pass_matrix(summary)
    pass = summary(startsWith(string(summary.profile_id),"physics_N"), ...
        {'case_id','parameter_label','n_runs','n_success', ...
         'profile_id', ...
         'median_relative_error','p95_relative_error','within_1pct_rate', ...
         'mean_false_safe_rate','max_false_safe_rate','median_wall_runtime_s'});
    pass.median_error_pass = pass.median_relative_error <= 0.01;
    pass.p95_error_pass = pass.p95_relative_error <= 0.05;
    pass.false_safe_pass = pass.mean_false_safe_rate <= 0.01;
    pass.complete_run_pass = pass.n_success == pass.n_runs;
    pass.overall_physics_profile_pass = pass.median_error_pass & ...
        pass.p95_error_pass & pass.false_safe_pass & pass.complete_run_pass;
end

function audit = build_reference_audit(cases)
    audit = cases(:,{'case_id','parameter_label','alpha','F', ...
        'alpha_over_alpha_crit','reference_LIM','reference_source', ...
        'reference_residual'});
end

function spec = model_spec(name,~,F)
    spec = struct('target',[0 0],'weight',[1 1],'domain',[-1 -1 1 1], ...
        'xScale',1,'vScale',1);
    switch char(name)
        case 'quadratic_cubic'
            spec.target = [0 0];
            spec.domain = [-1.2 -1.2 1.2 1.2];
            spec.xScale = 1;
            spec.vScale = sqrt(1/3);
        case 'bistable_duffing'
            spec.target = [-1 0];
            spec.domain = [-2.2 -2.2 1.2 2.2];
            spec.xScale = 1;
            spec.vScale = sqrt(0.5);
        case 'cosine_quadratic_drag'
            spec.target = [0 0];
            spec.domain = [-1.2*pi -3 1.2*pi 3];
            spec.xScale = pi;
            spec.vScale = 2;
        case 'tilted_washboard'
            delta = asin(F);
            leftSaddle = -pi-delta;
            rightSaddle = pi-delta;
            margin = 0.2*(rightSaddle-leftSaddle);
            well = -cos(delta)-F*delta;
            saddle = -cos(rightSaddle)-F*rightSaddle;
            vScale = sqrt(max(2*(saddle-well),0.05));
            spec.target = [delta 0];
            spec.domain = [leftSaddle-margin -3 rightSaddle+margin 3];
            spec.xScale = min(delta-leftSaddle,rightSaddle-delta);
            spec.vScale = vScale;
        otherwise
            error('Unknown benchmark: %s',name);
    end
end

function [R,source,residual] = analytical_reference(name,alpha,F)
    switch char(name)
        case 'quadratic_cubic'
            [R,residual] = reference_quadratic_cubic(alpha);
            source = 'Genda V2, Secs. 3.5-3.6, Eqs. 52, 54, 56-61';
        case 'bistable_duffing'
            [R,residual] = reference_bistable_duffing(alpha);
            source = 'Genda V2, Sec. 4.5, Eqs. 94, 96, 103-105, 110-112';
        case 'cosine_quadratic_drag'
            p = @(x) 2/(1+4*alpha^2)*(cos(x)-2*alpha*sin(x)+ ...
                exp(2*alpha*(pi-x)));
            stationarity = @(x) (1+4*alpha^2)*x-sin(x)- ...
                2*alpha*cos(x)-2*alpha*exp(2*alpha*(pi-x));
            xstar = fzero(stationarity,[0 pi],optimset('TolX',1e-12,'Display','off'));
            R = sqrt(xstar^2+p(xstar));
            residual = abs(stationarity(xstar));
            source = 'Genda Manuscript v2, cosine potential, Eqs. 26, 29, 34, 37';
        case 'tilted_washboard'
            [R,residual] = reference_washboard(alpha,F);
            source = 'Genda Manuscript v2, washboard potential, Eqs. 146-162';
        otherwise
            error('No analytical reference for %s',name);
    end
end

function [R,residual] = reference_washboard(alpha,F)
    delta = asin(F);
    xs = pi-delta;
    A = @(x) 2/(4*alpha^2+1)*(cos(x)-2*alpha*sin(x))+F/alpha;
    ps = @(x) A(x)-exp(2*alpha*(xs-x))*A(xs);
    objective = @(x) (x-delta).^2+max(0,ps(x));
    acrit = F/(2*sqrt(1-F^2));
    if alpha < acrit*(1-1e-10)
        left = delta-2*pi;
        while ps(left) > 0
            left = left-2*pi;
            assert(delta-left < 40*pi,'Could not bracket washboard turning point.');
        end
        xT = fzero(ps,[left delta],optimset('TolX',1e-12,'Display','off'));
        lower = xT;
    else
        lower = delta-2*pi;
        while washboard_Rprime(lower,alpha,F,delta,xs,A) >= 0
            lower = lower-2*pi;
            assert(delta-lower < 40*pi,'Could not bracket washboard LIM minimum.');
        end
    end
    xstar = fminbnd(objective,lower,xs,optimset('TolX',1e-12,'Display','off'));
    R = sqrt(objective(xstar));
    residual = abs(washboard_Rprime(xstar,alpha,F,delta,xs,A));
    assert(isfinite(R) && residual < 1e-6,'Washboard reference check failed.');
end

function value = washboard_Rprime(x,alpha,F,delta,xs,A)
    p = A(x)-exp(2*alpha*(xs-x))*A(xs);
    pprime = 2*(F-sin(x))-2*alpha*p;
    value = 2*(x-delta)+pprime;
end

function [R,residual] = reference_quadratic_cubic(a)
    p = @(x) (2*a^2*x.^2-2*a^2*x-2*a*x+2*a ...
        -(1-a)*expm1(2*a*(1-x)))/(2*a^3);
    left = -2;
    while p(left) > 0, left = left*1.25; end
    xL = fzero(p,[left 0],optimset('TolX',1e-12,'Display','off'));
    D = (a-1)/(a+1)*exp(2*a-1);
    w = fzero(@(u)u.*exp(u)-D,[-1 0],optimset('TolX',1e-12,'Display','off'));
    xint = (1+w)/(2*a);
    R = min(abs(xL),xint*sqrt(1+1/a));
    residual = max(abs(p(xL)),abs(w*exp(w)-D));
end

function [R,residual] = reference_bistable_duffing(a)
    p = @(x) (-4*a^3*x.^3+6*a^2*x.^2+(4*a^3-6*a)*x ...
        -(3-2*a^2)*expm1(-2*a*x))/(4*a^4);
    left = -2;
    while p(left) > 0, left = left*1.25; end
    xL = fzero(p,[left -1],optimset('TolX',1e-12,'Display','off'));
    g = @(x) a*p(x)-2*x-1+x.^3;
    xs = linspace(xL,0,4097); gs = g(xs); roots = [];
    for i = 1:numel(xs)-1
        if gs(i)*gs(i+1) < 0
            roots(end+1) = fzero(g,[xs(i) xs(i+1)], ...
                optimset('TolX',1e-12,'Display','off')); %#ok<AGROW>
        end
    end
    candidates = unique([xL roots 0]);
    values = (candidates+1).^2+max(0,p(candidates));
    R = sqrt(min(values));
    residual = abs(p(xL));
end

function dx = model_rhs(~,x,par,benchmarkName)
    switch char(benchmarkName)
        case 'quadratic_cubic'
            restoring = x(1)-x(1)^2;
        case 'bistable_duffing'
            restoring = -x(1)+x(1)^3;
        case 'cosine_quadratic_drag'
            restoring = sin(x(1));
        case 'tilted_washboard'
            restoring = sin(x(1))-par.F;
        otherwise
            error('Unknown benchmark: %s',benchmarkName);
    end
    dx = [x(2); -par.alpha*abs(x(2))*x(2)-restoring];
end

function write_sistema_file(modelDir,name)
    pathName = fullfile(modelDir,'sistema.m');
    fid = fopen(pathName,'w');
    assert(fid >= 0,'Could not create %s',pathName);
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'function dx = sistema(~,x,par)\n');
    fprintf(fid,'dx=zeros(2,1); dx(1)=x(2);\n');
    switch name
        case 'quadratic_cubic'
            fprintf(fid,'dx(2)=-par.alpha*abs(x(2))*x(2)-x(1)+x(1)^2;\n');
        case 'bistable_duffing'
            fprintf(fid,'dx(2)=-par.alpha*abs(x(2))*x(2)+x(1)-x(1)^3;\n');
        case 'cosine_quadratic_drag'
            fprintf(fid,'dx(2)=-par.alpha*abs(x(2))*x(2)-sin(x(1));\n');
        case 'tilted_washboard'
            fprintf(fid,'dx(2)=-par.alpha*abs(x(2))*x(2)-sin(x(1))+par.F;\n');
    end
    fprintf(fid,'end\n');
end

function vals = struct_to_original_optional_order(args,xe0)
    dim = numel(xe0);
    defaults = struct('tfinal',1000,'Ts',0.05,'weight',ones(1,dim), ...
        'type_x0',1,'reltol',1e-6,'abstol',1e-6,'number_of_steps',50, ...
        'num_of_cell_around_equilibrium',3,'num_fig',1001, ...
        'plot_results',0,'plot_results_final',0, ...
        'spaceboundary',[xe0-10 xe0+10],'discr',1001,'automatic',0, ...
        'var1',1,'var2',2,'rep_fix_point',40,'rep_periodic',10, ...
        'min_periodic_radius',0.005,'check_min_periodic',0, ...
        'check_equilibrium',1,'max_check_step',10000,'divR',40, ...
        'num_gen',5,'num_crossover',9,'selected_opt',3,'newcomers',8, ...
        'num_almost_clones',2,'bis_iter_max',5);
    names = fieldnames(args);
    for i = 1:numel(names), defaults.(names{i}) = args.(names{i}); end
    order = {'tfinal','Ts','weight','type_x0','reltol','abstol', ...
        'number_of_steps','num_of_cell_around_equilibrium','num_fig', ...
        'plot_results','plot_results_final','spaceboundary','discr', ...
        'automatic','var1','var2','rep_fix_point','rep_periodic', ...
        'min_periodic_radius','check_min_periodic','check_equilibrium', ...
        'max_check_step','divR','num_gen','num_crossover','selected_opt', ...
        'newcomers','num_almost_clones','bis_iter_max'};
    vals = cell(size(order));
    for i = 1:numel(order), vals{i} = defaults.(order{i}); end
end

function keys = completed_run_keys(raw)
    if isempty(raw) || ~ismember('run_key',raw.Properties.VariableNames)
        keys = strings(0,1);
    else
        keys = string(raw.run_key);
    end
end

function key = make_run_key(caseId,profileId,seed)
    key = string(sprintf('%s__%s__seed_%03d',caseId,profileId,seed));
end

function cfg = table_row_to_struct(row)
    cfg = table2struct(row);
end

function value = safe_scalar_field(s,name)
    value = NaN;
    if isstruct(s) && isfield(s,name)
        candidate = s.(name);
        if isnumeric(candidate) && isscalar(candidate), value = candidate; end
    end
end

function value = count_trajectory_evaluations(OutL)
    value = NaN;
    if isstruct(OutL) && isfield(OutL,'r_end')
        value = numel(OutL.r_end);
    elseif isstruct(OutL) && isfield(OutL,'time_steps_sim')
        value = numel(OutL.time_steps_sim);
    end
end

function value = sum_finite_field(s,name)
    value = NaN;
    if isstruct(s) && isfield(s,name)
        x = s.(name); x = x(isfinite(x));
        if ~isempty(x), value = sum(x); end
    end
end

function value = safe_ratio(numeratorMask,denominatorMask)
    n = nnz(denominatorMask);
    if n == 0, value = NaN;
    else, value = nnz(numeratorMask & denominatorMask)/n;
    end
end

function value = median_finite(x)
    x = x(isfinite(x));
    if isempty(x), value = NaN; else, value = median(x); end
end

function value = mean_finite(x)
    x = x(isfinite(x));
    if isempty(x), value = NaN; else, value = mean(x); end
end

function value = max_finite(x)
    x = x(isfinite(x));
    if isempty(x), value = NaN; else, value = max(x); end
end

function value = percentile_finite(x,p)
    x = sort(x(isfinite(x)));
    if isempty(x), value = NaN; return; end
    if isscalar(x), value = x; return; end
    q = 1+(numel(x)-1)*p/100;
    lo = floor(q); hi = ceil(q);
    value = x(lo)+(q-lo)*(x(hi)-x(lo));
end

function atomic_write_table(T,pathName)
    [folder,name,extension] = fileparts(pathName);
    tempName = fullfile(folder,[name '.tmp' extension]);
    writetable(T,tempName,'FileType','text');
    movefile(tempName,pathName,'f');
end

function assert_same_file(actual,expected,label)
    normalize = @(p) lower(strrep(char(p),'/','\'));
    assert(strcmp(normalize(actual),normalize(expected)), ...
        'Wrong %s resolved. Expected %s, got %s.',label,expected,actual);
end

function write_manifest(pathName,benchmarkName,runMode,seedList, ...
        functionDir,modelDir,scheduleSeed,cases,design)
    fid = fopen(pathName,'w');
    assert(fid >= 0,'Could not write manifest.');
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'Experiment C: physics-guided DynIn GA tuning\n');
    fprintf(fid,'Created: %s\n',char(datetime('now')));
    fprintf(fid,'Benchmark: %s\n',benchmarkName);
    fprintf(fid,'Mode: %s\n',runMode);
    fprintf(fid,'Seeds: %s\n',mat2str(seedList));
    fprintf(fid,'Schedule seed: %d\n',scheduleSeed);
    fprintf(fid,'Original functions: %s\n',functionDir);
    fprintf(fid,'Generated model: %s\n',modelDir);
    fprintf(fid,'Cases: %d; design rows: %d\n',height(cases),height(design));
    fprintf(fid,'Original DynIn source is not modified; type_x0 = 1.\n');
    fprintf(fid,'References are scoring-only and do not choose hyperparameters.\n');
    fprintf(fid,'Physics inputs: equilibria, saddle barriers, local frequency, damping.\n');
    fprintf(fid,'Cumulative blocks: geometry, decay time/sampling, periodic threshold.\n');
    fprintf(fid,'Frozen GA controls: divR=40, generations=5, population=20.\n');
end
