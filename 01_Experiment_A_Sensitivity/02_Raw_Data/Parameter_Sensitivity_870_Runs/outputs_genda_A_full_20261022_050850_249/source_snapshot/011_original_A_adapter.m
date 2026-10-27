function varargout = original_A_adapter(action,varargin)
% Generated from the original Experiment A helpers; do not edit the tail.
switch char(action)
    case 'base'
        varargout{1}=baseline_configuration();
    case 'config'
        varargout{1}=config_from_base(varargin{1});
    case 'execute'
        [varargout{1:3}]=execute_one_run(varargin{:});
    case 'diagnostic'
        base=varargin{1}; n=varargin{2}; fresh=varargin{3};
        if ~fresh
            D=build_diagnostic_set(base,n,[0.85 1.00 1.15]);
        else
            D=build_diagnostic_set(base,n,[0.875 1.025 1.175]);
            for i=1:height(D)
                D.theta_rad(i)=D.theta_rad(i)+pi/n;
                p=base.xe+D.weighted_radius(i)* ...
                    [cos(D.theta_rad(i)) sin(D.theta_rad(i))]./sqrt(base.weight);
                D.x0(i)=p(1); D.v0(i)=p(2);
                [label,event,elapsed]=independent_truth_label(p,base);
                D.true_label(i)=label;
                D.truth_event(i)=string(event);
                D.truth_time(i)=elapsed;
            end
        end
        varargout{1}=D;
    case 'evaluate'
        varargout{1}=evaluate_learned_classifier(varargin{:});
    case 'empty_diagnostic'
        varargout{1}=empty_diagnostic_metrics();
    otherwise
        error('Unknown adapter action: %s',action);
end
end

% Original source SHA256: ae5325355224b576d04e6db4caf4d96eaa9df3e949b7a83b6fcefca2ee4b6a67
function base = baseline_configuration()
    base = struct();
    base.model = "Habib unforced Duffing";
    base.xe = [-1 0];
    base.par = struct('zeta', 0.05, 'a', 1.0, 'b', 1.0);
    base.reference_LIM = 0.7683;
    base.weight = [4 1];
    base.spaceboundary = [-3 -2 3 4];

    base.tfinal = 2000;
    base.Ts = 0.05;
    base.reltol = 1e-8;
    base.abstol = 1e-8;
    base.number_of_steps = 100;
    base.num_of_cell_around_equilibrium = 3;
    base.discr = 701;
    base.rep_fix_point = 40;
    base.rep_periodic = 10;
    base.divR = 40;
    base.num_gen = 5;
    base.num_crossover = 9;
    base.selected_opt = 3;
    base.newcomers = 8;
    base.num_almost_clones = 2;

    base.type_x0 = 1;
    base.automatic = 1;
    base.min_periodic_radius = 0.005;
    base.check_min_periodic = 0;
    base.check_equilibrium = 1;
    base.max_check_step = 10000;
    base.bis_iter_max = 5;
end

