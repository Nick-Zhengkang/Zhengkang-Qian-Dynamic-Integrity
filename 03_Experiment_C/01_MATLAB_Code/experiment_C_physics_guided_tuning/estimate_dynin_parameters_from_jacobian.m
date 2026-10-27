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
function [estimate,audit] = estimate_dynin_parameters_from_jacobian( ...
        A,rhs,target,weight,domain,options)
%ESTIMATE_DYNIN_PARAMETERS_FROM_JACOBIAN Reference-blind DynIn settings.
%
% The rule uses only the local Jacobian, a deterministic nonlinear
% contraction check, the DynIn distance metric and the computational box.
% No LIM reference or previously measured boundary is used.

    if nargin < 6, options = struct(); end
    options = set_default(options,'samples_per_fast_period',125);
    options = set_default(options,'minimum_slow_periods',20);
    options = set_default(options,'time_safety_factor',1.5);
    options = set_default(options,'periodic_safety_factor',1.25);
    options = set_default(options,'eta_grid_per_axis',0.01);
    options = set_default(options,'minimum_discr',351);
    options = set_default(options,'maximum_discr',1201);
    options = set_default(options,'target_fraction_of_verified_region',0.10);
    options = set_default(options,'contraction_margin',0.25);
    options = set_default(options,'direction_count',64);
    options = set_default(options,'radial_levels',40);
    options = set_default(options,'maximum_target_cells',20000);
    options = set_default(options,'minimum_target_cells',3);
    options = set_default(options,'maximum_tfinal',10000);

    d = size(A,1);
    assert(size(A,2) == d,'A must be square.');
    target = target(:);
    weight = weight(:);
    lower = domain(1:d).';
    upper = domain(d+1:end).';
    assert(numel(target)==d && numel(weight)==d, ...
        'Target and weight must match the Jacobian dimension.');
    assert(numel(domain)==2*d && all(upper>lower), ...
        'Domain must contain lower and upper bounds for every state.');

    lambda = eig(A);
    spectralAbscissa = max(real(lambda));
    assert(spectralAbscissa < 0, ...
        'The Jacobian is not asymptotically stable; local tuning is undefined.');
    slowDecayRate = -spectralAbscissa;
    frequencies = abs(imag(lambda));
    positiveFrequencies = frequencies(frequencies>1e-10);
    if isempty(positiveFrequencies)
        omegaFast = 0;
        omegaSlow = 0;
        fastPeriod = Inf;
        slowPeriod = Inf;
        Ts = min(0.05,1/(125*slowDecayRate));
    else
        omegaFast = max(positiveFrequencies);
        omegaSlow = min(positiveFrequencies);
        fastPeriod = 2*pi/omegaFast;
        slowPeriod = 2*pi/omegaSlow;
        Ts = fastPeriod/options.samples_per_fast_period;
    end
    Ts = round_sig(min(0.20,max(0.001,Ts)),3);

    % Continuous Lyapunov equation A'P + PA = -I, solved without requiring
    % Control System Toolbox.
    K = kron(eye(d),A') + kron(A',eye(d));
    identityVector = reshape(eye(d),[],1);
    P = reshape(-(K\identityVector),d,d);
    P = (P+P')/2;
    assert(min(eig(P))>0,'The computed Lyapunov matrix is not positive definite.');

    % Largest P-ellipsoid centred at the target and contained in the box.
    Pinv = inv(P);
    distanceToFaces = min(target-lower,upper-target);
    rhoDomain = min(distanceToFaces./sqrt(max(diag(Pinv),eps)));

    directions = deterministic_directions(d,options.direction_count);
    for i = 1:size(directions,2)
        directions(:,i) = directions(:,i)/sqrt(directions(:,i)'*P*directions(:,i));
    end
    rhoLevels = logspace(log10(max(rhoDomain*1e-4,1e-10)), ...
        log10(rhoDomain),options.radial_levels);
    rhoVerified = rhoLevels(1);
    worstContractionRatio = NaN;
    for rho = rhoLevels
        passed = true;
        worst = -Inf;
        for i = 1:size(directions,2)
            dz = rho*directions(:,i);
            f = rhs(target+dz);
            vdot = 2*dz'*P*f;
            ratio = vdot/max(dot(dz,dz),eps);
            worst = max(worst,ratio);
            if ratio > -options.contraction_margin
                passed = false;
                break
            end
        end
        if passed
            rhoVerified = rho;
            worstContractionRatio = worst;
        else
            break
        end
    end
    rhoTarget = options.target_fraction_of_verified_region*rhoVerified;

    span = upper-lower;
    requestedDiscr = ceil(max(span.*sqrt(weight))/options.eta_grid_per_axis);
    discr = make_odd(min(options.maximum_discr, ...
        max(options.minimum_discr,requestedDiscr)));
    cellWidth = span/discr;

    signs = all_signs(d);
    maxCellCornerP = 0;
    for i = 1:size(signs,2)
        corner = signs(:,i).*cellWidth;
        maxCellCornerP = max(maxCellCornerP,corner'*P*corner);
    end
    halfCellsPhysics = floor(rhoTarget/sqrt(max(maxCellCornerP,eps)));
    maxOddWidth = floor(options.maximum_target_cells^(1/d));
    if mod(maxOddWidth,2)==0, maxOddWidth=maxOddWidth-1; end
    halfCellsMemory = max(0,(maxOddWidth-1)/2);
    halfCells = max(0,min(halfCellsPhysics,halfCellsMemory));
    targetCellsBeforeFloor = max(1,2*halfCells+1);
    targetCells = max(options.minimum_target_cells,targetCellsBeforeFloor);
    if mod(targetCells,2)==0, targetCells=targetCells+1; end

    initialRadius = max(rhoTarget,rhoDomain);
    decayTime = log(initialRadius/max(rhoTarget,eps))/slowDecayRate;
    if isfinite(slowPeriod)
        minimumTime = options.minimum_slow_periods*slowPeriod;
        expectedCycles = decayTime/slowPeriod;
    else
        minimumTime = 20/slowDecayRate;
        expectedCycles = 0;
    end
    rawTfinal = max(minimumTime,options.time_safety_factor*decayTime);
    tfinal = ceil_to_nice(min(options.maximum_tfinal,rawTfinal),10);
    repPeriodic = max(10,ceil(options.periodic_safety_factor*expectedCycles)+5);

    estimate = struct();
    estimate.discr = discr;
    estimate.num_of_cell_around_equilibrium = targetCells;
    estimate.tfinal = tfinal;
    estimate.Ts = Ts;
    estimate.rep_periodic = repPeriodic;
    estimate.reltol = 1e-8;
    estimate.abstol = 1e-8;

    audit = struct();
    audit.state_dimension = d;
    audit.spectral_abscissa = spectralAbscissa;
    audit.slowest_decay_rate = slowDecayRate;
    audit.fastest_angular_frequency = omegaFast;
    audit.slowest_angular_frequency = omegaSlow;
    audit.fastest_period = fastPeriod;
    audit.slowest_period = slowPeriod;
    audit.lyapunov_min_eigenvalue = min(eig(P));
    audit.lyapunov_max_eigenvalue = max(eig(P));
    audit.rho_domain = rhoDomain;
    audit.rho_verified_contraction = rhoVerified;
    audit.rho_target = rhoTarget;
    audit.worst_verified_contraction_ratio = worstContractionRatio;
    audit.requested_discr_before_cap = requestedDiscr;
    audit.grid_cap_active = requestedDiscr>options.maximum_discr;
    audit.estimated_discr = discr;
    audit.target_half_cells_from_physics = halfCellsPhysics;
    audit.target_half_cells_from_memory_cap = halfCellsMemory;
    audit.target_cells_before_algorithmic_floor = targetCellsBeforeFloor;
    audit.target_cell_floor_active = targetCells>targetCellsBeforeFloor;
    audit.estimated_target_cells = targetCells;
    audit.target_cells_total = targetCells^d;
    audit.estimated_decay_time = decayTime;
    audit.expected_decay_cycles = expectedCycles;
    audit.raw_tfinal_before_cap = rawTfinal;
    audit.tfinal_cap_active = rawTfinal>options.maximum_tfinal;
    audit.estimated_tfinal = tfinal;
    audit.estimated_Ts = Ts;
    audit.estimated_rep_periodic = repPeriodic;
    audit.reference_LIM_used = false;
    for i = 1:d
        audit.(sprintf('lambda_%d_real',i)) = real(lambda(i));
        audit.(sprintf('lambda_%d_imag',i)) = imag(lambda(i));
    end
end

function directions = deterministic_directions(d,count)
    directions = [eye(d),-eye(d)];
    stream = RandStream('mt19937ar','Seed',20260920+d);
    randomDirections = randn(stream,d,max(0,count-size(directions,2)));
    randomDirections = randomDirections./vecnorm(randomDirections,2,1);
    directions = [directions,randomDirections];
end

function signs = all_signs(d)
    bits = dec2bin(0:2^d-1)-'0';
    signs = (2*bits-1).';
end

function s = set_default(s,name,value)
    if ~isfield(s,name) || isempty(s.(name)), s.(name)=value; end
end

function n = make_odd(n)
    n=max(1,round(n));
    if mod(n,2)==0, n=n+1; end
end

function value = ceil_to_nice(value,step)
    value=step*ceil(value/step);
end

function value = round_sig(value,digits)
    if value==0, return; end
    power=digits-1-floor(log10(abs(value)));
    value=round(value*10^power)/10^power;
end
