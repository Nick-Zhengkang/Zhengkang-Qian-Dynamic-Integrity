function outDir=run_experiment_C_anchored_GA(coverageDir,alphas,seeds,budget,resumeDir,prepareOnly)
% Paired original DynIn GA with frozen domains and equal initial search balls.
if nargin<2, alphas=[0.2 0.7 1]; end
if nargin<3, seeds=61:90; end
if nargin<4, budget=100; end
if nargin<5, resumeDir=''; end
if nargin<6, prepareOnly=false; end
validateattributes(alphas,{'numeric'},{'vector','positive','finite','nonempty'});
validateattributes(seeds,{'numeric'},{'vector','integer','positive','finite','nonempty','<=',99999});
validateattributes(budget,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(prepareOnly,{'logical'},{'scalar'});
alphas=reshape(alphas,1,[]); seeds=reshape(seeds,1,[]);
assert(numel(unique(alphas))==numel(alphas) && numel(unique(seeds))==numel(seeds));
here=fileparts(mfilename('fullpath'));
funcDir=fullfile(fileparts(here),'work','DynIn','DynIn_v1.1.0','functions');
modelDir=fullfile(here,'transfer_2d_model');
ga=struct('type_x0',1,'divR',40,'num_gen',5,'num_crossover',9, ...
    'selected_opt',3,'newcomers',8,'num_almost_clones',2,'automatic',1);
protocol=struct('version','anchored_GA_v1','coverageDir',char(coverageDir), ...
    'alphas',alphas,'seeds',seeds,'budget',budget,'ga',ga,'orderSeed',9242602, ...
    'primaryTolerance',0.02,'thresholds',[0.01 0.02 0.05], ...
    'reuses_prior_comparison_seeds',true,'classification_diagnostics_pass_claimed',false);
if isempty(resumeDir)
    outDir=fullfile(here,['outputs_anchored_GA_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
else
    outDir=char(resumeDir); assert(isfile(fullfile(outDir,'experiment.mat')),'Wrong resume root.');
end
files=dir(fullfile(funcDir,'*.m')); assert(~isempty(files),'DynIn functions not found.');
sources=[{fullfile(here,'run_experiment_C_anchored_GA.m'), ...
    fullfile(here,'experiment_C_search_domain_closure.m'),fullfile(here,'experiment_C_2d_reference.m')}, ...
    arrayfun(@(d)fullfile(d.folder,d.name),files,'UniformOutput',false)', ...
    {fullfile(modelDir,'sistema.m')}];
snapshot=fullfile(outDir,'source_snapshot'); file=fullfile(outDir,'experiment.mat');
if isfile(file)
    saved=load(file,'protocol','settings','audit','schedule');
    assert(isequaln(saved.protocol,protocol),'Restore original settings to resume.');
    snapshot_sources(sources,snapshot,true);
    settings=saved.settings; audit=saved.audit; schedule=saved.schedule;
else
    [settings,audit]=load_inputs(coverageDir,alphas);
    schedule=make_schedule(alphas,seeds,budget,protocol.orderSeed);
    snapshot_sources(sources,snapshot,false);
    state=struct('protocol',protocol,'settings',settings,'audit',audit,'schedule',schedule);
    atomic_save(file,state);
    for name=["coverage_decisions.csv","search_domain_audit.csv","summary_trajectory_coverage.csv"]
        copyfile(fullfile(coverageDir,char(name)),outDir);
    end
end
atomic_csv(audit,fullfile(outDir,'matched_settings_audit.csv'));
atomic_csv(schedule,fullfile(outDir,'randomized_schedule.csv'));
fprintf('\nRadius-preserving domain comparison: %d cases x 2 domains x %d seeds = %d runs.\n', ...
    numel(alphas),numel(seeds),height(schedule));
fprintf('Budget=%d; primary error threshold=2%%. Output:\n%s\n',budget,outDir);
if prepareOnly
    fprintf('Preparation passed. Set prepareOnly=false and resumeDir to this folder to run.\n');
    return
end
oldPath=path; oldRng=rng;
cleanupPath=onCleanup(@()path(oldPath)); cleanupRng=onCleanup(@()rng(oldRng));
restoredefaultpath;
addpath(fullfile(snapshot,'experiment'),fullfile(snapshot,'dynin'),fullfile(snapshot,'model'),'-begin');
assert(strcmpi(which('compute_LIM_FP'),fullfile(snapshot,'dynin','compute_LIM_FP.m')));
assert(strcmpi(which('sistema'),fullfile(snapshot,'model','sistema.m')));
referenceFile=fullfile(outDir,'reference_audit.csv');
if isfile(referenceFile)
    reference=readtable(referenceFile);
else
    rr=cell(numel(alphas),1);
    for i=1:numel(alphas)
        timer=tic; [R,residual]=experiment_C_2d_reference('bistable_duffing',alphas(i));
        rr{i}=struct('alpha',alphas(i),'reference_LIM',R,'residual',residual,'wall_s',toc(timer));
    end
    reference=struct2table(vertcat(rr{:})); atomic_csv(reference,referenceFile);
end
checkpointDir=fullfile(outDir,'run_checkpoints');
if ~isfolder(checkpointDir), mkdir(checkpointDir); end
rows=cell(height(schedule),1);
for i=1:height(schedule)
    s=table2struct(schedule(i,:)); checkpoint=fullfile(checkpointDir,char(s.run_key+".mat"));
    setting=settings([settings.alpha]==s.alpha & [settings.profile]==s.profile);
    assert(isscalar(setting));
    if isfile(checkpoint)
        saved=load(checkpoint,'row','history'); row=saved.row; history=saved.history;
        assert(row.run_key==s.run_key && row.algorithm_seed==s.algorithm_seed);
        fprintf('[run %d/%d] RESUME %s (%s)\n',i,height(schedule),s.run_key,row.status);
    else
        fprintf('[run %d/%d] START alpha=%g, %s, seed=%d\n',i,height(schedule),s.alpha,s.profile,s.seed);
        rng(s.algorithm_seed,'twister');
        ref=reference.reference_LIM(abs(reference.alpha-s.alpha)<1e-12); assert(isscalar(ref));
        [row,history]=execute_run(s,setting,ga,ref);
        atomic_save(checkpoint,struct('row',row,'history',history));
        fprintf('[run %d/%d] DONE R=%.8g, error=%.3f%%, wall=%.2fs, tipo3=%g, %s\n', ...
            i,height(schedule),row.R_hat,100*row.relative_error,row.wall_s,row.n_tipo3_iterations,row.status);
    end
    if ~isempty(history)
        atomic_csv(history,fullfile(checkpointDir,char(s.run_key+"_history.csv")));
    end
    rows{i}=row;
    atomic_csv(struct2table(vertcat(rows{1:i})),fullfile(outDir,'raw_data_all_runs.csv'));
end
raw=struct2table(vertcat(rows{:}));
[summary,paired,contrasts]=reports(raw,alphas,seeds);
atomic_csv(summary,fullfile(outDir,'summary_by_alpha_and_domain.csv'));
atomic_csv(paired,fullfile(outDir,'paired_contrasts_by_seed.csv'));
atomic_csv(contrasts,fullfile(outDir,'paired_contrast_summary.csv'));
fprintf('\nAnchored GA test finished.\nRaw: %s\nSummary: %s\nPaired contrasts: %s\n', ...
    fullfile(outDir,'raw_data_all_runs.csv'),fullfile(outDir,'summary_by_alpha_and_domain.csv'), ...
    fullfile(outDir,'paired_contrasts_by_seed.csv'));
if any(paired.pair_complete & ~paired.same_first_initial_point)
    warning('AnchoredGA:PairMismatch','Some completed pairs had different first initial points. Inspect paired contrasts.');
end
end

function [settings,audit]=load_inputs(root,alphas)
D=readtable(fullfile(root,'coverage_decisions.csv'),'TextType','string');
P=readtable(fullfile(root,'summary_trajectory_coverage.csv'),'TextType','string');
folders=dir(fullfile(root,'case_*')); ss=cell(0,1); aa=cell(0,1);
for a=alphas
    d=D(abs(D.alpha-a)<1e-12,:);
    assert(height(d)==1 && d.ready_for_next_controlled_GA==1 && d.trajectory_checks_run==1, ...
        'Coverage validation has not passed for alpha=%g.',a);
    point=P(abs(P.alpha-a)<1e-12 & P.profile=="anchored_search_energy",:);
    assert(height(point)==1 && point.all_probes_pass==1);
    hits=0;
    for k=1:numel(folders)
        folder=fullfile(folders(k).folder,folders(k).name);
        candidate=fullfile(folder,'anchored_search_energy','coverage_settings.mat');
        if ~isfile(candidate), continue; end
        C=load(candidate);
        if abs(C.g.alpha-a)>1e-12, continue; end
        O=load(fullfile(folder,'original_domain','coverage_settings.mat'));
        F=load(fullfile(folder,'frozen_inputs.mat'),'O','cfg');
        assert(isequaln(O.g,F.O.g) && isequaln(O.p,F.O.p),'Baseline snapshot mismatch.');
        cfg=F.cfg; hits=hits+1;
        % Require every non-geometric setting to match exactly.
        assert(isequaln(rmfield(O.g,'domain'),rmfield(C.g,'domain')),'Model fields differ.');
        assert(isequaln(rmfield(O.p,'discr'),rmfield(C.p,'discr')),'Classifier settings differ.');
        A=experiment_C_search_domain_closure('audit',O.g,O.p);
        B=experiment_C_search_domain_closure('audit',C.g,C.p);
        assert(B.exact_energy_envelope_covered && C.p.discr<=cfg.maximumGrid);
        assert(abs(A.initial_search_radius-B.initial_search_radius)<1e-12);
        assert(max(abs([A.hx A.hv]-[B.hx B.hv]))<1e-12);
        beltDiff=max(abs(target_belt(O.g,O.p)-target_belt(C.g,C.p)));
        assert(beltDiff<1e-10,'Physical target neighbourhood differs.');
        for id=["original_domain","anchored_search_energy"]
            S=O; if id=="anchored_search_energy", S=C; end
            ss{end+1,1}=struct('alpha',a,'profile',id,'g',S.g,'p',S.p,'cfg',cfg); %#ok<AGROW>
            au=experiment_C_search_domain_closure('audit',S.g,S.p);
            au.profile=id; au.target_belt_difference=beltDiff;
            au.k=S.p.k; au.Ts=S.p.Ts; au.tfinal=S.p.tfinal;
            au.rep_periodic=S.p.rep_periodic; au.rep_fix_point=cfg.repFixPoint;
            au.RelTol=cfg.relTol; au.AbsTol=cfg.absTol;
            aa{end+1,1}=au; %#ok<AGROW>
        end
    end
    assert(hits==1,'Missing or duplicate frozen case for alpha=%g.',a);
end
settings=vertcat(ss{:}); audit=struct2table(vertcat(aa{:}));
end

function b=target_belt(g,p)
h=(g.domain(3:4)-g.domain(1:2))/p.discr; c=zeros(1,2);
for j=1:2
    centers=g.domain(j)+((0:p.discr-1)+0.5)*h(j);
    [~,c(j)]=min(abs(centers-g.target(j)));
end
assert(mod(p.k,2)==1); half=(p.k-1)/2;
b=[g.domain(1:2)+(c-half-1).*h,g.domain(1:2)+(c+half).*h];
end

function T=make_schedule(alphas,seeds,budget,orderSeed)
rows=cell(0,1);
for a=alphas
    for seed=seeds
        for profile=["original_domain","anchored_search_energy"]
            key="alpha_"+replace(sprintf('%.6g',a),'.','p')+"_"+profile+sprintf('_seed%03d',seed);
            rows{end+1,1}=struct('alpha',a,'profile',profile,'seed',seed, ...
                'algorithm_seed',24680+round(a*1000)*100000+seed, ...
                'number_of_steps',budget,'run_key',key); %#ok<AGROW>
        end
    end
end
T=struct2table(vertcat(rows{:})); state=rng; guard=onCleanup(@()rng(state));
rng(orderSeed,'twister'); T=T(randperm(height(T)),:); T.execution_order=(1:height(T))';
end

function [r,H]=execute_run(s,setting,ga,Rref)
g=setting.g; p=setting.p; cfg=setting.cfg;
a=experiment_C_search_domain_closure('audit',g,p);
r=s; r.discr=p.discr; r.k=p.k; r.tfinal=p.tfinal; r.Ts=p.Ts;
r.initial_search_radius=a.initial_search_radius; r.search_energy_cap=a.search_energy_cap;
r.reference_LIM=Rref; r.R_hat=NaN; r.relative_error=NaN; r.signed_error=NaN;
r.wall_s=NaN; r.cpu_s=NaN; r.trajectory_evaluations=NaN;
r.n_tipo3_iterations=NaN; r.n_tipo2_after_automatic=NaN; r.horizon_exhausted_proxy=NaN;
r.first_x0_x=NaN; r.first_x0_v=NaN; r.max_initial_energy=NaN;
r.max_radius_excess=NaN; r.energy_cap_excess=NaN; r.tail_relative_change=NaN;
r.domain_coverage_violation=false; r.timing_review_flag=false;
r.started_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
r.finished_at=""; r.status="failed"; r.error_message=""; H=table();
r.estimated_allocation_GB=96*round(p.tfinal/p.Ts*s.number_of_steps/4)/1e9;
if r.estimated_allocation_GB>cfg.maximumEstimatedAllocationGB
    r.status="allocation_limit"; r.error_message="Original allocation estimate exceeds frozen resource limit.";
    r.finished_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS')); return
end
values={p.tfinal,p.Ts,g.weight,ga.type_x0,cfg.relTol,cfg.absTol,s.number_of_steps, ...
    p.k,1001,0,0,g.domain,p.discr,ga.automatic,1,2,cfg.repFixPoint,p.rep_periodic, ...
    0.005,0,0,10000,ga.divR,ga.num_gen,ga.num_crossover,ga.selected_opt, ...
    ga.newcomers,ga.num_almost_clones,5};
timer=tic; cpu0=cputime;
try
    [R,L]=compute_LIM_FP(g.target,struct('model',g.model,'alpha',g.alpha),values{:});
    r.wall_s=toc(timer); r.cpu_s=cputime-cpu0;
    r.R_hat=R; r.relative_error=abs(R-Rref)/Rref; r.signed_error=(R-Rref)/Rref;
    r.trajectory_evaluations=nnz(L.time_steps_sim>0);
    r.n_tipo3_iterations=nnz(L.tipo==3); r.n_tipo2_after_automatic=nnz(L.tipo==2);
    r.horizon_exhausted_proxy=nnz(L.time_steps_sim>=floor(p.tfinal/p.Ts));
    r.first_x0_x=L.x0(1,1); r.first_x0_v=L.x0(1,2);
    energy=0.5*L.x0(:,2).^2-0.5*L.x0(:,1).^2+0.25*L.x0(:,1).^4;
    radius=sqrt(sum((L.x0-g.target).^2.*g.weight,2));
    r.max_initial_energy=max(energy); r.energy_cap_excess=max(energy)-a.search_energy_cap;
    r.max_radius_excess=max(radius)-a.initial_search_radius;
    r.tail_relative_change=abs(L.R(floor(.8*s.number_of_steps)+1)-R)/max(abs(R),eps);
    r.domain_coverage_violation=setting.profile=="anchored_search_energy" && r.n_tipo3_iterations>0;
    if isfinite(R) && numel(L.tipo)==s.number_of_steps, r.status="ok"; else, r.status="invalid_output"; end
    if r.max_radius_excess>1e-10 || r.energy_cap_excess>1e-8 || abs(L.R(1)-a.initial_search_radius)>1e-12
        r.status="search_contract_violation";
        r.error_message="Observed queries or initial radius violate the frozen search assumptions.";
    end
    n=numel(L.tipo);
    H=table((1:n)',L.R(1:n),L.R(2:n+1),L.x0(:,1),L.x0(:,2),radius,energy,L.tipo(:), ...
        L.time_steps_sim(:),L.time_sim(:),L.time_x0(:), ...
        'VariableNames',{'iteration','R_before','R_after','x0','v0','radius','energy', ...
        'tipo_after_automatic','output_samples','integration_wall_s','GA_selection_wall_s'});
catch ME
    r.wall_s=toc(timer); r.cpu_s=cputime-cpu0; r.status="failed";
    r.error_message=string(getReport(ME,'basic','hyperlinks','off'));
end
r.finished_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
r.timing_review_flag=r.wall_s>30 && r.wall_s>5*max(r.cpu_s,1);
end

function [S,P,C]=reports(raw,alphas,seeds)
ss=cell(0,1); pp=cell(0,1); cc=cell(0,1);
for a=[alphas NaN]
    allAlpha=isnan(a);
    for id=["original_domain","anchored_search_energy"]
        g=raw((allAlpha | abs(raw.alpha-a)<1e-12) & raw.profile==id,:);
        ok=g.status=="ok" & isfinite(g.relative_error); e=sort(g.relative_error(ok));
        p95=NaN; if ~isempty(e), p95=e(ceil(.95*numel(e))); end
        ss{end+1,1}=struct('alpha',a,'profile',id,'n_runs',height(g),'n_completed',nnz(ok), ...
            'median_R_hat',median(g.R_hat(ok),'omitnan'),'median_relative_error',median(e,'omitnan'), ...
            'p95_relative_error',p95,'median_signed_error',median(g.signed_error(ok),'omitnan'), ...
            'within_1pct_rate',mean(ok & g.relative_error<=.01), ...
            'within_2pct_rate',mean(ok & g.relative_error<=.02), ...
            'within_5pct_rate',mean(ok & g.relative_error<=.05), ...
            'overestimate_gt2pct_count',nnz(ok & g.signed_error>.02), ...
            'median_wall_s',median(g.wall_s(ok),'omitnan'),'median_cpu_s',median(g.cpu_s(ok),'omitnan'), ...
            'total_tipo3_iterations',sum(g.n_tipo3_iterations(ok)), ...
            'runs_with_tipo3',nnz(ok & g.n_tipo3_iterations>0), ...
            'n_coverage_violation_runs',nnz(g.domain_coverage_violation), ...
            'n_timing_flags',nnz(g.timing_review_flag),'n_failed',nnz(~ok)); %#ok<AGROW>
    end
    if allAlpha, continue; end
    for seed=seeds
        O=raw(raw.alpha==a & raw.seed==seed & raw.profile=="original_domain",:);
        N=raw(raw.alpha==a & raw.seed==seed & raw.profile=="anchored_search_energy",:);
        assert(height(O)==1 && height(N)==1);
        pp{end+1,1}=struct('alpha',a,'seed',seed,'pair_complete',O.status=="ok" && N.status=="ok", ...
            'same_algorithm_seed',O.algorithm_seed==N.algorithm_seed, ...
            'same_first_initial_point',max(abs([O.first_x0_x O.first_x0_v]-[N.first_x0_x N.first_x0_v]))<1e-12, ...
            'original_R_hat',O.R_hat,'anchored_R_hat',N.R_hat, ...
            'original_error',O.relative_error,'anchored_error',N.relative_error, ...
            'error_change',N.relative_error-O.relative_error, ...
            'success_2pct_change',double(N.status=="ok" && N.relative_error<=.02)- ...
            double(O.status=="ok" && O.relative_error<=.02), ...
            'original_wall_s',O.wall_s,'anchored_wall_s',N.wall_s,'wall_ratio',N.wall_s/O.wall_s, ...
            'tipo3_change',N.n_tipo3_iterations-O.n_tipo3_iterations, ...
            'either_timing_flag',O.timing_review_flag || N.timing_review_flag); %#ok<AGROW>
    end
end
P=struct2table(vertcat(pp{:})); S=struct2table(vertcat(ss{:}));
for a=[alphas NaN]
    g=P(isnan(a) | abs(P.alpha-a)<1e-12,:); ok=g.pair_complete;
    cc{end+1,1}=struct('alpha',a,'n_pairs',height(g),'n_complete_pairs',nnz(ok), ...
        'n_same_first_initial_point',nnz(ok & g.same_first_initial_point), ...
        'n_error_improved',nnz(ok & g.error_change<0),'median_error_change',median(g.error_change(ok),'omitnan'), ...
        'success_2pct_net_change',sum(g.success_2pct_change), ...
        'median_wall_ratio',median(g.wall_ratio(ok),'omitnan'), ...
        'median_wall_ratio_without_flags',median(g.wall_ratio(ok & ~g.either_timing_flag),'omitnan'), ...
        'median_tipo3_change',median(g.tipo3_change(ok),'omitnan')); %#ok<AGROW>
end
C=struct2table(vertcat(cc{:}));
end

function snapshot_sources(files,root,verify)
for i=1:numel(files)
    src=files{i}; kind='experiment';
    if contains(src,[filesep 'functions' filesep]), kind='dynin'; end
    if contains(src,[filesep 'transfer_2d_model' filesep]), kind='model'; end
    folder=fullfile(root,kind); [~,name,ext]=fileparts(src); dest=fullfile(folder,[name ext]);
    if verify
        assert(isfile(dest) && strcmp(fileread(src),fileread(dest)),'Source changed: %s',src);
    else
        if ~isfolder(folder), mkdir(folder); end
        copyfile(src,dest);
    end
end
end

function atomic_csv(T,file)
[folder,name,ext]=fileparts(file); tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end

function atomic_save(file,data)
[folder,name,ext]=fileparts(file); tmp=fullfile(folder,[name '_writing' ext]);
save(tmp,'-struct','data'); movefile(tmp,file,'f');
end
