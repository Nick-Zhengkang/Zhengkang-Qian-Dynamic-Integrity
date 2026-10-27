function [estimate,audit] = estimate_dynin_parameters_from_physics(benchmarkName,alpha,F,options)
%ESTIMATE_DYNIN_PARAMETERS_FROM_PHYSICS Map model scales to DynIn settings.
%
% This function never reads the analytical/reference LIM. It uses only the
% equation, equilibria, potential barriers, damping and fixed dimensionless
% design constants. The returned values are therefore valid inputs to a
% reference-blind cross-model transfer experiment.

    if nargin < 3, F = NaN; end
    if nargin < 4, options = struct(); end

    options = set_default(options,'beta_target',0.005);
    options = set_default(options,'eta_grid',0.005);
    options = set_default(options,'samples_per_period',125);
    options = set_default(options,'decay_safety_factor',1.5);
    options = set_default(options,'minimum_periods',20);
    options = set_default(options,'periodic_safety_factor',1.25);
    options = set_default(options,'domain_margin_fraction',0.20);
    options = set_default(options,'minimum_discr',351);
    options = set_default(options,'maximum_discr',1201);

    validateattributes(alpha,{'numeric'},{'scalar','positive','finite'});
    benchmarkName = validatestring(char(benchmarkName), ...
        {'quadratic_cubic','bistable_duffing', ...
         'cosine_quadratic_drag','tilted_washboard'});
    physics = physical_scales(benchmarkName,F,options.domain_margin_fraction);

    beta = options.beta_target;
    qTol = sqrt(beta*physics.deltaV/physics.curvature);
    vTol = sqrt(beta*physics.deltaV);
    localPeriod = 2*pi/physics.omega0;

    normalizedXSpan = diff(physics.domain([1 3]))/physics.Lx;
    normalizedVSpan = diff(physics.domain([2 4]))/physics.Lv;
    requestedDiscr = ceil(max(normalizedXSpan,normalizedVSpan)/options.eta_grid);
    discr = make_odd(min(options.maximum_discr, ...
        max(options.minimum_discr,requestedDiscr)));
    dx = diff(physics.domain([1 3]))/discr;
    dv = diff(physics.domain([2 4]))/discr;
    targetHalfCells = max(1,floor(min(qTol/dx,vTol/dv)));
    targetCells = 2*targetHalfCells+1;

    initialAmplitude = min(physics.Lx,physics.Lv/physics.omega0);
    targetAmplitude = min(qTol,vTol/physics.omega0);
    decayCoefficient = 4*alpha*physics.omega0/(3*pi);
    decayTime = max(0,(1/targetAmplitude-1/initialAmplitude)/decayCoefficient);
    minimumTime = options.minimum_periods*localPeriod;
    tfinal = ceil_to_nice(max(minimumTime, ...
        options.decay_safety_factor*decayTime),10);
    Ts = round_sig(localPeriod/options.samples_per_period,3);
    Ts = min(0.20,max(0.005,Ts));
    expectedDecayCycles = decayTime/localPeriod;
    repPeriodic = max(10,ceil(options.periodic_safety_factor*expectedDecayCycles)+5);

    estimate = struct();
    estimate.target = physics.target;
    estimate.weight = [1 1];
    estimate.domain = physics.domain;
    estimate.discr = discr;
    estimate.num_of_cell_around_equilibrium = targetCells;
    estimate.tfinal = tfinal;
    estimate.Ts = Ts;
    estimate.rep_periodic = repPeriodic;
    estimate.rep_fix_point = 40;
    estimate.reltol = 1e-8;
    estimate.abstol = 1e-9;

    audit = struct();
    audit.benchmark_name = string(benchmarkName);
    audit.alpha = alpha;
    audit.F = F;
    audit.target_x = physics.target(1);
    audit.target_v = physics.target(2);
    audit.left_saddle_x = physics.leftSaddle;
    audit.right_saddle_x = physics.rightSaddle;
    audit.nearest_saddle_distance_Lx = physics.Lx;
    audit.potential_barrier_deltaV = physics.deltaV;
    audit.velocity_scale_Lv = physics.Lv;
    audit.local_curvature = physics.curvature;
    audit.local_omega0 = physics.omega0;
    audit.local_period = localPeriod;
    audit.beta_target = beta;
    audit.domain_margin_fraction = options.domain_margin_fraction;
    audit.target_position_tolerance = qTol;
    audit.target_velocity_tolerance = vTol;
    audit.domain_x_min = physics.domain(1);
    audit.domain_v_min = physics.domain(2);
    audit.domain_x_max = physics.domain(3);
    audit.domain_v_max = physics.domain(4);
    audit.eta_grid = options.eta_grid;
    audit.samples_per_period = options.samples_per_period;
    audit.decay_safety_factor = options.decay_safety_factor;
    audit.minimum_periods = options.minimum_periods;
    audit.periodic_safety_factor = options.periodic_safety_factor;
    audit.requested_discr_before_cap = requestedDiscr;
    audit.grid_cap_active = requestedDiscr > options.maximum_discr;
    audit.achieved_normalized_grid_width = max( ...
        normalizedXSpan/discr,normalizedVSpan/discr);
    audit.grid_dx = dx;
    audit.grid_dv = dv;
    audit.estimated_discr = discr;
    audit.estimated_target_cells = targetCells;
    audit.initial_decay_amplitude = initialAmplitude;
    audit.target_decay_amplitude = targetAmplitude;
    audit.decay_coefficient = decayCoefficient;
    audit.estimated_decay_time = decayTime;
    audit.expected_decay_cycles = expectedDecayCycles;
    audit.estimated_tfinal = tfinal;
    audit.estimated_Ts = Ts;
    audit.estimated_rep_periodic = repPeriodic;
    audit.reference_LIM_used = false;