function design = build_experiment_design(base)
    configs = repmat(config_from_base(base), 0, 1);
    configs(end+1) = tagged_config(base, "baseline", "baseline", "baseline");

    configs = add_scalar_pair(configs, base, "discr", "discr", 351, 1051);
    configs = add_scalar_pair(configs, base, ...
        "num_of_cell_around_equilibrium", "target_neighborhood_cells", 1, 7);
    configs = add_scalar_pair(configs, base, "tfinal", "tfinal", 1000, 4000);
    configs = add_scalar_pair(configs, base, "Ts", "Ts", 0.025, 0.10);

    low = base; low.reltol = 1e-6; low.abstol = 1e-8;
    high = base; high.reltol = 1e-10; high.abstol = 1e-10;
    configs(end+1) = tagged_config(low, "ode_tolerance", "low", "1e-6 / 1e-8");
    configs(end+1) = tagged_config(high, "ode_tolerance", "high", "1e-10 / 1e-10");

    configs = add_scalar_pair(configs, base, ...
        "number_of_steps", "number_of_steps", 50, 200);
    configs = add_scalar_pair(configs, base, ...
        "rep_fix_point", "rep_fix_point", 20, 80);
    configs = add_scalar_pair(configs, base, ...
        "rep_periodic", "rep_periodic", 5, 20);
    configs = add_scalar_pair(configs, base, "divR", "divR", 20, 80);
    configs = add_scalar_pair(configs, base, "num_gen", "num_gen", 2, 10);

    low = base;
    low.num_crossover = 4; low.newcomers = 4; low.num_almost_clones = 1;
    high = base;
    high.num_crossover = 18; high.newcomers = 17; high.num_almost_clones = 4;
    configs(end+1) = tagged_config(low, "population_size", "low", "10 (4/4/1)");
    configs(end+1) = tagged_config(high, "population_size", "high", "40 (18/17/4)");

    low = base;
    low.newcomers = 4; low.num_almost_clones = 2; low.num_crossover = 13;
    high = base;
    high.newcomers = 12; high.num_almost_clones = 2; high.num_crossover = 5;
    configs(end+1) = tagged_config(low, "newcomer_fraction", "low", "0.2 (4/20)");
    configs(end+1) = tagged_config(high, "newcomer_fraction", "high", "0.6 (12/20)");

    low = base;
    low.num_almost_clones = 0; low.newcomers = 8; low.num_crossover = 11;
    high = base;
    high.num_almost_clones = 4; high.newcomers = 8; high.num_crossover = 7;
    configs(end+1) = tagged_config(low, "num_almost_clones", "low", "0");
    configs(end+1) = tagged_config(high, "num_almost_clones", "high", "4");

    configs = add_scalar_pair(configs, base, ...
        "selected_opt", "selected_opt", 2, 5);

    design = struct2table(configs);
    design.config_order = (1:height(design)).';
    design = movevars(design, 'config_order', 'Before', 1);
    assert(height(design) == 29, 'Full Experiment A must contain 29 unique configurations.');
    assert(all(design.population_size == ...
        1 + design.num_crossover + design.newcomers + design.num_almost_clones), ...
        'Invalid GA population composition in the design table.');
end

function configs = add_scalar_pair(configs, base, fieldName, factorName, lowValue, highValue)
    low = base;
    low.(char(fieldName)) = lowValue;
    high = base;
    high.(char(fieldName)) = highValue;
    configs(end+1) = tagged_config(low, factorName, "low", string(lowValue));
    configs(end+1) = tagged_config(high, factorName, "high", string(highValue));
end

function cfg = tagged_config(values, factorName, level, valueLabel)
    cfg = config_from_base(values);
    cfg.changed_parameter = string(factorName);
    cfg.level = string(level);
    cfg.value_label = string(valueLabel);
    if factorName == "baseline"
        cfg.config_id = "baseline";
    else
        cfg.config_id = factorName + "__" + level;
    end
end

function cfg = config_from_base(values)
    cfg = struct();
    cfg.config_id = "";
    cfg.changed_parameter = "";
    cfg.level = "";
    cfg.value_label = "";
    cfg.discr = values.discr;
    cfg.num_of_cell_around_equilibrium = values.num_of_cell_around_equilibrium;
    cfg.tfinal = values.tfinal;
    cfg.Ts = values.Ts;
    cfg.reltol = values.reltol;
    cfg.abstol = values.abstol;
    cfg.number_of_steps = values.number_of_steps;
    cfg.rep_fix_point = values.rep_fix_point;
    cfg.rep_periodic = values.rep_periodic;
    cfg.divR = values.divR;
    cfg.num_gen = values.num_gen;
    cfg.num_crossover = values.num_crossover;
    cfg.selected_opt = values.selected_opt;
    cfg.newcomers = values.newcomers;
    cfg.num_almost_clones = values.num_almost_clones;
    cfg.population_size = 1 + values.num_crossover + values.newcomers + ...
        values.num_almost_clones;
    cfg.newcomer_fraction = values.newcomers / cfg.population_size;
end

