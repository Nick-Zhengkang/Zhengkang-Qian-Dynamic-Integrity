function o = genda_A_options(mode)
if nargin < 1, mode = 'pilot'; end
o.mode = validatestring(mode, {'pilot','full','smoke'});
o.alpha = .7;
o.useParallel = true;
o.numWorkers = [];
o.scheduleSeed = 621031;
o.seedList = 99101:99102;
o.diagnosticAngles = 8;
o.radiusFactors = [.85 1 1.15];
o.truthHorizon = 4000;
o.truthTolerance = .002;
o.truthRelTol = 1e-11;
o.truthAbsTol = 1e-12;
o.saveTrajectories = false;
if strcmp(mode,'full')
    o.seedList = 99101:99130;
    o.diagnosticAngles = 24;
elseif strcmp(mode,'smoke')
    o.seedList = 99101;
    o.diagnosticAngles = 2;
    o.radiusFactors = [.85 1.15];
end
end
