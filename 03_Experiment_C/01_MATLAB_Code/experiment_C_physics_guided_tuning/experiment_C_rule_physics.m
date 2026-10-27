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
function varargout = experiment_C_rule_physics(action,varargin)
% Model features and exact target-cell energy checks; no reference LIM.
switch char(action)
    case 'initial'
        [varargout{1:nargout}]=initial(varargin{:});
    case 'regrid'
        [varargout{1:nargout}]=regrid(varargin{:});
    case 'potential'
        varargout{1}=potential(varargin{:});
    case 'trap'
        [varargout{1:nargout}]=trap_label(varargin{:});
    case 'rhs'
        model=varargin{1}; alpha=varargin{2}; z=varargin{3};
        switch char(model)
            case 'quadratic_cubic', force=z(1)-z(1)^2;
            case 'bistable_duffing', force=-z(1)+z(1)^3;
            case 'cosine_quadratic_drag', force=sin(z(1));
            otherwise, error('Unknown model.');
        end
        varargout{1}=[z(2);-alpha*abs(z(2))*z(2)-force];
    otherwise
        error('Unknown physics action.');
end
end

function [p,f]=initial(model,alpha,cfg)
options=struct('beta_target',cfg.beta,'eta_grid',cfg.eta, ...
    'samples_per_period',cfg.samplesPerPeriod, ...
    'domain_margin_fraction',cfg.domainMargin, ...
    'minimum_discr',cfg.minimumGrid,'maximum_discr',cfg.maximumGrid);
[est,a]=estimate_dynin_parameters_from_physics(model,alpha,NaN,options);
f=struct('model',string(model),'alpha',alpha,'target',est.target, ...
    'domain',est.domain,'weight',est.weight, ...
    'Lx',a.nearest_saddle_distance_Lx,'Lv',a.velocity_scale_Lv, ...
    'barrier',a.potential_barrier_deltaV,'omega',a.local_omega0, ...
    'period',a.local_period,'curvature',a.local_curvature);
f.targetAmplitude=min(sqrt(cfg.beta*f.barrier/f.curvature), ...
    sqrt(cfg.beta*f.barrier)/f.omega);
f.initialAmplitude=min(f.Lx,f.Lv/f.omega);
f.decayCoefficient=4*alpha*f.omega/(3*pi);
f.decayEstimate=max(0,(1/f.targetAmplitude-1/f.initialAmplitude) ...
    /f.decayCoefficient);
f.timeFromDecay=10*ceil(max(cfg.minimumPeriods*f.period, ...
    cfg.decaySafety*f.decayEstimate)/10);
f.timeFromPeriod=10*ceil(cfg.minimumPeriods*f.period/10);
f.requestedGrid=ceil(max((f.domain(3)-f.domain(1))/f.Lx, ...
    (f.domain(4)-f.domain(2))/f.Lv)/cfg.eta);
p=struct('discr',est.discr,'k',3,'Ts',f.period/cfg.samplesPerPeriod, ...
    'tfinal',min(cfg.maximumTime,f.timeFromDecay), ...
    'rep_periodic',cfg.repPeriodic,'belt_mode',"energy", ...
    'target_energy_fraction',NaN,'achieved_eta',NaN, ...
    'target_half_x',NaN,'target_half_v',NaN,'geometry_ok',false);
[p,ok]=regrid(p,p.discr,f,cfg);
assert(ok,'Initial grid cannot safely represent at least three target cells.');
end

function [p,ok]=regrid(p,N,f,cfg)
N=ceil(N); if mod(N,2)==0, N=N+1; end
if N>cfg.maximumGrid, ok=false; return; end
p.discr=N;
dh=(f.domain(3:4)-f.domain(1:2))/N;
center=floor((f.target-f.domain(1:2))./dh)+1;
center=max(1,min(N,center));
maxK=2*min([center-1,N-center])+1;
chosen=0; energy=NaN; bounds=NaN(1,4);
if p.belt_mode=="fixed3", candidates=3;
else, candidates=3:2:maxK; end
for k=candidates
    half=(k-1)/2;
    lower=f.domain(1:2)+(center-half-1).*dh;
    upper=f.domain(1:2)+(center+half).*dh;
    q=[lower(1),upper(1)]; v=max(abs([lower(2),upper(2)]));
    e=max(potential(f.model,q))-potential(f.model,f.target(1))+0.5*v^2;
    [leftWell,rightWell]=target_well(f.model);
    valid=all(lower>=f.domain(1:2)) && all(upper<=f.domain(3:4)) && ...
        q(1)>leftWell && q(2)<rightWell && e<=cfg.beta*f.barrier;
    if ~valid, break; end
    chosen=k; energy=e; bounds=[lower upper];
end
ok=chosen>=3;
p.geometry_ok=ok;
if ~ok, return; end
p.k=chosen;
p.target_energy_fraction=energy/f.barrier;
p.target_half_x=max(abs(bounds([1 3])-f.target(1)));
p.target_half_v=max(abs(bounds([2 4])));
p.achieved_eta=max(dh./[f.Lx f.Lv]);
end

function [label,reason]=trap_label(model,z,f,margin)
% Energy confinement identifies an eventual well, not a convergence time.
label=0; reason="unresolved";
E=0.5*z(2)^2+potential(model,z(1));
switch char(model)
    case 'quadratic_cubic'
        if z(1)>1 && z(2)>0
            label=2; reason="right_escape";
        elseif z(1)<1 && E<(1-margin)*f.barrier
            label=1; reason="energy_trapped_target";
        end
    case 'bistable_duffing'
        if E<potential(model,-1)+(1-margin)*f.barrier
            if z(1)<0, label=1; reason="energy_trapped_target";
            elseif z(1)>0, label=2; reason="energy_trapped_other"; end
        end
    case 'cosine_quadratic_drag'
        if E<(1-margin)*f.barrier
            well=floor((z(1)+pi)/(2*pi));
            if well==0, label=1; reason="energy_trapped_target";
            else, label=2; reason="energy_trapped_other"; end
        end
end
end

function [left,right]=target_well(model)
switch char(model)
    case 'quadratic_cubic', left=-inf; right=1;
    case 'bistable_duffing', left=-inf; right=0;
    case 'cosine_quadratic_drag', left=-pi; right=pi;
    otherwise, error('Unknown model.');
end
end

function V=potential(model,x)
switch char(model)
    case 'quadratic_cubic', V=0.5*x.^2-x.^3/3;
    case 'bistable_duffing', V=-0.5*x.^2+0.25*x.^4;
    case 'cosine_quadratic_drag', V=1-cos(x);
    otherwise, error('Unknown model.');
end
end
