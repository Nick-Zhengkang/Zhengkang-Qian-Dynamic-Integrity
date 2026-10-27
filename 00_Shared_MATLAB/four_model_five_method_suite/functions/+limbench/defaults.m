function c=defaults()
c.seeds=1:10; c.radialSteps=[0.05 0.025]; c.scanStep=0.05;
c.queryBudget=4096; c.maxSeconds=3;
c.relativeThresholds=[0.005 0.002 0.001];
c.initialDirections=16; c.uniformDirections=32; c.maxDirections=64;
c.fixedBisections=8; c.radialTolerance=1e-4; c.maxRadius=2.5;
c.globalEvery=4; c.batchSize=4;
% Internal stopping tolerances depend on the incumbent, never on R_ref.
c.stopRelativeChange=2e-4; c.stopAbsoluteChange=2e-5;
c.minRounds=3; c.patience=2;
c.globalGapLimit=2*pi/32; c.localGapLimit=2*pi/256;
c.RelTol=1e-8; c.AbsTol=1e-10; c.MaxStep=0.25;
c.timeStages=[100 400 1200]; c.energyMargin=1e-8;
c.synthetic=false;
% Controlled common-classifier GA profiles: NOT coarse/fine grid settings.
c.gaCoarseGenerations=10; c.gaFineGenerations=40;
c.gaCrossover=9; c.gaSelected=3; c.gaNewcomers=8; c.gaClones=2;
c.gaDivR=40; c.bisIterMax=5;
c.energyInitial=24; c.energyActive=50; c.energyPool=4000;
c.energyBisections=8;
c.version='adaptive-angle-v1.0.0';
end