function [result, OutL, OutH] = execute_one_run(cfg, base)
    result = empty_result();
    OutL = struct();
    OutH = struct();

    args = struct();
    args.tfinal = cfg.tfinal;
    args.Ts = cfg.Ts;
    args.weight = base.weight;
    args.type_x0 = base.type_x0;
    args.reltol = cfg.reltol;
    args.abstol = cfg.abstol;
    args.number_of_steps = cfg.number_of_steps;
    args.num_of_cell_around_equilibrium = cfg.num_of_cell_around_equilibrium;
    args.num_fig = 1001;
    args.plot_results = 0;
    args.plot_results_final = 0;
    args.spaceboundary = base.spaceboundary;
    args.discr = cfg.discr;
    args.automatic = base.automatic;
    args.var1 = 1;
    args.var2 = 2;
    args.rep_fix_point = cfg.rep_fix_point;
    args.rep_periodic = cfg.rep_periodic;
    args.min_periodic_radius = base.min_periodic_radius;
    args.check_min_periodic = base.check_min_periodic;
    args.check_equilibrium = base.check_equilibrium;
    args.max_check_step = base.max_check_step;
    args.divR = cfg.divR;
    args.num_gen = cfg.num_gen;
    args.num_crossover = cfg.num_crossover;
    args.selected_opt = cfg.selected_opt;
    args.newcomers = cfg.newcomers;
    args.num_almost_clones = cfg.num_almost_clones;
    args.bis_iter_max = base.bis_iter_max;

    wallTimer = tic;
    try
        vals = struct_to_original_optional_order(args, base.xe);
        [Rhat, OutL, OutH] = compute_LIM_FP(base.xe, base.par, vals{:});
        result.wall_runtime_s = toc(wallTimer);
        result.R_hat = Rhat;
        result.relative_error = abs(Rhat - base.reference_LIM) / base.reference_LIM;
        result.signed_relative_error = (Rhat - base.reference_LIM) / base.reference_LIM;
        result.within_1pct = isfinite(result.relative_error) && result.relative_error <= 0.01;
        result.unsafe_overestimate = isfinite(result.signed_relative_error) && ...
            result.signed_relative_error > 0;
        result.algorithm_runtime_s = safe_scalar_field(OutL, 'total_time');
        result.trajectory_evaluations = count_trajectory_evaluations(OutL);
        result.processed_time_samples = sum_finite_field(OutL, 'time_steps_sim');
        result.internal_unresolved_count = count_internal_unresolved(OutL);
        result.success = isfinite(Rhat);
        if ~result.success
            result.error_message = "compute_LIM_FP returned a non-finite LIM";
        end
    catch ME
        result.wall_runtime_s = toc(wallTimer);
        result.error_message = string(getReport(ME, 'basic', 'hyperlinks', 'off'));
    end
end

function result = empty_result()
    result = struct('success', false, 'R_hat', NaN, 'relative_error', NaN, ...
        'signed_relative_error', NaN, 'within_1pct', false, ...
        'unsafe_overestimate', false, 'wall_runtime_s', NaN, ...
        'algorithm_runtime_s', NaN, 'diagnostic_runtime_s', NaN, ...
        'trajectory_evaluations', NaN, 'processed_time_samples', NaN, ...
        'internal_unresolved_count', NaN, 'error_message', "");
end

function vals = struct_to_original_optional_order(args, xe0)
    dim = numel(xe0);
    defaults = struct('tfinal',1000,'Ts',0.05,'weight',ones(1,dim), ...
        'type_x0',1,'reltol',1e-6,'abstol',1e-6,'number_of_steps',50, ...
        'num_of_cell_around_equilibrium',3,'num_fig',1001, ...
        'plot_results',0,'plot_results_final',0, ...
        'spaceboundary',[xe0-10,xe0+10],'discr',1001,'automatic',0, ...
        'var1',1,'var2',2,'rep_fix_point',40,'rep_periodic',10, ...
        'min_periodic_radius',0.005,'check_min_periodic',0, ...
        'check_equilibrium',1,'max_check_step',10000,'divR',40, ...
        'num_gen',5,'num_crossover',9,'selected_opt',3,'newcomers',8, ...
        'num_almost_clones',2,'bis_iter_max',5);

    names = fieldnames(args);
    for i = 1:numel(names)
        if isfield(defaults, names{i})
            defaults.(names{i}) = args.(names{i});
        end
    end
    order = {'tfinal','Ts','weight','type_x0','reltol','abstol', ...
        'number_of_steps','num_of_cell_around_equilibrium','num_fig', ...
        'plot_results','plot_results_final','spaceboundary','discr', ...
        'automatic','var1','var2','rep_fix_point','rep_periodic', ...
        'min_periodic_radius','check_min_periodic','check_equilibrium', ...
        'max_check_step','divR','num_gen','num_crossover','selected_opt', ...
        'newcomers','num_almost_clones','bis_iter_max'};
    vals = cell(size(order));
    for i = 1:numel(order)
        vals{i} = defaults.(order{i});
    end
end

