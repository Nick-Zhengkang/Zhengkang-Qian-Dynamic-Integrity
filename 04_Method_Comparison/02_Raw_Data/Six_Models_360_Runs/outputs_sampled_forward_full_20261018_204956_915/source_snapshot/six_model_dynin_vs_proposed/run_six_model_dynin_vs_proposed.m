function outputDirectory = run_six_model_dynin_vs_proposed( ...
        runMode,seedList,resumeDirectory)
%RUN_SIX_MODEL_DYNIN_VS_PROPOSED Compare original DynIn GA and proposed.
%
% DynIn uses the original type_x0=1 GA branch with all later adaptive-grid
% extensions disabled. Proposed uses adaptive angular search without
% trajectory reuse. References are scoring-only.

    % Opt-in reuse of the original adapter; ordinary experiments are unchanged.
    if nargin>=1 && string(runMode)=="comparison_api"
        outputDirectory=struct('cases',@build_cases, ...
            'configurations',@build_dynin_configurations,'dynin',@execute_dynin);
        return
    end
    if nargin<1 || strlength(string(runMode))==0, runMode="pilot"; end
    if nargin<2 || isempty(seedList)
        if string(runMode)=="full", seedList=1:30; else, seedList=1:3; end
    end
    if nargin<3, resumeDirectory=""; end
    runMode=string(runMode);
    assert(any(runMode==["pilot","full"]),'runMode must be pilot or full.');
    seedList=double(seedList(:).');
    validateattributes(seedList,{'numeric'},{'integer','positive','finite','vector'});
    assert(numel(unique(seedList))==numel(seedList),'seedList contains duplicates.');

    here=fileparts(mfilename('fullpath'));
    repoRoot=fileparts(here);
    dyninDir=fullfile(repoRoot,'work','DynIn','DynIn_v1.1.0','functions');
    packageDir=fullfile(repoRoot,'four_model_five_method_suite','functions');
    habib4dDir=fullfile(repoRoot,'habib_4d_adaptive_radial');
    separable4dDir=fullfile(repoRoot,'separable_4d_analytic_benchmark');
    habibModelDir=fullfile(repoRoot,'work','DynIn','DynIn_v1.1.0', ...
        'VanDerPolDuffing_NLTVA');
    assert(isfile(fullfile(dyninDir,'compute_LIM_FP.m')), ...
        'Original DynIn v1.1.0 compute_LIM_FP.m was not found.');
    assert(isfile(fullfile(habibModelDir,'coefficients_VDPD_NLTVA.m')), ...
        'Habib 4D model was not found.');

    if strlength(string(resumeDirectory))>0
        outputDirectory=char(resumeDirectory);
        assert(isfolder(outputDirectory),'Resume directory does not exist.');
    else
        stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
        outputDirectory=fullfile(here,['outputs_six_model_' stamp]);
        mkdir(outputDirectory);
    end
    modelRoot=fullfile(outputDirectory,'dynin_models');
    if ~isfolder(modelRoot), mkdir(modelRoot); end

    oldPath=path;
    pathGuard=onCleanup(@()path(oldPath)); %#ok<NASGU>
    addpath(packageDir,'-begin');
    addpath(habib4dDir,'-begin');
    addpath(separable4dDir,'-begin');
    limbench.verify_freeze();

    [cases,references]=build_cases(habibModelDir);
    atomic_write_table(references,fullfile(outputDirectory, ...
        'benchmark_references.csv'));
    configs=build_dynin_configurations(cases,modelRoot,habibModelDir);
    atomic_write_table(configs_to_table(configs),fullfile(outputDirectory, ...
        'dynin_configurations.csv'));

    protocol=struct('version',"six-model-v1",'runMode',runMode, ...
        'seedList',seedList,'caseIds',{string(cases.model_id)}, ...
        'methods',["dynin_original_ga","proposed_adaptive_angle"], ...
        'scheduleSeed',20260926);
    protocolFile=fullfile(outputDirectory,'protocol.mat');
    if isfile(protocolFile)
        previous=load(protocolFile,'protocol');
        assert(isequaln(previous.protocol,protocol), ...
            'Resume protocol differs from the saved experiment.');
    else
        save(protocolFile,'protocol');
    end

    rawPath=fullfile(outputDirectory,'raw_data_all_runs.csv');
    if isfile(rawPath), raw=readtable(rawPath,'TextType','string');
    else, raw=table(); end

    % Direct schedule: all 2D runs and the DynIn side of both 4D models.
    schedule=build_direct_schedule(cases,seedList,protocol.scheduleSeed);
    atomic_write_table(schedule,fullfile(outputDirectory, ...
        'randomized_direct_schedule.csv'));
    completed=strings(0,1);
    if ~isempty(raw) && ismember('run_key',raw.Properties.VariableNames)
        completed=string(raw.run_key(logical(raw.success)));
    end

    fprintf('\nDynIn GA versus proposed adaptive angle: %s mode\n',runMode);
    fprintf('Models: %d; paired seeds: %d; expected runs: %d\n', ...
        height(cases),numel(seedList),2*height(cases)*numel(seedList));
    fprintf('Output directory:\n%s\n\n',outputDirectory);

    for iRun=1:height(schedule)
        item=schedule(iRun,:);
        key=string(item.run_key);
        if any(completed==key)
            fprintf('[direct %d/%d] SKIP %s\n',iRun,height(schedule),key);
            continue
        end
        c=table2struct(cases(cases.model_id==item.model_id,:));
        cfg=configs.(char(c.model_id));
        fprintf('[direct %d/%d] START model=%s, method=%s, seed=%d\n', ...
            iRun,height(schedule),c.model_id,item.method,item.seed);
        rng(item.algorithm_seed,'twister');
        if item.method=="dynin_original_ga"
            outcome=execute_dynin(cfg,dyninDir,item.algorithm_seed,iRun);
        else
            outcome=execute_proposed_2d(c,packageDir,item.algorithm_seed);
        end
        row=common_row(c,item.method,item.seed,item.algorithm_seed, ...
            item.execution_order,"randomized_direct",outcome);
        raw=replace_or_append(raw,row);
        atomic_write_table(raw,rawPath);
        if row.success, completed(end+1,1)=key; end %#ok<AGROW>
        fprintf('[direct %d/%d] DONE R=%.8g, err=%.3f%%, eval=%g, wall=%.2fs, %s\n', ...
            iRun,height(schedule),row.R_hat,100*row.relative_error, ...
            row.trajectory_evaluations,row.wall_runtime_s,row.stop_status);
    end

    % Proposed 4D implementations are reused byte-for-byte and restricted
    % to adaptive_s3_radial. Their internal seed schedules are retained.
    stateFile=fullfile(outputDirectory,'child_output_state.mat');
    if isfile(stateFile)
        state=load(stateFile);
    else
        state=struct('habib4dOutput',"",'separable4dOutput',"");
    end
    state.habib4dOutput=run_habib_4d_adaptive_radial_benchmark( ...
        char(runMode),0.075,seedList,state.habib4dOutput, ...
        "adaptive_s3_radial");
    save(stateFile,'-struct','state');
    state.separable4dOutput=run_separable_4d_analytic_benchmark( ...
        char(runMode),0.4,0.7,seedList,state.separable4dOutput, ...
        "adaptive_s3_radial");
    save(stateFile,'-struct','state');

    raw=import_4d_proposed(raw,cases,"habib_vdp_tmd_4d", ...
        state.habib4dOutput,"published_numerical_Habib_2021");
    raw=import_4d_proposed(raw,cases,"separable_qc_bd_4d", ...
        state.separable4dOutput,"exact_analytical_product_basin");
    raw=sortrows(raw,{'model_order','seed','method'});
    atomic_write_table(raw,rawPath);

    manifest=table(["habib_vdp_tmd_4d";"separable_qc_bd_4d"], ...
        [string(state.habib4dOutput);string(state.separable4dOutput)], ...
        'VariableNames',{'model_id','child_output_directory'});
    atomic_write_table(manifest,fullfile(outputDirectory, ...
        'child_output_manifest.csv'));

    summary=summarize_results(raw);
    paired=summarize_paired(raw);
    atomic_write_table(summary,fullfile(outputDirectory, ...
        'summary_by_model_and_method.csv'));
    atomic_write_table(paired,fullfile(outputDirectory, ...
        'paired_contrasts_proposed_vs_dynin.csv'));

    expected=2*height(cases)*numel(seedList);
    fprintf('\nSix-model comparison finished: %d/%d rows written.\n', ...
        height(raw),expected);
    fprintf('Raw: %s\nSummary: %s\n',rawPath,fullfile(outputDirectory, ...
        'summary_by_model_and_method.csv'));
end

function [cases,references]=build_cases(habibModelDir)
    ids=["quadratic_cubic";"bistable_duffing"; ...
        "habib_unforced_duffing";"genda_cosine_quadratic_drag"; ...
        "habib_vdp_tmd_4d";"separable_qc_bd_4d"];
    labels=["Quadratic-cubic potential";"Bistable Duffing potential"; ...
        "Habib unforced Duffing oscillator"; ...
        "Genda cosine potential with quadratic drag"; ...
        "Habib Duffing-van der Pol oscillator with NLTVA/TMD"; ...
        "Separable QC x bistable Duffing 4D benchmark"];
    dimension=[2;2;2;2;4;4];
    parameter_name=["alpha";"alpha";"zeta";"alpha";"mu1";"alpha_qc/alpha_bd"];
    parameter_value=["0.4";"0.7";"0.05";"0.05";"0.075";"0.4/0.7"];
    references=zeros(6,1); kinds=strings(6,1); sources=strings(6,1);
    mapNames=["quadratic_cubic","bistable_duffing", ...
        "paper_unforced_duffing","genda_cosine_quadratic_drag"];
    alphas=[0.4 0.7 0.05 0.05];
    for i=1:4
        [ref,~]=fourbench.reference(char(mapNames(i)),alphas(i));
        references(i)=ref.R; kinds(i)=string(ref.kind); sources(i)=string(ref.source);
    end
    references(5)=0.57370;
    kinds(5)="published_approximate_numerical";
    sources(5)="Habib 2021, 4D Duffing-van der Pol + NLTVA/TMD, mu1=0.075";
    [q,~]=limbench.reference('quadratic_cubic',0.4);
    [b,~]=limbench.reference('bistable_duffing',0.7);
    references(6)=min(q.R,b.R);
    kinds(6)="exact_analytical_product_basin";
    sources(6)="Direct product theorem: min(R_QC,R_BD)";
    cases=table((1:6).',ids,labels,dimension,parameter_name,parameter_value, ...
        references,kinds,sources,repmat(string(habibModelDir),6,1), ...
        'VariableNames',{'model_order','model_id','model_label','dimension', ...
        'parameter_name','parameter_value','R_reference','reference_kind', ...
        'reference_source','habib_model_directory'});
    references=cases(:,{'model_order','model_id','model_label','dimension', ...
        'parameter_name','parameter_value','R_reference','reference_kind', ...
        'reference_source'});
end

function configs=build_dynin_configurations(cases,modelRoot,habibModelDir)
    configs=struct();
    for i=1:height(cases)
        id=char(cases.model_id(i));
        cfg=common_dynin_config();
        cfg.model_id=string(id);
        switch id
            case 'quadratic_cubic'
                cfg.target=[0 0]; cfg.weight=[1 1];
                cfg.domain=[-1 -1 1 1]; cfg.discr=401; cfg.targetCells=12;
                cfg.tfinal=1200; cfg.Ts=.05; cfg.numberOfSteps=100;
                cfg.par=struct('alpha',.4);
            case 'bistable_duffing'
                cfg.target=[-1 0]; cfg.weight=[1 1];
                cfg.domain=[-2 -2 1 2]; cfg.discr=401; cfg.targetCells=12;
                cfg.tfinal=1200; cfg.Ts=.05; cfg.numberOfSteps=100;
                cfg.par=struct('alpha',.7);
            case 'habib_unforced_duffing'
                cfg.target=[-1 0]; cfg.weight=[4 1];
                cfg.domain=[-3 -2 3 4]; cfg.discr=701; cfg.targetCells=3;
                cfg.tfinal=2000; cfg.Ts=.05; cfg.numberOfSteps=100;
                cfg.par=struct('alpha',.05,'a',1);
            case 'genda_cosine_quadratic_drag'
                cfg.target=[0 0]; cfg.weight=[1 1];
                cfg.domain=[-pi -8 pi 8]; cfg.discr=501; cfg.targetCells=11;
                cfg.tfinal=1200; cfg.Ts=.05; cfg.numberOfSteps=100;
                cfg.par=struct('alpha',.05);
            case 'habib_vdp_tmd_4d'
                guard=temporary_path(habibModelDir); %#ok<NASGU>
                [cfg.par,cfg.weight]=coefficients_VDPD_NLTVA( ...
                    .97,.12,.05,.3,0,.075);
                cfg.target=zeros(1,4); cfg.domain=[-3*ones(1,4) 3*ones(1,4)];
                cfg.discr=701; cfg.targetCells=3; cfg.tfinal=2000;
                cfg.Ts=.05; cfg.numberOfSteps=40; cfg.modelDir=habibModelDir;
            case 'separable_qc_bd_4d'
                cfg.target=[0 0 -1 0]; cfg.weight=ones(1,4);
                cfg.domain=[-4 -4 -4 -4 2 4 2 4];
                cfg.discr=801; cfg.targetCells=7; cfg.tfinal=1200;
                cfg.Ts=.05; cfg.numberOfSteps=100;
                cfg.par=struct('alpha_qc',.4,'alpha_bd',.7);
            otherwise
                error('Unknown model: %s',id);
        end
        if strlength(string(cfg.modelDir))==0
            cfg.modelDir=fullfile(modelRoot,id);
            if ~isfolder(cfg.modelDir), mkdir(cfg.modelDir); end
            write_sistema(cfg.modelDir,id);
        end
        configs.(id)=cfg;
    end
end

function cfg=common_dynin_config()
    cfg=struct('model_id',"",'target',[],'weight',[],'domain',[], ...
        'discr',NaN,'targetCells',NaN,'tfinal',NaN,'Ts',NaN, ...
        'numberOfSteps',NaN,'par',struct(),'modelDir',"", ...
        'RelTol',1e-8,'AbsTol',1e-8,'repFixPoint',40, ...
        'repPeriodic',10,'divR',40,'numGen',5,'numCrossover',9, ...
        'selectedOpt',3,'newcomers',8,'clones',2);
end

function schedule=build_direct_schedule(cases,seeds,scheduleSeed)
    rows=cell(0,1);
    for i=1:height(cases)
        methods="dynin_original_ga";
        if cases.dimension(i)==2
            methods=[methods,"proposed_adaptive_angle"];
        end
        for seed=seeds
            for method=methods
                algorithmSeed=800000+1000*i+seed;
                key=sprintf('%s__%s__seed_%03d',cases.model_id(i),method,seed);
                rows{end+1,1}=struct('model_id',cases.model_id(i), ...
                    'method',method,'seed',seed,'algorithm_seed',algorithmSeed, ...
                    'run_key',string(key)); %#ok<AGROW>
            end
        end
    end
    schedule=struct2table(vertcat(rows{:}));
    old=rng; guard=onCleanup(@()rng(old)); %#ok<NASGU>
    rng(scheduleSeed,'twister'); schedule=schedule(randperm(height(schedule)),:);
    schedule.execution_order=(1:height(schedule)).';
    schedule=movevars(schedule,'execution_order','Before',1);
end

function [outcome,details]=execute_dynin(cfg,dyninDir,seed,runIndex)
    outcome=empty_outcome();
    details=struct();
    oldPath=path; guard=onCleanup(@()path(oldPath)); %#ok<NASGU>
    addpath(cfg.modelDir,'-begin'); addpath(dyninDir,'-begin');
    clear('sistema','compute_LIM_FP'); rehash;
    assert(strcmpi(normalize_path(which('sistema')), ...
        normalize_path(fullfile(cfg.modelDir,'sistema.m'))), ...
        'Wrong sistema.m resolved for %s.',cfg.model_id);
    % The unmodified v1.1.0 function uses 29 positional optional inputs.
    % Keep this order synchronized with its inputParser declaration.
    values={cfg.tfinal,cfg.Ts,cfg.weight,1,cfg.RelTol,cfg.AbsTol, ...
        cfg.numberOfSteps,cfg.targetCells,40000+runIndex,0,0, ...
        cfg.domain,cfg.discr,1,1,2,cfg.repFixPoint,cfg.repPeriodic, ...
        .005,0,0,10000,cfg.divR,cfg.numGen,cfg.numCrossover, ...
        cfg.selectedOpt,cfg.newcomers,cfg.clones,5};
    rng(seed,'twister'); timer=tic;
    try
        [R,OutL]=compute_LIM_FP(cfg.target,cfg.par,values{:});
        details=OutL;
        outcome.wall_runtime_s=toc(timer); outcome.R_hat=R;
        outcome.algorithm_runtime_s=safe_field(OutL,'total_time', ...
            outcome.wall_runtime_s);
        outcome.trajectory_evaluations=count_dynin_evaluations(OutL);
        outcome.query_count=outcome.trajectory_evaluations;
        outcome.integration_count=outcome.trajectory_evaluations;
        outcome.success=isfinite(R); outcome.stop_status="completed_steps";
        if ~outcome.success, outcome.stop_status="nonfinite_result"; end
    catch ME
        outcome.wall_runtime_s=toc(timer);
        outcome.stop_status="failed";
        outcome.error_message=string(getReport(ME,'basic','hyperlinks','off'));
    end
end

function outcome=execute_proposed_2d(c,packageDir,seed)
    outcome=empty_outcome();
    oldPath=path; guard=onCleanup(@()path(oldPath)); %#ok<NASGU>
    addpath(packageDir,'-begin'); rng(seed,'twister');
    mapName=char(c.model_id);
    if strcmp(mapName,'habib_unforced_duffing')
        mapName='paper_unforced_duffing';
    end
    alpha=str2double(extractBefore(c.parameter_value+"/","/"));
    model=fourbench.model(mapName,alpha);
    settings=limbench.defaults();
    if strcmp(mapName,'paper_unforced_duffing')
        settings.timeStages=[100 400 1200 2000];
    end
    timer=tic;
    try
        [r,~,~]=limbench.proposed_four_models(model,settings);
        outcome.wall_runtime_s=toc(timer); outcome.algorithm_runtime_s=r.runtime;
        outcome.R_hat=r.R; outcome.query_count=r.queries;
        outcome.integration_count=safe_field(r,'odeCalls',r.queries);
        outcome.trajectory_evaluations=outcome.integration_count;
        outcome.direction_count=safe_field(r,'directions',NaN);
        outcome.success=isfinite(r.R);
        outcome.stop_status=string(safe_field(r,'reason',"completed"));
    catch ME
        outcome.wall_runtime_s=toc(timer); outcome.stop_status="failed";
        outcome.error_message=string(getReport(ME,'basic','hyperlinks','off'));
    end
end

function raw=import_4d_proposed(raw,cases,modelId,folder,referenceKind)
    child=readtable(fullfile(folder,'raw_data_all_runs.csv'),'TextType','string');
    child=child(string(child.method)=="adaptive_s3_radial",:);
    c=table2struct(cases(cases.model_id==modelId,:));
    for i=1:height(child)
        outcome=empty_outcome();
        outcome.success=logical(child.success(i)); outcome.R_hat=child.R_hat(i);
        outcome.query_count=child.query_count(i);
        outcome.integration_count=child.integration_count(i);
        outcome.trajectory_evaluations=child.integration_count(i);
        outcome.direction_count=child.direction_count(i);
        outcome.algorithm_runtime_s=child.algorithm_runtime_s(i);
        outcome.wall_runtime_s=child.wall_runtime_s(i);
        outcome.stop_status=string(child.stop_status(i));
        outcome.audit_pass=logical(child.post_audit_pass(i));
        outcome.error_message=string(child.error_message(i));
        row=common_row(c,"proposed_adaptive_angle",child.seed(i), ...
            child.algorithm_seed(i),NaN,"four_dimensional_child",outcome);
        row.reference_kind=string(referenceKind);
        raw=replace_or_append(raw,row);
    end
end

function row=common_row(c,method,seed,algorithmSeed,executionOrder,block,outcome)
    row=struct();
    row.run_key=sprintf('%s__%s__seed_%03d',c.model_id,method,seed);
    row.execution_order=executionOrder; row.execution_block=string(block);
    row.model_order=c.model_order; row.model_id=string(c.model_id);
    row.model_label=string(c.model_label); row.dimension=c.dimension;
    row.parameter_name=string(c.parameter_name);
    row.parameter_value=string(c.parameter_value);
    row.seed=seed; row.algorithm_seed=algorithmSeed; row.method=string(method);
    row.success=logical(outcome.success); row.R_hat=outcome.R_hat;
    row.R_reference=c.R_reference; row.reference_kind=string(c.reference_kind);
    row.absolute_error=abs(row.R_hat-row.R_reference);
    row.relative_error=row.absolute_error/row.R_reference;
    row.signed_relative_error=(row.R_hat-row.R_reference)/row.R_reference;
    row.within_1_percent=row.relative_error<=.01;
    row.within_2_percent=row.relative_error<=.02;
    row.within_5_percent=row.relative_error<=.05;
    row.trajectory_evaluations=outcome.trajectory_evaluations;
    row.query_count=outcome.query_count;
    row.integration_count=outcome.integration_count;
    row.direction_count=outcome.direction_count;
    row.algorithm_runtime_s=outcome.algorithm_runtime_s;
    row.wall_runtime_s=outcome.wall_runtime_s;
    row.stop_status=string(outcome.stop_status);
    row.audit_pass=logical(outcome.audit_pass);
    row.error_message=string(outcome.error_message);
end

function outcome=empty_outcome()
    outcome=struct('success',false,'R_hat',NaN, ...
        'trajectory_evaluations',NaN,'query_count',NaN, ...
        'integration_count',NaN,'direction_count',NaN, ...
        'algorithm_runtime_s',NaN,'wall_runtime_s',NaN, ...
        'stop_status',"not_started",'audit_pass',false,'error_message',"");
end

function summary=summarize_results(raw)
    rows=cell(0,1); models=unique(raw.model_id,'stable');
    methods=["dynin_original_ga","proposed_adaptive_angle"];
    for model=models.'
        for method=methods
            g=raw(raw.model_id==model & raw.method==method,:);
            if isempty(g), continue; end
            row=struct('model_order',g.model_order(1),'model_id',model, ...
                'model_label',g.model_label(1),'dimension',g.dimension(1), ...
                'method',method,'n_runs',height(g),'n_success',nnz(g.success), ...
                'R_reference',g.R_reference(1), ...
                'median_R_hat',median_finite(g.R_hat), ...
                'median_relative_error',median_finite(g.relative_error), ...
                'p95_relative_error',percentile_finite(g.relative_error,95), ...
                'max_relative_error',max_finite(g.relative_error), ...
                'within_1_percent_fraction',mean(double(g.within_1_percent)), ...
                'within_2_percent_fraction',mean(double(g.within_2_percent)), ...
                'within_5_percent_fraction',mean(double(g.within_5_percent)), ...
                'median_trajectory_evaluations', ...
                    median_finite(g.trajectory_evaluations), ...
                'median_algorithm_runtime_s',median_finite(g.algorithm_runtime_s), ...
                'median_wall_runtime_s',median_finite(g.wall_runtime_s), ...
                'audit_pass_fraction',mean(double(g.audit_pass)));
            rows{end+1,1}=row; %#ok<AGROW>
        end
    end
    summary=struct2table(vertcat(rows{:}));
    summary=sortrows(summary,{'model_order','method'});
end

function paired=summarize_paired(raw)
    rows=cell(0,1); models=unique(raw.model_id,'stable');
    for model=models.'
        d=raw(raw.model_id==model & raw.method=="dynin_original_ga",:);
        p=raw(raw.model_id==model & raw.method=="proposed_adaptive_angle",:);
        [shared,ip,id]=intersect(p.seed,d.seed,'stable');
        if isempty(shared), continue; end
        row=struct('model_order',p.model_order(1),'model_id',model, ...
            'dimension',p.dimension(1),'n_paired_seeds',numel(shared), ...
            'median_delta_relative_error',median_finite( ...
                p.relative_error(ip)-d.relative_error(id)), ...
            'median_error_ratio',median_finite( ...
                p.relative_error(ip)./max(d.relative_error(id),eps)), ...
            'median_evaluation_ratio',median_finite( ...
                p.trajectory_evaluations(ip)./d.trajectory_evaluations(id)), ...
            'median_runtime_ratio',median_finite( ...
                p.algorithm_runtime_s(ip)./d.algorithm_runtime_s(id)), ...
            'proposed_better_error_fraction',mean( ...
                p.relative_error(ip)<d.relative_error(id)), ...
            'proposed_faster_fraction',mean( ...
                p.algorithm_runtime_s(ip)<d.algorithm_runtime_s(id)));
        rows{end+1,1}=row; %#ok<AGROW>
    end
    paired=struct2table(vertcat(rows{:}));
    paired=sortrows(paired,'model_order');
end

function T=configs_to_table(configs)
    names=fieldnames(configs); rows=cell(numel(names),1);
    for i=1:numel(names)
        c=configs.(names{i});
        rows{i}=struct('model_id',string(c.model_id),'dimension',numel(c.target), ...
            'target',string(mat2str(c.target)),'weight',string(mat2str(c.weight)), ...
            'domain',string(mat2str(c.domain)),'discr',c.discr, ...
            'target_cells',c.targetCells,'tfinal',c.tfinal,'Ts',c.Ts, ...
            'RelTol',c.RelTol,'AbsTol',c.AbsTol, ...
            'number_of_steps',c.numberOfSteps,'type_x0',1,'divR',c.divR, ...
            'num_gen',c.numGen,'num_crossover',c.numCrossover, ...
            'selected_opt',c.selectedOpt,'newcomers',c.newcomers, ...
            'num_almost_clones',c.clones,'adaptive_grid_enabled',false);
    end
    T=struct2table(vertcat(rows{:}));
end

function write_sistema(folder,id)
    file=fullfile(folder,'sistema.m'); fid=fopen(file,'w');
    assert(fid>=0,'Could not create %s.',file);
    guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid,'function dz=sistema(~,z,par)\n');
    if strcmp(id,'separable_qc_bd_4d')
        fprintf(fid,'dz=zeros(4,1); z=z(:);\n');
        fprintf(fid,'dz(1)=z(2);\n');
        fprintf(fid,'dz(2)=-par.alpha_qc*abs(z(2))*z(2)-z(1)+z(1)^2;\n');
        fprintf(fid,'dz(3)=z(4);\n');
        fprintf(fid,'dz(4)=-par.alpha_bd*abs(z(4))*z(4)+z(3)-z(3)^3;\n');
    else
        fprintf(fid,'dz=zeros(2,1); z=z(:); dz(1)=z(2);\n');
        switch id
            case 'quadratic_cubic'
                fprintf(fid,'dz(2)=-par.alpha*abs(z(2))*z(2)-z(1)+z(1)^2;\n');
            case 'bistable_duffing'
                fprintf(fid,'dz(2)=-par.alpha*abs(z(2))*z(2)+z(1)-z(1)^3;\n');
            case 'habib_unforced_duffing'
                fprintf(fid,'dz(2)=-2*par.alpha*z(2)+z(1)-par.a*z(1)^3;\n');
            case 'genda_cosine_quadratic_drag'
                fprintf(fid,'dz(2)=-par.alpha*abs(z(2))*z(2)-sin(z(1));\n');
            otherwise
                error('Unknown generated model: %s',id);
        end
    end
    fprintf(fid,'end\n');
