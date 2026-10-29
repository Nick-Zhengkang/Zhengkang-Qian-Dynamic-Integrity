function outputDirectory = run_separable_4d_analytic_benchmark( ...
        runMode,alphaQC,alphaBD,seedList,resumeDirectory,methodList)
%RUN_SEPARABLE_4D_ANALYTIC_BENCHMARK Compare three 4D radial searches.
%
% The model is the direct product of Genda's quadratic-cubic and bistable
% Duffing systems with quadratic drag. Its exact LIM in the block Euclidean
% metric is min(R_QC,R_BD). The reference is used only for scoring.
%
% The experiment compares three point-selection rules with the same model,
% metric, trajectory classifier, radial tolerance, budgets, and seeds:
%   1. fixed_s3_radial_24
%   2. adaptive_s3_radial
%   3. adaptive_s3_with_trajectory_reuse
%
% Directions live on the unit three-sphere S^3 in weighted coordinates:
%       z0 = ze + r * W^(-1/2) * u,  ||u||_2 = 1.
%
% The adaptive methods refine tangent directions around the best rays and
% add maximin directions in the largest uncovered angular region. A result
% is called converged only after local and two independent global checks.

    % Opt-in verification interface; ordinary benchmark calls are unchanged.
    if nargin>=1 && string(runMode)=="refinement_api"
        outputDirectory=struct('configuration',@experiment_configuration, ...
            'problem',@build_problem,'search',@execute_search, ...
            'state',@initialize_oracle_state,'ray',@search_one_ray, ...
            'reference',@analytical_reference,'rhs',@separable_rhs, ...
            'classify',@classify_initial_condition);
        return
    end
    if nargin < 1 || strlength(string(runMode)) == 0
        runMode = "pilot";
    end
    if nargin < 2 || isempty(alphaQC)
        alphaQC = 0.4;
    end
    if nargin < 3 || isempty(alphaBD)
        alphaBD = 0.7;
    end
    if nargin < 4 || isempty(seedList)
        if string(runMode) == "full"
            seedList = 1:30;
        else
            seedList = 1:3;
        end
    end
    if nargin < 5
        resumeDirectory = "";
    end
    if nargin < 6 || isempty(methodList)
        methodList = ["fixed_s3_radial_24", ...
            "adaptive_s3_radial", ...
            "adaptive_s3_with_trajectory_reuse"];
    end

    runMode = string(runMode);
    alphaQC = double(alphaQC);
    alphaBD = double(alphaBD);
    seedList = double(seedList(:).');
    cfg = experiment_configuration(runMode);
    [reference,referenceAuditQC,referenceAuditBD] = ...
        analytical_reference(alphaQC,alphaBD);

    here = fileparts(mfilename('fullpath'));

    if strlength(string(resumeDirectory)) > 0
        outputDirectory = char(resumeDirectory);
        assert(isfolder(outputDirectory), ...
            'Resume directory does not exist: %s',outputDirectory);
    else
        stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
        outputDirectory = fullfile(here,['outputs_separable_4d_' stamp]);
        mkdir(outputDirectory);
    end
    detailDirectory = fullfile(outputDirectory,'run_details');
    if ~isfolder(detailDirectory), mkdir(detailDirectory); end

    methods = string(methodList(:).');
    allowedMethods = ["fixed_s3_radial_24", ...
        "adaptive_s3_radial", ...
        "adaptive_s3_with_trajectory_reuse"];
    assert(~isempty(methods) && all(ismember(methods,allowedMethods)) && ...
        numel(unique(methods))==numel(methods), ...
        'methodList contains an unknown or duplicate method.');
    schedule = build_schedule(seedList,methods,cfg.scheduleSeed);
    schedulePath = fullfile(outputDirectory, ...
        'randomized_execution_schedule.csv');
    atomic_write_table(schedule,schedulePath);
    rawPath = fullfile(outputDirectory,'raw_data_all_runs.csv');
    if isfile(rawPath)
        raw = readtable(rawPath,'TextType','string');
    else
        raw = table();
    end
    completed = strings(0,1);
    if ~isempty(raw) && ismember('run_key',raw.Properties.VariableNames)
        validCompleted = true(height(raw),1);
        if ismember('success',raw.Properties.VariableNames)
            validCompleted = validCompleted & logical(raw.success);
        end
        if ismember('R_hat',raw.Properties.VariableNames)
            validCompleted = validCompleted & isfinite(raw.R_hat);
        end
        completed = string(raw.run_key(validCompleted));
    end

    writetable(struct2table(reference),fullfile(outputDirectory, ...
        'analytical_reference.csv'));
    writetable(referenceAuditQC,fullfile(outputDirectory, ...
        'reference_audit_quadratic_cubic.csv'));
    writetable(referenceAuditBD,fullfile(outputDirectory, ...
        'reference_audit_bistable_duffing.csv'));
    write_configuration(outputDirectory,cfg,runMode,alphaQC,alphaBD, ...
        seedList,reference);
    fprintf('Separable analytical 4D benchmark: %s mode\n',runMode);
    fprintf('alpha_QC=%.3f, alpha_BD=%.3f, exact R_4D=%.12g\n', ...
        alphaQC,alphaBD,reference.R_4D);
    fprintf('Methods: %d; seeds: %d; scheduled runs: %d\n', ...
        numel(methods),numel(seedList),height(schedule));
    fprintf('Output directory:\n%s\n\n',outputDirectory);

    oldRng = rng;
    restoreRng = onCleanup(@() rng(oldRng)); %#ok<NASGU>
    for iRun = 1:height(schedule)
        item = schedule(iRun,:);
        key = string(item.run_key);
        if any(completed == key)
            fprintf('[run %d/%d] SKIP %s\n',iRun,height(schedule),key);
            continue
        end

        problem = build_problem(alphaQC,alphaBD,cfg);
        fprintf('[run %d/%d] START seed=%d, method=%s\n', ...
            iRun,height(schedule),item.seed,item.method);
        timer = tic;
        try
            [result,details] = execute_search(problem,cfg, ...
                string(item.method),item.algorithm_seed);
            success = isfinite(result.R_hat);
            errorMessage = "";
        catch ME
            result = failed_result(string(item.method));
            details = struct('error_report', ...
                string(getReport(ME,'extended','hyperlinks','off')));
            success = false;
            errorMessage = string(getReport(ME,'basic','hyperlinks','off'));
        end
        wall = toc(timer);

        row = struct();
        row.run_key = key;
        row.execution_order = item.execution_order;
        row.alpha_qc = alphaQC;
        row.alpha_bd = alphaBD;
        row.seed = item.seed;
        row.algorithm_seed = item.algorithm_seed;
        row.method = string(item.method);
        row.success = success;
        row.R_hat = result.R_hat;
        row.R_reference = reference.R_4D;
        row.absolute_error = abs(result.R_hat-reference.R_4D);
        row.relative_error = row.absolute_error/reference.R_4D;
        row.signed_relative_error = ...
            (result.R_hat-reference.R_4D)/reference.R_4D;
        row.within_1_percent = row.relative_error<=0.01;
        row.within_2_percent = row.relative_error<=0.02;
        row.within_5_percent = row.relative_error<=0.05;
        row.stop_status = result.stop_status;
        row.query_count = result.query_count;
        row.integration_count = result.integration_count;
        row.direction_count = result.direction_count;
        row.direction_budget = cfg.maxDirections;
        row.direction_budget_respected = ...
            result.direction_count<=cfg.maxDirections;
        row.unresolved_count = result.unresolved_count;
        row.local_delta_final_rad = result.local_delta_final_rad;
        row.global_validation_passes = result.global_validation_passes;
        row.post_audit_R_hat = result.post_audit_R_hat;
        row.post_audit_relative_drop = result.post_audit_relative_drop;
        row.post_audit_status = result.post_audit_status;
        row.post_audit_pass = result.post_audit_pass;
        row.post_audit_query_count = result.post_audit_query_count;
        row.post_audit_integration_count = result.post_audit_integration_count;
        row.post_audit_direction_count = result.post_audit_direction_count;
        row.algorithm_runtime_s = result.algorithm_runtime_s;
        row.wall_runtime_s = wall;
        row.error_message = errorMessage;

        % A resumed run replaces its earlier unsuccessful record instead of
        % creating a duplicate run_key in the raw table.
        if ~isempty(raw) && ismember('run_key',raw.Properties.VariableNames)
            raw(string(raw.run_key)==key,:) = [];
        end
        raw = append_struct_row(raw,row);
        atomic_write_table(raw,rawPath);
        detailPath = fullfile(detailDirectory, ...
            [matlab.lang.makeValidName(char(key)) '.mat']);
        save(detailPath,'details','problem','cfg','-v7.3');
        completed(end+1,1) = key; %#ok<AGROW>

        fprintf(['[run %d/%d] DONE R=%.6g, status=%s, queries=%g, ' ...
            'audit.drop=%.3g%%, wall=%.2fs\n'],iRun,height(schedule), ...
            result.R_hat,char(result.stop_status),result.query_count, ...
            100*result.post_audit_relative_drop,wall);
    end

    raw = readtable(rawPath,'TextType','string');
    summary = summarize_runs(raw);
    summaryPath = fullfile(outputDirectory,'summary_by_method.csv');
    atomic_write_table(summary,summaryPath);
    paired = summarize_paired_contrasts(raw);
    pairedPath = fullfile(outputDirectory,'paired_contrasts_by_seed.csv');
    atomic_write_table(paired,pairedPath);
    fprintf(['\nSeparable 4D experiment finished.\nRaw: %s\nSummary: %s\n' ...
        'Paired contrasts: %s\nSchedule: %s\n'], ...
        rawPath,summaryPath,pairedPath,schedulePath);
end

function cfg = experiment_configuration(runMode)
    cfg = struct();
    cfg.runMode = string(runMode);

    % Common classifier settings for z=[x,xdot,y,ydot]. The target is the
    % product equilibrium (0,0) x (-1,0), and W=I is used throughout.
    cfg.target = [0 0 -1 0];
    cfg.lower = [-4 -4 -4 -4];
    cfg.upper = [2 4 2 4];
    cfg.discr = 801;
    cfg.targetCells = 7;
    cfg.tfinal = 1200;
    cfg.Ts = 0.05;
    cfg.RelTol = 1e-8;
    cfg.AbsTol = 1e-8;
    cfg.MaxStep = 0.25;
    cfg.repFixPoint = 40;
    cfg.repPeriodic = 5;
    cfg.minPeriodicRadius = 0.005;
    cfg.retryUnresolved = true;
    cfg.retryHorizonFactor = 2;

    % Common radial search settings.
    cfg.initialDirections = 24;
    % Strict core-algorithm cap. The post-stop audit has its own separately
    % reported direction budget and is not counted against this value.
    cfg.maxDirections = 200;
    cfg.maxRadius = 1.5;
    cfg.scanStep = 0.05;
    cfg.radialTolerance = 1e-4;
    cfg.queryBudget = 700;
    cfg.maxWallSeconds = 3600;

    % Four-dimensional adaptive direction settings.
    cfg.localCenters = 3;
    cfg.localDeltaInitial = 12*pi/180;
    cfg.localDeltaMinimum = 1*pi/180;
    cfg.localNoImprovementSweeps = 2;
    cfg.centerSeparation = 8*pi/180;
    cfg.duplicateAngle = 0.25*pi/180;
    cfg.globalCandidatePool = 1024;
    cfg.globalValidationBatch = 16;
    cfg.requiredGlobalPasses = 2;
    cfg.maxRefinementRounds = 20;
    cfg.stopRelativeImprovement = 2e-3;
    cfg.stopAbsoluteImprovement = 2e-5;

    % Independent post-stop audit. This budget is not included in R_hat.
    cfg.postAuditDirections = 16;
    cfg.postAuditBudget = 220;
    cfg.scheduleSeed = 20260926;

    % A smoke mode exists only for syntax/integration checks. It is not a
    % scientific configuration and must not be mixed with pilot/full data.
    if string(runMode) == "smoke"
        cfg.tfinal = 2;
        cfg.retryUnresolved = false;
        cfg.initialDirections = 4;
        cfg.maxDirections = 6;
        cfg.queryBudget = 12;
        cfg.maxRefinementRounds = 1;
        cfg.globalValidationBatch = 1;
        cfg.requiredGlobalPasses = 1;
        cfg.postAuditDirections = 1;
        cfg.postAuditBudget = 2;
        cfg.maxWallSeconds = 120;
    elseif ~any(string(runMode) == ["pilot","full"])
        error('runMode must be "pilot", "full", or "smoke".');
    end
end

function schedule = build_schedule(seedList,methods,scheduleSeed)
    n = numel(seedList)*numel(methods);
    seed = zeros(n,1);
    algorithmSeed = zeros(n,1);
    method = strings(n,1);
    runKey = strings(n,1);
    k = 0;
    for iSeed = 1:numel(seedList)
        for iMethod = 1:numel(methods)
            k = k+1;
            seed(k) = seedList(iSeed);
            algorithmSeed(k) = scheduleSeed + seed(k);
            method(k) = methods(iMethod);
            runKey(k) = sprintf('seed_%03d__%s',seed(k),method(k));
        end
    end
    stream = RandStream('mt19937ar','Seed',scheduleSeed);
    order = randperm(stream,n).';
    schedule = table(seed(order),algorithmSeed(order), ...
        method(order),runKey(order),'VariableNames', ...
        {'seed','algorithm_seed','method','run_key'});
    schedule.execution_order = (1:n).';
    schedule = movevars(schedule,'execution_order','Before',1);
end

function problem = build_problem(alphaQC,alphaBD,cfg)
    problem = struct();
    problem.name = "separable quadratic-cubic x bistable Duffing";
    problem.alphaQC = alphaQC;
    problem.alphaBD = alphaBD;
    problem.weight = ones(1,4);
    problem.sqrtWeight = sqrt(problem.weight);
    problem.target = cfg.target;
    problem.lower = cfg.lower;
    problem.upper = cfg.upper;
    problem.cellWidth = (problem.upper-problem.lower)/cfg.discr;
    problem.targetHalfWidth = 0.5*cfg.targetCells*problem.cellWidth;
    problem.targetMetricRadius = sqrt(sum( ...
        problem.weight.*problem.targetHalfWidth.^2));
end

function [result,details] = execute_search(problem,cfg,method,seed)
    timer = tic;
    stream = RandStream('mt19937ar','Seed',seed);
    directions = initial_s3_directions(stream,cfg.initialDirections);
    allowAdaptive = method ~= "fixed_s3_radial_24";
    allowReuse = method == "adaptive_s3_with_trajectory_reuse";

    state = initialize_oracle_state();
    rays = empty_ray_array();
    best = Inf;
    hardStatus = "";
    for i = 1:size(directions,1)
        [state,rays,best,hardStatus] = evaluate_direction( ...
            state,rays,best,directions(i,:),NaN,allowReuse, ...
            problem,cfg,cfg.queryBudget,timer);
        if strlength(hardStatus)>0, break; end
    end

    localDelta = NaN;
    globalPasses = 0;
    if strlength(hardStatus)>0
        stopStatus = hardStatus;
    elseif ~isfinite(best)
        stopStatus = "boundary_not_found";
    elseif ~allowAdaptive
        stopStatus = "fixed_direction_set_complete";
    else
        localDelta = cfg.localDeltaInitial;
        noImproveSweeps = 0;
        stopStatus = "";
        for iRound = 1:cfg.maxRefinementRounds
            if numel(rays) >= cfg.maxDirections
                stopStatus = "direction_limit_reached";
                break
            end
            beforeRound = best;
            centers = select_local_centers(rays,cfg.localCenters, ...
                cfg.centerSeparation);
            localCandidates = tangent_candidates(centers,localDelta);
            for i = 1:size(localCandidates,1)
                if is_duplicate_direction(localCandidates(i,:),rays, ...
                        cfg.duplicateAngle)
                    continue
                end
                [state,rays,best,hardStatus] = evaluate_direction( ...
                    state,rays,best,localCandidates(i,:),NaN,allowReuse, ...
                    problem,cfg,cfg.queryBudget,timer);
                if strlength(hardStatus)>0 || numel(rays)>=cfg.maxDirections
                    break
                end
            end
            if strlength(hardStatus)>0
                stopStatus = hardStatus;
                break
            end

            globalDirection = choose_maximin_direction( ...
                stream,rays,cfg.globalCandidatePool);
            [state,rays,best,hardStatus] = evaluate_direction( ...
                state,rays,best,globalDirection,NaN,allowReuse, ...
                problem,cfg,cfg.queryBudget,timer);
            if strlength(hardStatus)>0
                stopStatus = hardStatus;
                break
            end

            if meaningful_improvement(beforeRound,best,cfg)
                noImproveSweeps = 0;
                globalPasses = 0;
            else
                noImproveSweeps = noImproveSweeps+1;
                localDelta = max(cfg.localDeltaMinimum,localDelta/2);
            end

            localReady = localDelta<=cfg.localDeltaMinimum*(1+eps) && ...
                noImproveSweeps>=cfg.localNoImprovementSweeps;
            if localReady
                validationStart = best;
                completedValidation = 0;
                for i = 1:cfg.globalValidationBatch
                    if numel(rays)>=cfg.maxDirections
                        hardStatus = "direction_limit_reached";
                        break
                    end
                    u = choose_maximin_direction( ...
                        stream,rays,cfg.globalCandidatePool);
                    [state,rays,best,hardStatus] = evaluate_direction( ...
                        state,rays,best,u,NaN,false,problem,cfg, ...
                        cfg.queryBudget,timer);
                    if strlength(hardStatus)>0, break; end
                    completedValidation = completedValidation+1;
                end
                if strlength(hardStatus)>0
                    stopStatus = hardStatus;
                    break
                elseif completedValidation < cfg.globalValidationBatch
                    stopStatus = "direction_limit_reached";
                    break
                elseif meaningful_improvement(validationStart,best,cfg)
                    globalPasses = 0;
                    noImproveSweeps = 0;
                    localDelta = max(2*cfg.localDeltaMinimum,localDelta);
                else
                    globalPasses = globalPasses+1;
                end
                if globalPasses>=cfg.requiredGlobalPasses && ...
                        all_radial_results_resolved(rays,cfg) && ...
                        state.unresolvedCount==0
                    stopStatus = "converged_local_and_global";
                    break
                end
            end
        end
        if strlength(stopStatus)==0
            stopStatus = "maximum_refinement_rounds";
        end
    end

    preAuditBest = best;
    preAuditQueryCount = state.queryCount;
    preAuditIntegrationCount = state.integrationCount;
    preAuditDirectionCount = numel(rays);
    preAuditUnresolvedCount = state.unresolvedCount;
    algorithmRuntime = toc(timer);
    [state,rays,postAuditBest,auditStatus,auditPass] = post_stop_audit( ...
        state,rays,best,stream,problem,cfg,tic);
    relativeDrop = relative_improvement(preAuditBest,postAuditBest);

    result = struct();
    if isfinite(preAuditBest), result.R_hat = preAuditBest;
    else, result.R_hat = NaN; end
    result.stop_status = stopStatus;
    result.query_count = preAuditQueryCount;
    result.integration_count = preAuditIntegrationCount;
    result.direction_count = preAuditDirectionCount;
    result.unresolved_count = preAuditUnresolvedCount;
    result.local_delta_final_rad = localDelta;
    result.global_validation_passes = globalPasses;
    result.post_audit_R_hat = finite_or_nan(postAuditBest);
    result.post_audit_relative_drop = relativeDrop;
    result.post_audit_status = auditStatus;
    result.post_audit_pass = auditPass;
    result.post_audit_query_count = state.queryCount-preAuditQueryCount;
    result.post_audit_integration_count = ...
        state.integrationCount-preAuditIntegrationCount;
    result.post_audit_direction_count = numel(rays)-preAuditDirectionCount;
    result.algorithm_runtime_s = algorithmRuntime;

    details = struct();
    details.method = method;
    details.seed = seed;
    details.rays = rays;
    details.query_records = state.records;
    details.pre_audit_R_hat = finite_or_nan(preAuditBest);
    details.post_audit_R_hat = finite_or_nan(postAuditBest);
    details.stop_status = stopStatus;
    details.audit_status = auditStatus;
end

function state = initialize_oracle_state()
    state = struct();
    state.queryCount = 0;
    state.integrationCount = 0;
    state.unresolvedCount = 0;
    state.cache = containers.Map('KeyType','char','ValueType','any');
    state.records = cell(0,1);
end

function [state,rays,best,hardStatus] = evaluate_direction( ...
        state,rays,best,u,knownUpper,allowReuse,problem,cfg,queryLimit,timer)
    hardStatus = "";
    chainCount = 0;
    while true
        if numel(rays)>=cfg.maxDirections
            hardStatus = "direction_limit_reached";
            return
        end
        [state,ray,reuseCandidate] = search_one_ray( ...
            state,u,knownUpper,best,problem,cfg,queryLimit,timer);
        rays(end+1,1) = ray; %#ok<AGROW>
        if ray.status == "unresolved"
            hardStatus = "unresolved_classification";
            return
        elseif ray.status == "query_budget_exhausted"
            hardStatus = "query_budget_exhausted";
            return
        elseif ray.status == "wall_time_exhausted"
            hardStatus = "wall_time_exhausted";
            return
        end
        if isfinite(ray.boundary_radius)
            best = min(best,ray.boundary_radius);
        end
        if ~allowReuse || ~reuseCandidate.valid || chainCount>=3
            return
        end
        if reuseCandidate.upper_radius >= best*(1-cfg.stopRelativeImprovement)
            return
        end
        if is_duplicate_direction(reuseCandidate.direction,rays, ...
                cfg.duplicateAngle)
            return
        end
        u = reuseCandidate.direction;
        knownUpper = reuseCandidate.upper_radius;
        chainCount = chainCount+1;
    end
end

function [state,ray,reuseCandidate] = search_one_ray( ...
        state,u,knownUpper,currentBest,problem,cfg,queryLimit,timer)
    u = u(:).'/norm(u);
    startQueries = state.queryCount;
    startRecord = numel(state.records);
    rLimit = min(cfg.maxRadius,radial_domain_limit(u,problem));
    lo = 0;
    hi = NaN;
    status = "ok";

    if toc(timer)>cfg.maxWallSeconds
        status = "wall_time_exhausted";
    elseif isfinite(knownUpper)
        hi = min(knownUpper,rLimit);
    elseif isfinite(currentBest)
        testRadius = min(rLimit,currentBest*(1-0.5*cfg.stopRelativeImprovement));
        if testRadius<=cfg.radialTolerance
            status = "pruned_by_incumbent";
        else
            [state,q] = query_at_radius( ...
                state,u,testRadius,problem,cfg,queryLimit);
            if q.label == "target"
                status = "pruned_by_incumbent";
            elseif q.label == "non_target"
                hi = testRadius;
            elseif q.label == "unresolved"
                status = "unresolved";
            else
                status = "query_budget_exhausted";
            end
        end
    else
        scanRadii = cfg.scanStep:cfg.scanStep:rLimit;
        if isempty(scanRadii) || scanRadii(end)<rLimit-10*eps(rLimit)
            scanRadii(end+1) = rLimit; %#ok<AGROW>
        end
        for radius = scanRadii
            [state,q] = query_at_radius( ...
                state,u,radius,problem,cfg,queryLimit);
            if q.label == "target"
                lo = radius;
            elseif q.label == "non_target"
                hi = radius;
                break
            elseif q.label == "unresolved"
                status = "unresolved";
                break
            else
                status = "query_budget_exhausted";
                break
            end
        end
        if status=="ok" && ~isfinite(hi)
            status = "boundary_not_found_on_ray";
        end
    end

    if status=="ok" && isfinite(hi)
        while hi-lo>cfg.radialTolerance
            if toc(timer)>cfg.maxWallSeconds
                status = "wall_time_exhausted";
                break
            end
            mid = 0.5*(lo+hi);
            [state,q] = query_at_radius( ...
                state,u,mid,problem,cfg,queryLimit);
            if q.label == "target"
                lo = mid;
            elseif q.label == "non_target"
                hi = mid;
            elseif q.label == "unresolved"
                status = "unresolved";
                break
            else
                status = "query_budget_exhausted";
                break
            end
        end
    end

    if status=="ok" && isfinite(hi)
        boundary = 0.5*(lo+hi);
        width = hi-lo;
    else
        boundary = Inf;
        width = NaN;
    end
    reuseCandidate = closest_trajectory_candidate( ...
        state.records,startRecord+1,numel(state.records),problem);
    ray = struct();
    ray.direction = u;
    ray.boundary_radius = boundary;
    ray.bracket_lower = lo;
    ray.bracket_upper = hi;
    ray.bracket_width = width;
    ray.status = status;
    ray.queries_used = state.queryCount-startQueries;
    ray.known_upper_radius = knownUpper;
    ray.trajectory_candidate_radius = reuseCandidate.upper_radius;
end

function [state,result] = query_at_radius( ...
        state,u,radius,problem,cfg,queryLimit)
    z0 = problem.target + radius*u./problem.sqrtWeight;
    key = sprintf('%.12e,',z0);
    if isKey(state.cache,key)
        result = state.cache(key);
        result.from_cache = true;
        return
    end
    if state.queryCount>=queryLimit
        result = empty_query_result("budget");
        return
    end

    state.queryCount = state.queryCount+1;
    [result,nIntegrations] = classify_initial_condition(z0,problem,cfg);
    state.integrationCount = state.integrationCount+nIntegrations;
    if result.label=="unresolved"
        state.unresolvedCount = state.unresolvedCount+1;
    end
    result.from_cache = false;
    state.cache(key) = result;
    record = result;
    record.query_id = state.queryCount;
    record.initial_state = z0;
    record.initial_radius = radius;
    state.records{end+1,1} = record;
end

function [result,nIntegrations] = classify_initial_condition(z0,problem,cfg)
    if isfield(cfg,'classifierOverride')
        [result,nIntegrations] = cfg.classifierOverride(z0,problem,cfg);
        return
    end
    [result,nIntegrations] = integrate_and_classify(z0,problem,cfg,cfg.tfinal);
    if result.label=="unresolved" && cfg.retryUnresolved
        firstRuntime = result.integration_runtime_s;
        firstSamples = result.sample_count;
        [retryResult,nRetry] = integrate_and_classify( ...
            z0,problem,cfg,cfg.retryHorizonFactor*cfg.tfinal);
        nIntegrations = nIntegrations+nRetry;
        retryResult.retried = true;
        retryResult.integration_runtime_s = ...
            firstRuntime+retryResult.integration_runtime_s;
        retryResult.sample_count = firstSamples+retryResult.sample_count;
        result = retryResult;
    end
end

function [result,nIntegrations] = integrate_and_classify( ...
        z0,problem,cfg,horizon)
    nIntegrations = 1;
    result = empty_query_result("unresolved");
    result.horizon_used = horizon;
    result.retried = false;
    if any(z0<=problem.lower) || any(z0>=problem.upper)
        result.label = "non_target";
        result.classification_reason = "initial_state_outside_domain";
        result.min_radius = weighted_radius(z0,problem);
        result.min_point = z0;
        return
    end
    if all(abs(z0-problem.target)<=problem.targetHalfWidth)
        result.label = "target";
        result.classification_reason = "initial_state_in_target_belt";
        result.min_radius = weighted_radius(z0,problem);
        result.min_point = z0;
        return
    end

    outputTimes = 0:cfg.Ts:horizon;
    if outputTimes(end)<horizon, outputTimes(end+1)=horizon; end %#ok<AGROW>
    options = odeset('RelTol',cfg.RelTol,'AbsTol',cfg.AbsTol, ...
        'MaxStep',cfg.MaxStep,'Events', ...
        @(t,z) classification_events(t,z,problem));
    timer = tic;
    try
        [~,states,~,~,eventIndex] = ode45( ...
            @(t,z) separable_rhs(z,problem),outputTimes,z0(:),options);
        result.integration_runtime_s = toc(timer);
        result.sample_count = size(states,1);
    catch ME
        result.integration_runtime_s = toc(timer);
        result.classification_reason = "ode_failure: " + string(ME.message);
        result.min_radius = NaN;
        result.min_point = nan(1,4);
        return
    end

    radii = sqrt(sum((states-problem.target).^2.*problem.weight,2));
    [result.min_radius,indexMin] = min(radii);
    result.min_point = states(indexMin,:);
    if any(eventIndex==2)
        result.label = "target";
        result.classification_reason = "entered_target_belt";
        return
    elseif any(eventIndex==1)
        result.label = "non_target";
        result.classification_reason = "left_computational_domain";
        return
    end

    [isFixed,isPeriodic] = classify_recurrence(states,problem,cfg);
    if isFixed
        result.label = "non_target";
        result.classification_reason = "new_fixed_point_cell_recurrence";
    elseif isPeriodic
        result.label = "non_target";
        result.classification_reason = "periodic_cell_recurrence";
    else
        result.label = "unresolved";
        result.classification_reason = "horizon_reached_without_classification";
    end
end

function [value,isterminal,direction] = classification_events(~,z,problem)
    z = z(:).';
    domainMargin = min([z-problem.lower,problem.upper-z]);
    targetMargin = max(abs(z-problem.target)./problem.targetHalfWidth)-1;
    value = [domainMargin;targetMargin];
    isterminal = [1;1];
    direction = [-1;-1];
end

function dz = separable_rhs(z,problem)
    z = z(:);
    dz = zeros(4,1);
    dz(1)=z(2);
    dz(2)=-problem.alphaQC*abs(z(2))*z(2)-z(1)+z(1)^2;
    dz(3)=z(4);
    dz(4)=-problem.alphaBD*abs(z(4))*z(4)+z(3)-z(3)^3;
end

function [isFixed,isPeriodic] = classify_recurrence(states,problem,cfg)
    coordinates = floor((states-problem.lower)./problem.cellWidth)+1;
    coordinates = min(cfg.discr,max(1,coordinates));
    powers = cfg.discr.^((size(states,2)-1):-1:0);
    cellId = 1+(coordinates-1)*powers(:);

    isFixed = false;
    longestRun = 1;
    currentRun = 1;
    for i = 2:numel(cellId)
        if cellId(i)==cellId(i-1)
            currentRun = currentRun+1;
            longestRun = max(longestRun,currentRun);
        else
            currentRun = 1;
        end
    end
    if longestRun>cfg.repFixPoint
        isFixed = true;
        isPeriodic = false;
        return
    end

    isPeriodic = false;
    [~,~,group] = unique(cellId,'stable');
    counts = accumarray(group,1);
    candidates = find(counts>cfg.repPeriodic+1);
    for i = 1:numel(candidates)
        occurrences = find(group==candidates(i));
        nonConsecutive = find(diff(occurrences)>1);
        if numel(nonConsecutive)<=cfg.repPeriodic, continue; end
        j = nonConsecutive(end);
        first = occurrences(j);
        last = occurrences(j+1);
        segment = states(first:last,:);
        delta = segment-states(last,:);
        amplitude = max(sqrt(sum(delta.^2.*problem.weight,2)));
        if amplitude>cfg.minPeriodicRadius
            isPeriodic = true;
            return
        end
    end
end

function candidate = closest_trajectory_candidate(records,first,last,problem)
    candidate = struct('valid',false,'direction',nan(1,4), ...
        'upper_radius',Inf);
    if first>last, return; end
    for i = first:last
        r = records{i};
        if r.label~="non_target" || ~isfinite(r.min_radius), continue; end
        if r.min_radius<=1.05*problem.targetMetricRadius, continue; end
        if r.min_radius<candidate.upper_radius
            y = (r.min_point-problem.target).*problem.sqrtWeight;
            n = norm(y);
            if n>0
                candidate.valid = true;
                candidate.direction = y/n;
                candidate.upper_radius = n;
            end
        end
    end
end

function directions = initial_s3_directions(stream,count)
    corners = dec2bin(0:15)-'0';
    corners = (2*corners-1)/2;
    base = [eye(4);-eye(4);corners];
    [Q,R] = qr(randn(stream,4,4));
    signs = sign(diag(R));
    signs(signs==0)=1;
    Q = Q*diag(signs);
    directions = base*Q;
    directions = directions./vecnorm(directions,2,2);
    directions = directions(1:min(count,size(directions,1)),:);
end

function centers = select_local_centers(rays,maxCenters,separation)
    radii = [rays.boundary_radius].';
    finiteIndex = find(isfinite(radii));
    [~,order] = sort(radii(finiteIndex));
    centers = zeros(0,4);
    for k = 1:numel(order)
        u = rays(finiteIndex(order(k))).direction;
        if isempty(centers) || all(direction_angles(centers,u)>=separation)
            centers(end+1,:) = u; %#ok<AGROW>
            if size(centers,1)>=maxCenters, break; end
        end
    end
end

function candidates = tangent_candidates(centers,delta)
    candidates = zeros(0,4);
    for i = 1:size(centers,1)
        center = centers(i,:).';
        basis = null(center.');
        for j = 1:size(basis,2)
            candidates(end+1,:) = (cos(delta)*center+ ...
                sin(delta)*basis(:,j)).'; %#ok<AGROW>
            candidates(end+1,:) = (cos(delta)*center- ...
                sin(delta)*basis(:,j)).'; %#ok<AGROW>
        end
    end
    if ~isempty(candidates)
        candidates = candidates./vecnorm(candidates,2,2);
    end
end

function u = choose_maximin_direction(stream,rays,poolSize)
    pool = randn(stream,poolSize,4);
    pool = pool./vecnorm(pool,2,2);
    if isempty(rays)
        u = pool(1,:);
        return
    end
    sampled = vertcat(rays.direction);
    cosines = max(-1,min(1,pool*sampled.'));
    gaps = min(acos(cosines),[],2);
    [~,index] = max(gaps);
    u = pool(index,:);
end

function duplicate = is_duplicate_direction(u,rays,tolerance)
    if isempty(rays)
        duplicate = false;
    else
        sampled = vertcat(rays.direction);
        duplicate = min(direction_angles(sampled,u))<tolerance;
    end
end

function angles = direction_angles(directions,u)
    angles = acos(max(-1,min(1,directions*u(:))));
end

function limit = radial_domain_limit(u,problem)
    physicalDirection = u./problem.sqrtWeight;
    limits = inf(1,4);
    positive = physicalDirection>1e-14;
    negative = physicalDirection<-1e-14;
    limits(positive) = (problem.upper(positive)- ...
        problem.target(positive))./physicalDirection(positive);
    limits(negative) = (problem.lower(negative)- ...
        problem.target(negative))./physicalDirection(negative);
    limit = min(limits);
end

function yes = meaningful_improvement(oldValue,newValue,cfg)
    if ~isfinite(oldValue)
        yes = isfinite(newValue);
    elseif ~isfinite(newValue)
        yes = false;
    else
        yes = oldValue-newValue > max(cfg.stopAbsoluteImprovement, ...
            cfg.stopRelativeImprovement*abs(oldValue));
    end
end

function value = relative_improvement(oldValue,newValue)
    if isfinite(oldValue) && isfinite(newValue)
        value = max(0,(oldValue-newValue)/max(abs(oldValue),eps));
    else
        value = NaN;
    end
end

function yes = all_radial_results_resolved(rays,cfg)
    yes = true;
    for i = 1:numel(rays)
        if rays(i).status=="ok" && ...
                rays(i).bracket_width>cfg.radialTolerance*(1+10*eps)
            yes = false;
            return
        elseif any(rays(i).status==["unresolved", ...
                "query_budget_exhausted","wall_time_exhausted"])
            yes = false;
            return
        end
    end
end

function [state,rays,best,auditStatus,auditPass] = post_stop_audit( ...
        state,rays,best,stream,problem,cfg,timer)
    auditPass = false;
    if ~isfinite(best)
        auditStatus = "not_run_no_boundary";
        return
    end
    startBest = best;
    queryLimit = state.queryCount+cfg.postAuditBudget;
    completed = 0;
    for i = 1:cfg.postAuditDirections
        u = choose_maximin_direction(stream,rays,cfg.globalCandidatePool);
        [state,ray,~] = search_one_ray( ...
            state,u,NaN,best,problem,cfg,queryLimit,timer);
        rays(end+1,1) = ray; %#ok<AGROW>
        if ray.status=="unresolved"
            auditStatus = "inconclusive_unresolved";
            return
        elseif any(ray.status==["query_budget_exhausted", ...
                "wall_time_exhausted"])
            auditStatus = "incomplete_budget_or_time";
            return
        end
        if isfinite(ray.boundary_radius)
            best = min(best,ray.boundary_radius);
        end
        completed = completed+1;
    end
    if completed==cfg.postAuditDirections
        auditPass = ~meaningful_improvement(startBest,best,cfg);
        if auditPass
            auditStatus = "passed_no_material_drop";
        else
            auditStatus = "failed_material_drop_found";
        end
    else
        auditStatus = "incomplete";
    end
end

function rays = empty_ray_array()
    rays = struct('direction',{},'boundary_radius',{}, ...
        'bracket_lower',{},'bracket_upper',{},'bracket_width',{}, ...
        'status',{},'queries_used',{},'known_upper_radius',{}, ...
        'trajectory_candidate_radius',{});
end

function result = empty_query_result(label)
    result = struct();
    result.label = string(label);
    result.classification_reason = "";
    result.min_radius = NaN;
    result.min_point = nan(1,4);
    result.horizon_used = NaN;
    result.retried = false;
    result.integration_runtime_s = NaN;
    result.sample_count = NaN;
    result.from_cache = false;
end

function result = failed_result(method)
    result = struct('R_hat',NaN,'stop_status',"execution_error", ...
        'query_count',NaN,'integration_count',NaN, ...
        'direction_count',NaN,'unresolved_count',NaN, ...
        'local_delta_final_rad',NaN,'global_validation_passes',NaN, ...
        'post_audit_R_hat',NaN,'post_audit_relative_drop',NaN, ...
        'post_audit_status',"not_run",'post_audit_pass',false, ...
        'post_audit_query_count',NaN,'post_audit_integration_count',NaN, ...
        'post_audit_direction_count',NaN, ...
        'algorithm_runtime_s',NaN,'method',method);
end

function radius = weighted_radius(point,problem)
    radius = sqrt(sum((point-problem.target).^2.*problem.weight));
end

function value = finite_or_nan(value)
    if ~isfinite(value), value=NaN; end
end

function summary = summarize_runs(raw)
    methods = unique(string(raw.method),'stable');
    rows = cell(0,1);
    for iMethod = 1:numel(methods)
            g = raw(string(raw.method)==methods(iMethod),:);
            if isempty(g), continue; end
            row = struct();
            row.method = methods(iMethod);
            row.n_runs = height(g);
            row.n_finite = nnz(isfinite(g.R_hat));
            row.median_R_hat = median_finite(g.R_hat);
            row.p05_R_hat = percentile_finite(g.R_hat,5);
            row.p95_R_hat = percentile_finite(g.R_hat,95);
            row.R_reference = g.R_reference(1);
            row.median_relative_error = median_finite(g.relative_error);
            row.p95_relative_error = percentile_finite(g.relative_error,95);
            row.median_signed_relative_error = ...
                median_finite(g.signed_relative_error);
            row.within_1_percent_fraction = mean(double(g.within_1_percent));
            row.within_2_percent_fraction = mean(double(g.within_2_percent));
            row.within_5_percent_fraction = mean(double(g.within_5_percent));
            row.median_queries = median_finite(g.query_count);
            row.median_integrations = median_finite(g.integration_count);
            row.median_algorithm_runtime_s = ...
                median_finite(g.algorithm_runtime_s);
            row.median_wall_with_audit_s = median_finite(g.wall_runtime_s);
            row.unresolved_run_fraction = mean( ...
                string(g.stop_status)=="unresolved_classification");
            row.budget_exhausted_fraction = mean( ...
                string(g.stop_status)=="query_budget_exhausted");
            row.direction_limit_fraction = mean( ...
                string(g.stop_status)=="direction_limit_reached");
            row.direction_budget_violation_fraction = mean( ...
                ~logical(g.direction_budget_respected));
            row.converged_fraction = mean( ...
                string(g.stop_status)=="converged_local_and_global");
            row.audit_pass_fraction = mean(double(g.post_audit_pass));
            row.median_post_audit_relative_drop = ...
                median_finite(g.post_audit_relative_drop);
            rows{end+1,1} = row; %#ok<AGROW>
    end
    summary = struct2table(vertcat(rows{:}));
end

function paired = summarize_paired_contrasts(raw)
    comparisonMethod = ["adaptive_s3_radial"; ...
        "adaptive_s3_with_trajectory_reuse"];
    baselineMethod = "fixed_s3_radial_24";
    rows = cell(0,1);
        baseline = raw(string(raw.method)==baselineMethod,:);
        for iMethod = 1:numel(comparisonMethod)
            candidate = raw(string(raw.method)== ...
                comparisonMethod(iMethod),:);
            [sharedSeeds,ia,ib] = intersect( ...
                candidate.seed,baseline.seed,'stable');
            if isempty(sharedSeeds), continue; end
            row = struct();
            row.method = comparisonMethod(iMethod);
            row.baseline = baselineMethod;
            row.n_paired_seeds = numel(sharedSeeds);
            row.median_delta_R_hat = median_finite( ...
                candidate.R_hat(ia)-baseline.R_hat(ib));
            row.median_delta_relative_error = median_finite( ...
                candidate.relative_error(ia)-baseline.relative_error(ib));
            row.median_R_hat_ratio = median_finite( ...
                candidate.R_hat(ia)./baseline.R_hat(ib));
            row.median_query_ratio = median_finite( ...
                candidate.query_count(ia)./baseline.query_count(ib));
            row.median_integration_ratio = median_finite( ...
                candidate.integration_count(ia)./ ...
                baseline.integration_count(ib));
            row.median_direction_ratio = median_finite( ...
                candidate.direction_count(ia)./baseline.direction_count(ib));
            row.median_runtime_ratio = median_finite( ...
                candidate.algorithm_runtime_s(ia)./ ...
                baseline.algorithm_runtime_s(ib));
            row.candidate_converged_fraction = mean( ...
                string(candidate.stop_status(ia))== ...
                "converged_local_and_global");
            row.candidate_audit_pass_fraction = mean( ...
                double(candidate.post_audit_pass(ia)));
            rows{end+1,1} = row; %#ok<AGROW>
        end
    if isempty(rows)
        paired = table();
    else
        paired = struct2table(vertcat(rows{:}));
    end
end

function T = append_struct_row(T,row)
    newRow = struct2table(row,'AsArray',true);
    if isempty(T)
        T = newRow;
    else
        T = [T;newRow]; %#ok<AGROW>
    end
end

function value = median_finite(x)
    x = x(isfinite(x));
    if isempty(x), value=NaN; else, value=median(x); end
end

function value = percentile_finite(x,p)
    x = sort(x(isfinite(x)));
    if isempty(x), value=NaN; return; end
    if numel(x)==1, value=x; return; end
    q = 1+(numel(x)-1)*p/100;
    lo = floor(q); hi = ceil(q);
    value = x(lo)+(q-lo)*(x(hi)-x(lo));
end

function atomic_write_table(T,pathName)
    [folder,name,~] = fileparts(pathName);
    temporary = fullfile(folder,[name '_writing.csv']);
    writetable(T,temporary,'FileType','text');
    movefile(temporary,pathName,'f');
end

function write_configuration(folder,cfg,runMode,alphaQC,alphaBD, ...
        seedList,reference)
    parameter = ["run_mode";"alpha_qc";"alpha_bd";"seed_list"; ...
        "model_equations";"target";"weight";"domain";"discr"; ...
        "target_cells";"tfinal";"Ts";"RelTol_AbsTol"; ...
        "initial_directions";"max_directions";"scan_step"; ...
        "radial_tolerance"; ...
        "query_budget";"local_delta_initial";"local_delta_minimum"; ...
        "global_validation";"stopping_improvement_threshold"; ...
        "post_stop_audit";"analytical_LIM"];
    value = [string(runMode);string(alphaQC);string(alphaBD); ...
        mat2str(seedList); ...
        "QC x''+a|x'|x'+x-x^2=0; BD y''+a|y'|y'-y+y^3=0"; ...
        "[0 0 -1 0]";"diag(1,1,1,1)"; ...
        "[-4,2]x[-4,4]x[-4,2]x[-4,4]"; ...
        string(cfg.discr);string(cfg.targetCells); ...
        string(cfg.tfinal);string(cfg.Ts); ...
        sprintf('%g / %g',cfg.RelTol,cfg.AbsTol); ...
        string(cfg.initialDirections);string(cfg.maxDirections); ...
        string(cfg.scanStep); ...
        string(cfg.radialTolerance);string(cfg.queryBudget); ...
        sprintf('%.6g rad',cfg.localDeltaInitial); ...
        sprintf('%.6g rad',cfg.localDeltaMinimum); ...
        sprintf('%d batches x %d directions', ...
            cfg.requiredGlobalPasses,cfg.globalValidationBatch); ...
        sprintf('max(%g relative, %g absolute)', ...
            cfg.stopRelativeImprovement,cfg.stopAbsoluteImprovement); ...
        sprintf('%d directions, separate budget %d', ...
            cfg.postAuditDirections,cfg.postAuditBudget); ...
        sprintf('min(%.12g, %.12g) = %.12g',reference.R_QC, ...
            reference.R_BD,reference.R_4D)];
    source = ["experiment control";"benchmark definition"; ...
        "benchmark definition";"experiment control"; ...
        "Genda analytical 1-DOF models, direct product"; ...
        "product equilibrium";"benchmark definition"; ...
        "classifier control";"classifier control"; ...
        "classifier control";"classifier control"; ...
        "classifier control";"classifier control"; ...
        repmat("new 4D method control",10,1); ...
        "product-basin distance theorem"];
    note = strings(size(parameter));
    note(parameter=="analytical_LIM") = ...
        "Reference is scoring-only and is never read by the search.";
    configuration = table(parameter,value,source,note);
    atomic_write_table(configuration,fullfile(folder,'configuration.csv'));
end

function [reference,auditQC,auditBD] = analytical_reference(alphaQC,alphaBD)
    [rQC,xQC,xLeftQC,auditQC] = reference_quadratic_cubic(alphaQC);
    [rBD,xBD,xLeftBD,auditBD] = reference_bistable_duffing(alphaBD);
    reference = struct();
    reference.alpha_qc = alphaQC;
    reference.alpha_bd = alphaBD;
    reference.R_QC = rQC;
    reference.R_BD = rBD;
    reference.R_4D = min(rQC,rBD);
    reference.active_component = "quadratic_cubic";
    if rBD<rQC, reference.active_component = "bistable_duffing"; end
    reference.minimizer_qc_x = xQC;
    reference.minimizer_bd_x = xBD;
    reference.left_turn_qc = xLeftQC;
    reference.left_turn_bd = xLeftBD;
    reference.metric = "Euclidean W=diag(1,1,1,1)";
    reference.proof = ...
        "B=B_QC x B_BD, so dist(z_e,boundary(B))=min(R_QC,R_BD)";
end

function [R,xstar,xLeft,audit] = reference_quadratic_cubic(a)
    assert(a>=0.1 && a<=0.95, ...
        'Quadratic-cubic reference requires 0.1 <= alpha <= 0.95.');
    rows = zeros(2,10);
    for stage = 1:2
        n = 1024*2^stage;
        tol = 10^(-9-3*(stage-1));
        p = @(x) (2*a^2*x.^2-2*a^2*x-2*a*x+2*a ...
            -(1-a)*expm1(2*a*(1-x)))/(2*a^3);
        left = -2;
        while p(left)>0, left=1.25*left; end
        opts = optimset('TolX',tol,'Display','off');
        xLeftStage = fzero(p,[left 0],opts);
        D = (a-1)/(a+1)*exp(2*a-1);
        w = fzero(@(q) q.*exp(q)-D,[-1 0],opts);
        xInterior = (1+w)/(2*a);
        rInterior = xInterior*sqrt(1+1/a);
        rEndpoint = abs(xLeftStage);
        [rStage,index] = min([rEndpoint rInterior]);
        candidates = [xLeftStage xInterior];
        xStage = candidates(index);
        integralValue = exp(-2*a*xStage)*integral( ...
            @(s)(-2*s+2*s.^2).*exp(2*a*s),1,xStage, ...
            'AbsTol',1e-12,'RelTol',1e-12);
        rows(stage,:) = [stage n tol xLeftStage xStage rStage ...
            rEndpoint rInterior abs(integralValue-p(xStage)) ...
            abs(w*exp(w)-D)];
    end
    assert(abs(rows(2,6)-rows(1,6))<1e-8 && ...
        max(rows(:,9:10),[],'all')<1e-8, ...
        'Quadratic-cubic analytical reference failed its audit.');
    R=rows(2,6); xstar=rows(2,5); xLeft=rows(2,4);
    audit=array2table(rows,'VariableNames',{'stage','scan_intervals', ...
        'root_tolerance','left_turning_point','minimizer_x', ...
        'reference_LIM','endpoint_radius','interior_radius', ...
        'integral_residual','Lambert_residual'});
end

function [R,xstar,xLeft,audit] = reference_bistable_duffing(a)
    assert(a>=0.1 && a<=1, ...
        'Bistable Duffing reference requires 0.1 <= alpha <= 1.');
    rows = zeros(2,9);
    for stage = 1:2
        n = 1024*2^stage;
        tol = 10^(-9-3*(stage-1));
        p = @(x) (-4*a^3*x.^3+6*a^2*x.^2+(4*a^3-6*a)*x ...
            -(3-2*a^2)*expm1(-2*a*x))/(4*a^4);
        left = -2;
        while p(left)>0, left=1.25*left; end
        opts = optimset('TolX',tol,'Display','off');
        xLeftStage = fzero(p,[left -1],opts);
        g = @(x) a*p(x)-2*x-1+x.^3;
        xs = linspace(xLeftStage,0,n+1);
        gs = g(xs);
        roots = zeros(0,1);
        for k=1:n
            if gs(k)*gs(k+1)<0
                roots(end+1,1)=fzero(g,[xs(k) xs(k+1)],opts); %#ok<AGROW>
            end
        end
        candidates = unique([xLeftStage;roots;0]);
        values = (candidates+1).^2+max(0,p(candidates));
        [minimum,index] = min(values);
        rStage = sqrt(minimum);
        xStage = candidates(index);
        integralValue = exp(-2*a*xStage)*integral( ...
            @(s)(2*s-2*s.^3).*exp(2*a*s),0,xStage, ...
            'AbsTol',1e-12,'RelTol',1e-12);
        rows(stage,:) = [stage n tol xLeftStage xStage rStage ...
            abs(p(xLeftStage)) abs(integralValue-p(xStage)) numel(roots)];
    end
    assert(abs(rows(2,6)-rows(1,6))<1e-8 && max(rows(:,8))<1e-8, ...
        'Bistable Duffing analytical reference failed its audit.');
    R=rows(2,6); xstar=rows(2,5); xLeft=rows(2,4);
    audit=array2table(rows,'VariableNames',{'stage','scan_intervals', ...
        'root_tolerance','left_turning_point','minimizer_x', ...
        'reference_LIM','turning_residual','integral_residual', ...
        'stationary_root_count'});
end