function diagnostic = build_diagnostic_set(base, nAngles, radiusFactors)
    theta = (0:nAngles-1).' * (2*pi/nAngles);
    rows = [];
    eventNames = strings(0,1);
    pointId = 0;
    for iFactor = 1:numel(radiusFactors)
        radius = base.reference_LIM * radiusFactors(iFactor);
        for iTheta = 1:numel(theta)
            y = radius * [cos(theta(iTheta)), sin(theta(iTheta))];
            x0 = base.xe + y ./ sqrt(base.weight);
            if ~point_in_domain(x0, base.spaceboundary)
                continue
            end
            pointId = pointId + 1;
            [truth, eventName, truthTime] = independent_truth_label(x0, base);
            rows = [rows; pointId, theta(iTheta), radiusFactors(iFactor), ...
                radius, x0(1), x0(2), truth, truthTime]; %#ok<AGROW>
            eventNames(pointId,1) = string(eventName); %#ok<AGROW>
        end
    end
    diagnostic = array2table(rows, 'VariableNames', ...
        {'point_id','theta_rad','radius_factor','weighted_radius', ...
        'x0','v0','true_label','truth_time'});
    diagnostic.truth_event = eventNames;
    diagnostic = movevars(diagnostic, 'truth_event', 'After', 'true_label');
end

function [label, eventName, elapsed] = independent_truth_label(x0, base)
    target = base.xe;
    other = [1 0];
    targetTol = 2e-3;
    maxTime = 4000;
    options = odeset('RelTol',1e-11,'AbsTol',1e-12, ...
        'Events', @(t,x) truth_events(t,x,target,other,targetTol,base.spaceboundary));
    timer = tic;
    [~, trajectory, ~, ~, eventIndex] = ode45( ...
        @(t,x) duffing_rhs(t,x,base.par), [0 maxTime], x0(:), options);
    elapsed = toc(timer);
    label = 0;
    eventName = "unresolved";
    if ~isempty(eventIndex)
        lastEvent = eventIndex(end);
        if lastEvent == 1
            label = 1;
            eventName = "target";
        else
            label = 2;
            if lastEvent == 2
                eventName = "other_attractor";
            else
                eventName = "left_domain";
            end
        end
        return
    end
    finalState = trajectory(end,:);
    if norm(finalState-target) <= 0.02
        label = 1;
        eventName = "target_at_final_time";
    elseif norm(finalState-other) <= 0.02
        label = 2;
        eventName = "other_at_final_time";
    end
end

function [value, isterminal, direction] = truth_events(~, x, target, other, tol, boundary)
    state = x(:).';
    value = [norm(state-target)-tol; norm(state-other)-tol; ...
        state(1)-boundary(1); state(2)-boundary(2); ...
        boundary(3)-state(1); boundary(4)-state(2)];
    isterminal = ones(6,1);
    direction = -ones(6,1);
end

function dx = duffing_rhs(~, x, par)
    dx = [x(2); -2*par.zeta*x(2) + par.b*x(1) - par.a*x(1)^3];
end

function metrics = evaluate_learned_classifier(diagnostic, OutH, cfg, base)
    metrics = empty_diagnostic_metrics();
    truth = diagnostic.true_label;
    resolvedTruth = truth ~= 0;
    metrics.diagnostic_truth_unresolved_rate = mean(truth == 0);
    if ~any(resolvedTruth)
        return
    end

    [safeCells, unsafeCells] = learned_cell_sets(OutH, cfg, base);
    predicted = zeros(height(diagnostic),1);
    for i = 1:height(diagnostic)
        if truth(i) == 0
            continue
        end
        predicted(i) = classify_with_learned_grid( ...
            [diagnostic.x0(i), diagnostic.v0(i)], safeCells, unsafeCells, cfg, base);
    end

    trueUnsafe = truth == 2;
    trueSafe = truth == 1;
    metrics.false_safe_rate = safe_ratio(predicted == 1, trueUnsafe);
    metrics.false_unsafe_rate = safe_ratio(predicted == 2, trueSafe);
    metrics.diagnostic_unresolved_rate = safe_ratio(predicted == 0, resolvedTruth);
    metrics.diagnostic_coverage = safe_ratio(predicted ~= 0, resolvedTruth);
    metrics.diagnostic_accuracy_resolved = safe_ratio( ...
        predicted == truth, resolvedTruth & predicted ~= 0);
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