end

function guard=temporary_path(folder)
    old=path; addpath(folder,'-begin');
    guard=onCleanup(@()path(old));
end

function pathName=normalize_path(pathName)
    pathName=lower(strrep(char(pathName),'/','\'));
end

function value=safe_field(s,name,fallback)
    if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
        value=s.(name);
        if isnumeric(value) && ~isscalar(value), value=value(end); end
    else
        value=fallback;
    end
end

function n=count_dynin_evaluations(OutL)
    n=NaN;
    if isstruct(OutL) && isfield(OutL,'x0') && ~isempty(OutL.x0)
        n=size(OutL.x0,1);
    elseif isstruct(OutL) && isfield(OutL,'R') && ~isempty(OutL.R)
        n=numel(OutL.R);
    end
end

function T=replace_or_append(T,row)
    new=struct2table(row,'AsArray',true);
    if isempty(T), T=new; return; end
    match=string(T.run_key)==string(row.run_key);
    T(match,:)=[]; T=[T;new]; %#ok<AGROW>
end

function value=median_finite(x)
    x=x(isfinite(x)); if isempty(x), value=NaN; else, value=median(x); end
end

function value=max_finite(x)
    x=x(isfinite(x)); if isempty(x), value=NaN; else, value=max(x); end
end

function value=percentile_finite(x,p)
    x=sort(x(isfinite(x)));
    if isempty(x), value=NaN; return; end
    if numel(x)==1, value=x; return; end
    q=1+(numel(x)-1)*p/100; lo=floor(q); hi=ceil(q);
    value=x(lo)+(q-lo)*(x(hi)-x(lo));
end

function atomic_write_table(T,pathName)
    [folder,name,~]=fileparts(pathName);
    temporary=fullfile(folder,[name '_writing.csv']);
    writetable(T,temporary,'FileType','text');
    movefile(temporary,pathName,'f');
end