end

function physics = physical_scales(name,F,marginFraction)
    physics = struct();
    switch name
        case 'quadratic_cubic'
            physics.target = [0 0];
            physics.leftSaddle = NaN;
            physics.rightSaddle = 1;
            physics.deltaV = 1/6;
            physics.curvature = 1;
            physics.Lx = 1;
            physics.Lv = sqrt(2*physics.deltaV);
            xCore = [-0.5 1];
            vCore = [-physics.Lv physics.Lv];
        case 'bistable_duffing'
            physics.target = [-1 0];
            physics.leftSaddle = NaN;
            physics.rightSaddle = 0;
            physics.deltaV = 1/4;
            physics.curvature = 2;
            physics.Lx = 1;
            physics.Lv = sqrt(2*physics.deltaV);
            xCore = [-sqrt(2) 1];
            vCore = [-physics.Lv physics.Lv];
        case 'cosine_quadratic_drag'
            physics.target = [0 0];
            physics.leftSaddle = -pi;
            physics.rightSaddle = pi;
            physics.deltaV = 2;
            physics.curvature = 1;
            physics.Lx = pi;
            physics.Lv = sqrt(2*physics.deltaV);
            xCore = [-pi pi];
            vCore = [-physics.Lv physics.Lv];
        case 'tilted_washboard'
            validateattributes(F,{'numeric'},{'scalar','>',0,'<',1,'finite'});
            delta = asin(F);
            leftSaddle = -pi-delta;
            rightSaddle = pi-delta;
            potential = @(x) -cos(x)-F*x;
            targetPotential = potential(delta);
            leftBarrier = potential(leftSaddle)-targetPotential;
            rightBarrier = potential(rightSaddle)-targetPotential;
            physics.target = [delta 0];
            physics.leftSaddle = leftSaddle;
            physics.rightSaddle = rightSaddle;
            physics.deltaV = min(leftBarrier,rightBarrier);
            physics.curvature = cos(delta);
            physics.Lx = min(delta-leftSaddle,rightSaddle-delta);
            physics.Lv = sqrt(2*physics.deltaV);
            xCore = [leftSaddle rightSaddle];
            vMax = sqrt(2*max(leftBarrier,rightBarrier));
            vCore = [-vMax vMax];
        otherwise
            error('Unknown benchmark: %s',name);
    end
    physics.omega0 = sqrt(physics.curvature);
    xMargin = marginFraction*diff(xCore);
    vMargin = marginFraction*diff(vCore);
    physics.domain = [xCore(1)-xMargin, vCore(1)-vMargin, ...
                      xCore(2)+xMargin, vCore(2)+vMargin];
end

function s = set_default(s,name,value)
    if ~isfield(s,name) || isempty(s.(name)), s.(name) = value; end
end

function n = make_odd(n)
    n = max(1,round(n));
    if mod(n,2) == 0, n = n+1; end
end

function value = ceil_to_nice(value,step)
    value = step*ceil(value/step);
end

function value = round_sig(value,digits)
    if value == 0, return; end
    power = digits-1-floor(log10(abs(value)));
    value = round(value*10^power)/10^power;
end