function [safeCells, unsafeCells] = learned_cell_sets(OutH, cfg, base)
    safeCells = points_to_cell_ids(OutH.vc, cfg.discr, base.spaceboundary);
    unsafeCells = [points_to_cell_ids(OutH.vd, cfg.discr, base.spaceboundary); ...
        points_to_cell_ids(OutH.vdout, cfg.discr, base.spaceboundary)];

    equilibriumCell = point_to_cell_coordinate(base.xe, cfg.discr, base.spaceboundary);
    targetBelt = local_target_belt(equilibriumCell, cfg.discr, ...
        cfg.num_of_cell_around_equilibrium);
    safeCells = unique([safeCells; targetBelt]);
    unsafeCells = unique(unsafeCells);
    conflict = intersect(safeCells, unsafeCells);
    safeCells = setdiff(safeCells, conflict);
    unsafeCells = setdiff(unsafeCells, conflict);
end

function label = classify_with_learned_grid(x0, safeCells, unsafeCells, cfg, base)
    state = x0;
    label = lookup_cell_label(state, safeCells, unsafeCells, cfg.discr, base.spaceboundary);
    if label ~= 0
        return
    end
    tolerance = [cfg.reltol cfg.abstol];
    maxSegments = ceil(cfg.tfinal / cfg.Ts);
    for i = 1:maxSegments
        if ~point_in_domain(state, base.spaceboundary)
            label = 2;
            return
        end
        segment = sys_solver(cfg.Ts, state, base.par, tolerance);
        state = segment(end,:);
        if ~point_in_domain(state, base.spaceboundary)
            label = 2;
            return
        end
        label = lookup_cell_label(state, safeCells, unsafeCells, ...
            cfg.discr, base.spaceboundary);
        if label ~= 0
            return
        end
    end
end

function label = lookup_cell_label(point, safeCells, unsafeCells, discr, boundary)
    id = point_to_cell_id(point, discr, boundary);
    if isnan(id)
        label = 2;
    elseif ismember(id, safeCells)
        label = 1;
    elseif ismember(id, unsafeCells)
        label = 2;
    else
        label = 0;
    end
end

function ids = points_to_cell_ids(points, discr, boundary)
    if isempty(points) || all(isnan(points(:)))
        ids = zeros(0,1);
        return
    end
    points = points(all(isfinite(points),2),:);
    ids = zeros(size(points,1),1);
    keep = false(size(points,1),1);
    for i = 1:size(points,1)
        id = point_to_cell_id(points(i,:), discr, boundary);
        if isfinite(id)
            ids(i) = id;
            keep(i) = true;
        end
    end
    ids = unique(ids(keep));
end

function id = point_to_cell_id(point, discr, boundary)
    if ~point_in_domain(point, boundary)
        id = NaN;
        return
    end
    coord = point_to_cell_coordinate(point, discr, boundary);
    id = 1 + (coord(1)-1)*discr + (coord(2)-1);
end

function coord = point_to_cell_coordinate(point, discr, boundary)
    lower = boundary(1:2);
    upper = boundary(3:4);
    dh = (upper-lower) / discr;
    coord = floor((point-lower) ./ dh) + 1;
    coord = max(1, min(discr, coord));
end

function ids = local_target_belt(center, discr, requestedCells)
    n = max(1, floor(abs(requestedCells)));
    halfWidth = floor(n/2);
    offsets = -halfWidth:halfWidth;
    ids = zeros(numel(offsets)^2,1);
    k = 0;
    for i = offsets
        for j = offsets
            cellCoord = center + [i j];
            if all(cellCoord >= 1) && all(cellCoord <= discr)
                k = k + 1;
                ids(k) = 1 + (cellCoord(1)-1)*discr + (cellCoord(2)-1);
            end
        end
    end
    ids = unique(ids(1:k));
end

function tf = point_in_domain(point, boundary)
    tf = all(point >= boundary(1:2)) && all(point <= boundary(3:4));
end

function row = assemble_raw_row(cfg, seed, key, result, metrics)
    row = cfg;
    row.run_key = string(key);
    row.seed = seed;
    row.reference_LIM = 0.7683;
    resultNames = fieldnames(result);
    for i = 1:numel(resultNames)
        row.(resultNames{i}) = result.(resultNames{i});
    end
    metricNames = fieldnames(metrics);
    for i = 1:numel(metricNames)
        row.(metricNames{i}) = metrics.(metricNames{i});
    end
end

