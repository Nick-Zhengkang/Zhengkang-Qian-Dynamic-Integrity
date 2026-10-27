function [f,p,historical,cfg,audit]=experiment_C_cosine_settings(alpha)
% Generate a target-well domain without using a reference LIM.
assert(abs(alpha-0.05)<1e-12,'This confirmation uses the original alpha=0.05 benchmark.');
cfg=experiment_C_rule_defaults('confirm');
cfg.version='cosine_transfer_v1';
cfg.calibrationAngles=16; cfg.holdoutAngles=16;
cfg.calibrationRadii=[0.05 0.35 0.65 0.9 0.999];
cfg.holdoutRadii=[0.025 0.25 0.55 0.8 0.98 0.9999];
cfg.boundaryBisections=4; cfg.holdoutBoundaryBisections=4;
% The constants beta, eta, and decaySafety are inherited, not retuned here.
f=struct('model',"cosine_quadratic_drag",'alpha',alpha,'target',[0 0], ...
    'domain',[-pi -pi pi pi],'weight',[1 1],'Lx',pi,'Lv',2, ...
    'barrier',2,'omega',1,'period',2*pi,'curvature',1);
% x faces fix R0=pi. Add velocity padding WITHOUT enlarging R0.
vmax=pi*(1+2*cfg.eta);
f.domain=[-pi -vmax pi vmax];
f.targetAmplitude=sqrt(cfg.beta*f.barrier);
f.initialAmplitude=min(f.Lx,f.Lv/f.omega);
f.decayCoefficient=4*alpha*f.omega/(3*pi);
f.decayEstimate=(1/f.targetAmplitude-1/f.initialAmplitude)/f.decayCoefficient;
f.timeFromDecay=10*ceil(max(cfg.minimumPeriods*f.period, ...
    cfg.decaySafety*f.decayEstimate)/10);
f.requestedGrid=ceil(max((f.domain(3:4)-f.domain(1:2))./[f.Lx f.Lv])/cfg.eta);
p=struct('discr',0,'k',3,'Ts',f.period/cfg.samplesPerPeriod, ...
    'tfinal',min(cfg.maximumTime,f.timeFromDecay),'rep_periodic',cfg.repPeriodic, ...
    'belt_mode',"energy",'target_energy_fraction',NaN,'achieved_eta',NaN, ...
    'target_half_x',NaN,'target_half_v',NaN,'geometry_ok',false);
[p,ok]=experiment_C_rule_physics('regrid',p,max(cfg.minimumGrid,f.requestedGrid),f,cfg);
assert(ok,'Cannot represent a target neighbourhood of at least 3 cells.');
% Historical COSINE classifier controls, with the SAME frozen GA in both arms.
% This is not called a Habib-paper GA reproduction.
historical=struct('discr',501,'k',11,'Ts',0.05,'tfinal',1200, ...
    'rep_periodic',10,'domain',[-pi -8 pi 8],'relTol',1e-8,'absTol',1e-9);
audit=struct('alpha',alpha,'target_x',0,'target_v',0,'weight_x',1,'weight_v',1, ...
    'saddle_left',-pi,'saddle_right',pi,'barrier',2,'Lx',f.Lx,'Lv',f.Lv, ...
    'local_period',f.period,'initial_search_radius',pi,'search_energy_cap',pi^2/2, ...
    'velocity_bound',pi,'velocity_face',vmax,'beta',cfg.beta,'eta',cfg.eta, ...
    'discr',p.discr,'k',p.k,'Ts',p.Ts,'initial_tfinal',p.tfinal, ...
    'target_energy_fraction',p.target_energy_fraction,'achieved_eta',p.achieved_eta, ...
    'global_position_envelope_available',false,'outward_saddle_exit_certified',true);
% E=v^2/2+1-cos(x) <= (x^2+v^2)/2 <= pi^2/2 on the GA ball.
% E'=-alpha*abs(v)^3 <= 0, so |v(t)|<=pi. Position is NOT energy-bounded.
% After an outward crossing of +/-pi, a reversal would have E=V(x)<=2;
% strict dissipation prevents recrossing a saddle of energy 2 into this well.
end
