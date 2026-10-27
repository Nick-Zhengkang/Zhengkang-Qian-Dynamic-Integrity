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
function cfg = experiment_C_rule_defaults(mode)
% Prespecified candidate constants, not experimentally established optima.
if nargin==0, mode='develop'; end
mode=validatestring(mode,{'smoke','develop','confirm'});
cfg.version='rule_hypotheses_v1';
cfg.mode=mode;
cfg.seeds=1:10;
cfg.budgets=100;
cfg.eta=0.005;
cfg.beta=0.005;
cfg.samplesPerPeriod=125;
cfg.decaySafety=1.5;
cfg.minimumPeriods=20;
cfg.domainMargin=0.20;
cfg.minimumGrid=101;
cfg.maximumGrid=2401;
cfg.maximumTime=20000;
cfg.minimumTs=0.001;
cfg.maxRefinements=2;
cfg.maxCombinedPasses=2;
cfg.repFixPoint=40;
cfg.repPeriodic=10;
cfg.relTol=1e-8;
cfg.absTol=1e-8;
cfg.calibrationAngles=12;
cfg.holdoutAngles=12;
cfg.calibrationRadii=[0.10 0.40 0.70 1.00 1.30];
cfg.holdoutRadii=[0.15 0.50 0.85 1.15];
cfg.boundaryBisections=3;
cfg.holdoutBoundaryBisections=4;
cfg.oraclePeriods=200;
cfg.oracleMaxTime=40000;
cfg.oracleEnergyMargin=0.01;
cfg.oracleRelTol=1e-10;
cfg.oracleAbsTol=1e-11;
cfg.maxFalseSafe=0;
cfg.maxFalseUnsafe=0.02;
cfg.maxUnresolved=0.02;
cfg.maxTruthUnresolved=0.05;
cfg.minClassCount=5;
cfg.minBoundaryPoints=3;
cfg.labelChangeThreshold=0;
cfg.maxPathDistanceChange=0.005;
cfg.targetRelativeError=0.01;
cfg.requiredLIMSuccessRate=0.90;
cfg.maximumEstimatedAllocationGB=2;
cfg.writeTrajectoryHistory=true;
if strcmp(mode,'confirm')
    cfg.seeds=31:60;
elseif strcmp(mode,'smoke')
    cfg.seeds=1;
    cfg.budgets=5;
    cfg.calibrationAngles=4;
    cfg.holdoutAngles=4;
    cfg.calibrationRadii=[0.2 1.1];
    cfg.holdoutRadii=[0.3 1.2];
    cfg.boundaryBisections=1;
    cfg.holdoutBoundaryBisections=1;
    cfg.maxRefinements=1;
    cfg.maxCombinedPasses=1;
    cfg.minClassCount=1;
    cfg.minBoundaryPoints=1;
end
end