function long = build_factorwise_long_table(raw, design)
    baseline = raw(raw.changed_parameter == "baseline",:);
    factorNames = unique(design.changed_parameter(design.changed_parameter ~= "baseline"), 'stable');
    long = table();
    for i = 1:numel(factorNames)
        factor = factorNames(i);
        copies = baseline;
        copies.changed_parameter(:) = factor;
        copies.level(:) = "baseline";
        copies.value_label(:) = baseline_value_label(factor, baseline(1,:));
        copies.baseline_reused = true(height(copies),1);

        changed = raw(raw.changed_parameter == factor,:);
        changed.baseline_reused = false(height(changed),1);
        long = [long; copies; changed]; %#ok<AGROW>
    end
end

function label = baseline_value_label(factor, baselineRow)
    switch factor
        case "target_neighborhood_cells"
            value = baselineRow.num_of_cell_around_equilibrium;
        case "ode_tolerance"
            label = string(sprintf('%.0e / %.0e', baselineRow.reltol, baselineRow.abstol));
            return
        case "population_size"
            value = baselineRow.population_size;
        case "newcomer_fraction"
            value = baselineRow.newcomer_fraction;
        otherwise
            value = baselineRow.(char(factor));
    end
    label = string(value);
end

function summary = summarize_factorwise_results(long)
    factors = unique(long.changed_parameter, 'stable');
    % Store complete row structures in cells first. Assigning the first
    % populated row into an empty fieldless struct causes MATLAB's
    % "Subscripted assignment between dissimilar structures" error.
    rows = cell(0,1);
    levels = ["low","baseline","high"];
    for iFactor = 1:numel(factors)
        factor = factors(iFactor);
        for iLevel = 1:numel(levels)
            level = levels(iLevel);
            group = long(long.changed_parameter == factor & long.level == level,:);
            if isempty(group)
                continue
            end
            row = struct();
            row.changed_parameter = factor;
            row.level = level;
            row.value_label = group.value_label(1);
            row.n_runs = height(group);
            row.n_success = nnz(group.success);
            row.median_relative_error = median_finite(group.relative_error);
            row.p95_relative_error = percentile_finite(group.relative_error, 95);
            row.unsafe_overestimate_rate = mean_finite(double(group.unsafe_overestimate));
            row.within_1pct_rate = mean_finite(double(group.within_1pct));
            row.median_wall_runtime_s = median_finite(group.wall_runtime_s);
            row.median_algorithm_runtime_s = median_finite(group.algorithm_runtime_s);
            row.median_trajectory_evaluations = median_finite(group.trajectory_evaluations);
            row.median_processed_time_samples = median_finite(group.processed_time_samples);
            row.median_false_safe_rate = median_finite(group.false_safe_rate);
            row.median_false_unsafe_rate = median_finite(group.false_unsafe_rate);
            row.median_diagnostic_unresolved_rate = ...
                median_finite(group.diagnostic_unresolved_rate);
            rows{end+1,1} = row; %#ok<AGROW>
        end
    end
    if isempty(rows)
        summary = table();
    else
        summary = struct2table(vertcat(rows{:}));
    end
end

function make_overview_figure(summary, outputPath)
    if isempty(summary)
        return
    end
    factors = unique(summary.changed_parameter, 'stable');
    levels = ["low","baseline","high"];
    colors = [0.20 0.45 0.65; 0.15 0.15 0.15; 0.75 0.30 0.20];
    metrics = {'median_relative_error','median_false_safe_rate', ...
        'median_wall_runtime_s','within_1pct_rate'};
    titles = {'Median relative LIM error','Median false-safe rate', ...
        'Median wall runtime (s)','Runs within 1% error'};

    fig = figure('Color','w','Visible','off','Position',[80 80 1500 850]);
    tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    for iMetric = 1:numel(metrics)
        nexttile; hold on;
        for iLevel = 1:numel(levels)
            values = NaN(numel(factors),1);
            for iFactor = 1:numel(factors)
                mask = summary.changed_parameter == factors(iFactor) & ...
                    summary.level == levels(iLevel);
                if any(mask)
                    values(iFactor) = summary.(metrics{iMetric})(find(mask,1));
                end
            end
            plot(1:numel(factors), values, '-o', 'LineWidth',1.4, ...
                'MarkerSize',5, 'Color',colors(iLevel,:));
        end
        grid on; box on;
        xlim([0.5 numel(factors)+0.5]);
        xticks(1:numel(factors));
        xticklabels(strrep(cellstr(factors), '_', ' '));
        xtickangle(40);
        title(titles{iMetric});
        if iMetric == 3
            set(gca,'YScale','log');
        end
        if iMetric == 4
            ylim([0 1]);
        end
    end
    legend(cellstr(levels), 'Location','southoutside','Orientation','horizontal');
    exportgraphics(fig, outputPath, 'Resolution',180);
    close(fig);
end

function keys = completed_run_keys(raw)
    if isempty(raw) || ~ismember('run_key', raw.Properties.VariableNames)
        keys = strings(0,1);
    else
        keys = string(raw.run_key);
    end
end

function key = make_run_key(configId, seed)
    key = string(configId) + "__seed_" + string(seed);
end

function cfg = table_row_to_struct(row)
    cfg = table2struct(row);
end

function atomic_write_table(data, pathName)
    tempName = [pathName '.tmp.csv'];
    writetable(data, tempName);
    movefile(tempName, pathName, 'f');
end

function write_manifest(pathName, runMode, seeds, functionsDir, modelDir, base, nConfigs)
    fid = fopen(pathName, 'w');
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, 'DynIn Experiment A - GA hyperparameter sensitivity\n');
    fprintf(fid, 'Created: %s\n', char(datetime('now')));
    fprintf(fid, 'Mode: %s\n', runMode);
    fprintf(fid, 'Seeds: %s\n', mat2str(seeds));
    fprintf(fid, 'Configurations: %d\n', nConfigs);
    fprintf(fid, 'DynIn functions: %s\n', functionsDir);
    fprintf(fid, 'Model folder: %s\n', modelDir);
    fprintf(fid, 'type_x0: %d (GA)\n', base.type_x0);
    fprintf(fid, 'Reference LIM: %.10g (evaluation only)\n', base.reference_LIM);
    fprintf(fid, 'Target: %s\n', mat2str(base.xe));
    fprintf(fid, 'Weight: %s\n', mat2str(base.weight));
    fprintf(fid, 'Domain: %s\n', mat2str(base.spaceboundary));
    fprintf(fid, ['Timing rule: wall_runtime_s encloses compute_LIM_FP only; ' ...
        'diagnostic_runtime_s is recorded separately.\n']);
end

function value = safe_scalar_field(data, fieldName)
    value = NaN;
    if isstruct(data) && isfield(data, fieldName)
        candidate = data.(fieldName);
        if isscalar(candidate) && isfinite(candidate)
            value = candidate;
        end
    end
end

function value = sum_finite_field(data, fieldName)
    value = NaN;
    if isstruct(data) && isfield(data, fieldName)
        candidate = data.(fieldName);
        candidate = candidate(isfinite(candidate));
        if ~isempty(candidate)
            value = sum(candidate);
        end
    end
end

function n = count_trajectory_evaluations(OutL)
    n = NaN;
    if isstruct(OutL) && isfield(OutL, 'tipo')
        tipo = OutL.tipo;
        n = nnz(isfinite(tipo) & tipo ~= 0);
    end
end

function n = count_internal_unresolved(OutL)
    n = NaN;
    if isstruct(OutL) && isfield(OutL, 'tipo')
        tipo = OutL.tipo;
        n = nnz(isfinite(tipo) & tipo == 0);
    end
end

function value = safe_ratio(numeratorMask, denominatorMask)
    denominator = nnz(denominatorMask);
    if denominator == 0
        value = NaN;
    else
        value = nnz(numeratorMask & denominatorMask) / denominator;
    end
end

function value = median_finite(x)
    x = x(isfinite(x));
    if isempty(x)
        value = NaN;
    else
        value = median(x);
    end
end

function value = mean_finite(x)
    x = x(isfinite(x));
    if isempty(x)
        value = NaN;
    else
        value = mean(x);
    end
end

function value = percentile_finite(x, percentile)
    x = sort(x(isfinite(x)));
    if isempty(x)
        value = NaN;
        return
    end
    index = max(1, min(numel(x), ceil(percentile/100 * numel(x))));
    value = x(index);
end

function assert_same_file(actual, expected, functionName)
    if isempty(actual) || ~strcmpi(strrep(actual,'/','\'), strrep(expected,'/','\'))
        error('%s resolves to the wrong file.\nExpected: %s\nActual: %s', ...
            functionName, expected, actual);
    end
end
