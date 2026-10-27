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
function outDir=run_experiment_C_cosine_transfer(alpha,seeds,budget,mode,resumeDir)
% Frozen GA, physics-generated classifier, independent diagnostic holdout.
if nargin<1, alpha=0.05; end
if nargin<2, seeds=91:120; end
if nargin<3, budget=100; end
if nargin<4, mode='full'; end
if nargin<5, resumeDir=''; end
mode=validatestring(mode,{'prepare','diagnostics','full'});
validateattributes(seeds,{'numeric'},{'vector','positive','integer','finite','nonempty','<=',99999});
validateattributes(budget,{'numeric'},{'scalar','integer','positive','finite'});
seeds=reshape(seeds,1,[]); assert(numel(unique(seeds))==numel(seeds));
here=fileparts(mfilename('fullpath')); root=fileparts(here);
funcDir=fullfile(root,'work','DynIn','DynIn_v1.1.0','functions');
[f,p,historical,cfg,audit]=experiment_C_cosine_settings(alpha);
protocol=struct('version','cosine_transfer_v1','alpha',alpha,'seeds',seeds, ...
    'budget',budget,'orderSeed',9242603,'primaryTolerance',0.02, ...
    'referenceUsedForTuning',false,'cfg',cfg);
if isempty(resumeDir)
    outDir=fullfile(here,['outputs_cosine_transfer_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
else
    outDir=char(resumeDir); assert(isfile(fullfile(outDir,'protocol.mat')),'Invalid resume directory.');
end
snap=fullfile(outDir,'source_snapshot'); file=fullfile(outDir,'protocol.mat');
verify=isfile(file);
if verify
    old=load(file); assert(isequaln(old.protocol,protocol),'Resume settings have changed.');
    assert(isequaln(old.f,f) && isequaln(old.p,p) && isequaln(old.historical,historical));
end
snapshot(here,funcDir,root,snap,verify);
if ~verify, atomic_save(file,struct('protocol',protocol,'f',f,'p',p,'historical',historical)); end
csv(struct2table(audit),fullfile(outDir,'physics_initial_settings.csv'));
fprintf('\nCosine transfer: alpha=%g, %d paired seeds, %d GA runs, N=%d.\n',alpha,numel(seeds),2*numel(seeds),budget);
fprintf('Output directory:\n%s\n',outDir);
fprintf('Initial rule: grid=%d, target cells=%d, Ts=%.6g, tfinal=%g, R0=pi.\n',p.discr,p.k,p.Ts,p.tfinal);
if strcmp(mode,'prepare'), return; end
oldPath=path; oldRng=rng;
pathGuard=onCleanup(@()path(oldPath)); rngGuard=onCleanup(@()rng(oldRng));
restoredefaultpath;
addpath(fullfile(snap,'experiment'),fullfile(snap,'dynin'),fullfile(snap,'model'),fullfile(snap,'reference'),'-begin');
assert(strcmpi(which('compute_LIM_FP'),fullfile(snap,'dynin','compute_LIM_FP.m')));
assert(strcmpi(which('sistema'),fullfile(snap,'model','sistema.m')));
prepTimer=tic;
freezeFile=fullfile(outDir,'frozen_classifier.mat');
if isfile(freezeFile)
    F=load(freezeFile,'settings'); settings=F.settings;
else
    % Scale diagnostic points to the ENTIRE allowed initial GA ball, not an
    % ellipse that misses its high-velocity tips. Physics scales stay in f.
    probes=f; probes.Lx=pi; probes.Lv=pi;
    calibration=experiment_C_rule_diagnostics('dataset','calibration',probes,cfg,outDir);
    assert(all(hypot(calibration.x0,calibration.v0)<pi) && all(calibration.inside_domain));
    [p,verified,decisions]=calibrate(calibration,f,p,cfg,budget,outDir);
    csv(decisions,fullfile(outDir,'calibration_decisions.csv'));
    atomic_save(fullfile(outDir,'calibration_candidate.mat'),struct('p',p,'verified',verified));
    if ~verified
        diagnostic_costs(outDir);
        csv(table(false,"calibration_not_verified",'VariableNames',{'ready_for_GA','reason'}),fullfile(outDir,'decision.csv'));
        warning('CosineTransfer:Calibration','Calibration not verified. No GA started; inspect calibration_decisions.csv.');
        return
    end
    % Fresh directions/radii. Holdout results NEVER alter the candidate.
    fresh=experiment_C_rule_diagnostics('dataset','holdout',probes,cfg,outDir);
    [holdout,Q]=experiment_C_rule_diagnostics('classify',fresh,'physics_holdout',p,f,cfg,outDir);
    csv(Q,fullfile(outDir,'independent_pointwise_validation.csv'));
    csv(struct2table(holdout),fullfile(outDir,'independent_validation_summary.csv'));
    if ~holdout.diagnostic_pass
        diagnostic_costs(outDir);
        csv(table(false,"independent_validation_failed",'VariableNames',{'ready_for_GA','reason'}),fullfile(outDir,'decision.csv'));
        warning('CosineTransfer:Holdout','Independent validation failed. Do not retune on these holdout points; no GA started.');
        return
    end
    oldF=f; oldF.domain=historical.domain;
    oldP=p; oldP.discr=historical.discr; oldP.k=historical.k;
    oldP.Ts=historical.Ts; oldP.tfinal=historical.tfinal; oldP.rep_periodic=historical.rep_periodic;
    oldCfg=cfg; oldCfg.relTol=historical.relTol; oldCfg.absTol=historical.absTol;
    [hs,HQ]=experiment_C_rule_diagnostics('classify',fresh,'historical_holdout',oldP,oldF,oldCfg,outDir);
    csv(struct2table(hs),fullfile(outDir,'historical_validation_summary.csv'));
    csv(HQ,fullfile(outDir,'historical_pointwise_validation.csv'));
    settings=[struct('profile',"historical_cosine",'f',oldF,'p',oldP,'cfg',oldCfg), ...
        struct('profile',"physics_rule",'f',f,'p',p,'cfg',cfg)];
    atomic_save(freezeFile,struct('p',p,'settings',settings,'holdout',holdout));
end
csv(table(true,"frozen_after_independent_validation",'VariableNames',{'ready_for_GA','reason'}),fullfile(outDir,'decision.csv'));
auditRows=cell(2,1);
for j=1:2
    s=settings(j); h=(s.f.domain(3:4)-s.f.domain(1:2))/s.p.discr;
    auditRows{j}=struct('profile',s.profile,'xmin',s.f.domain(1),'vmin',s.f.domain(2), ...
        'xmax',s.f.domain(3),'vmax',s.f.domain(4),'discr',s.p.discr,'hx',h(1),'hv',h(2), ...
        'target_cells',s.p.k,'tfinal',s.p.tfinal,'Ts',s.p.Ts, ...
        'rep_fix_point',s.cfg.repFixPoint,'rep_periodic',s.p.rep_periodic, ...
        'RelTol',s.cfg.relTol,'AbsTol',s.cfg.absTol,'initial_R',pi, ...
        'type_x0',1,'divR',40,'num_gen',5,'num_crossover',9,'selected_opt',3, ...
        'newcomers',8,'num_almost_clones',2,'number_of_steps',budget);
end
csv(struct2table(vertcat(auditRows{:})),fullfile(outDir,'frozen_settings.csv'));
diagnostic_costs(outDir);
preparation_seconds=toc(prepTimer);
sessionFile=fullfile(outDir,['session_cost_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '.csv']);
csv(table(preparation_seconds),sessionFile);
if strcmp(mode,'diagnostics')
    fprintf('Diagnostics passed and configuration frozen. Use mode=full with this resumeDir for GA.\n'); return
end
% Analytical reference is evaluated ONLY after all parameter choices freeze.
refFile=fullfile(outDir,'reference_audit.csv');
if isfile(refFile)
    ref=readtable(refFile,'TextType','string'); Rref=ref.reference_LIM(1);
else
    [r,ref]=fourbench.reference('genda_cosine_quadratic_drag',alpha);
    ref.reference_kind=string(r.kind); ref.reference_source=string(r.source);
    ref.reference_wall_s=r.runtime; Rref=r.R; csv(ref,refFile);
end
schedule=make_schedule(seeds,budget,protocol.orderSeed);
csv(schedule,fullfile(outDir,'randomized_schedule.csv'));
ck=fullfile(outDir,'run_checkpoints'); if ~isfolder(ck), mkdir(ck); end
% One untimed warm-up per invocation; seeds for recorded runs are reset below.
warm=schedule(1,:); warm.number_of_steps=3; rng(19242603,'twister');
timer=tic; [wr,~]=execute(table2struct(warm),settings(1),Rref);
warmup_seconds=toc(timer);
assert(wr.status=="ok",'Warm-up failed: %s',wr.error_message);
csv(table(preparation_seconds,warmup_seconds),sessionFile);
rows=cell(height(schedule),1);
for i=1:height(schedule)
    s=table2struct(schedule(i,:)); checkpoint=fullfile(ck,char(s.run_key+".mat"));
    if isfile(checkpoint)
        saved=load(checkpoint,'row','history'); row=saved.row; history=saved.history;
        assert(row.run_key==s.run_key && row.algorithm_seed==s.algorithm_seed);
        fprintf('[run %d/%d] RESUME %s (%s)\n',i,height(schedule),s.run_key,row.status);
    else
        fprintf('[run %d/%d] START %s, seed=%d\n',i,height(schedule),s.profile,s.seed);
        rng(s.algorithm_seed,'twister'); setting=settings([settings.profile]==s.profile);
        [row,history]=execute(s,setting,Rref);
        atomic_save(checkpoint,struct('row',row,'history',history));
        fprintf('[run %d/%d] DONE R=%.8f, error=%.3f%%, wall=%.2fs, %s\n', ...
            i,height(schedule),row.R_hat,100*row.relative_error,row.wall_s,row.status);
    end
    if ~isempty(history), csv(history,fullfile(ck,char(s.run_key+"_history.csv"))); end
    rows{i}=row; csv(struct2table(vertcat(rows{1:i})),fullfile(outDir,'raw_data_all_runs.csv'));
end
raw=struct2table(vertcat(rows{:})); [summary,paired]=reports(raw,seeds);
csv(summary,fullfile(outDir,'summary_by_profile.csv'));
csv(paired,fullfile(outDir,'paired_contrasts_by_seed.csv'));
fprintf('\nCosine transfer finished.\nRaw: %s\nSummary: %s\n', ...
    fullfile(outDir,'raw_data_all_runs.csv'),fullfile(outDir,'summary_by_profile.csv'));
end

function [p,verified,T]=calibrate(D,f,p,cfg,budget,root)
rows=cell(0,1); verified=false;
% Recheck preceding blocks after a later change. rep_periodic stays frozen.
for pass=1:cfg.maxCombinedPasses+1
    start=p; allVerified=true;
    for block=["time","sampling","grid"]
        blockVerified=false;
        for attempt=0:cfg.maxRefinements
            q=p;
            if block=="time", q.tfinal=2*p.tfinal;
            elseif block=="sampling", q.Ts=p.Ts/2;
            else
                nextGrid=min(2*p.discr-1,cfg.maximumGrid);
                if nextGrid<=p.discr, break; end
                [q,gridOK]=experiment_C_rule_physics('regrid',q,nextGrid,f,cfg);
                if ~gridOK, break; end
            end
            if q.tfinal>cfg.maximumTime || q.Ts<cfg.minimumTs || ...
                    96*round(q.tfinal/q.Ts*budget/4)/1e9>cfg.maximumEstimatedAllocationGB
                break
            end
            fprintf('[calibration pass %d / %s / check %d] T=%g, Ts=%.6g, grid=%d, cells=%d\n', ...
                pass,block,attempt+1,p.tfinal,p.Ts,p.discr,p.k);
            [A,QA]=experiment_C_rule_diagnostics('classify',D,'calibration',p,f,cfg,root);
            [B,QB]=experiment_C_rule_diagnostics('classify',D,'calibration',q,f,cfg,root);
            [action,blockVerified,changeRate,pathChange]=experiment_C_rule_decision(A,B,QA,QB,cfg,char(block));
            rows{end+1,1}=struct('pass',pass,'block',block,'check',attempt+1, ...
                'old_T',p.tfinal,'candidate_T',q.tfinal,'old_Ts',p.Ts,'candidate_Ts',q.Ts, ...
                'old_grid',p.discr,'candidate_grid',q.discr,'old_cells',p.k,'candidate_cells',q.k, ...
                'old_false_safe',A.n_false_safe,'candidate_false_safe',B.n_false_safe, ...
                'old_false_unsafe',A.n_false_unsafe,'candidate_false_unsafe',B.n_false_unsafe, ...
                'old_unresolved',A.n_unresolved,'candidate_unresolved',B.n_unresolved, ...
                'label_change',changeRate,'path_distance_change',pathChange, ...
                'old_pass',A.diagnostic_pass,'candidate_pass',B.diagnostic_pass, ...
                'verified',blockVerified,'action',action); %#ok<AGROW>
            csv(struct2table(vertcat(rows{:})),fullfile(root,'calibration_decisions.csv'));
            if blockVerified, break; end
            if action=="adopt_and_recheck", p=q; else, break; end
        end
        allVerified=allVerified && blockVerified;
    end
    if allVerified && isequaln(start,p), verified=true; break; end
    if isequaln(start,p), break; end
end
T=struct2table(vertcat(rows{:}));
end

function T=make_schedule(seeds,budget,orderSeed)
rr=cell(0,1);
for seed=seeds
    for profile=["historical_cosine","physics_rule"]
        rr{end+1,1}=struct('alpha',0.05,'profile',profile,'seed',seed, ...
            'algorithm_seed',5024680+seed,'number_of_steps',budget, ...
            'run_key',profile+sprintf('_seed%03d',seed)); %#ok<AGROW>
    end
end
T=struct2table(vertcat(rr{:})); old=rng; guard=onCleanup(@()rng(old));
rng(orderSeed,'twister'); T=T(randperm(height(T)),:); T.execution_order=(1:height(T))';
end

function [r,H]=execute(s,S,Rref)
f=S.f; p=S.p; cfg=S.cfg; r=s; H=table();
r.discr=p.discr; r.k=p.k; r.Ts=p.Ts; r.tfinal=p.tfinal;
r.reference_LIM=Rref; r.R_hat=NaN; r.relative_error=NaN; r.signed_error=NaN;
r.wall_s=NaN; r.cpu_s=NaN; r.trajectory_evaluations=NaN;
r.n_tipo3_iterations=NaN; r.n_tipo2_after_automatic=NaN; r.horizon_exhausted_proxy=NaN;
r.first_x0_x=NaN; r.first_x0_v=NaN; r.max_radius_excess=NaN; r.energy_cap_excess=NaN;
r.tail_relative_change=NaN; r.timing_review_flag=false; r.status="failed"; r.error_message="";
r.estimated_allocation_GB=96*round(p.tfinal/p.Ts*s.number_of_steps/4)/1e9;
if r.estimated_allocation_GB>cfg.maximumEstimatedAllocationGB
    r.status="allocation_limit"; r.error_message="Original allocation exceeds the resource limit."; return
end
values={p.tfinal,p.Ts,f.weight,1,cfg.relTol,cfg.absTol,s.number_of_steps, ...
    p.k,1001,0,0,f.domain,p.discr,1,1,2,cfg.repFixPoint,p.rep_periodic, ...
    0.005,0,0,10000,40,5,9,3,8,2,5};
timer=tic; cpu0=cputime;
try
    [R,L]=compute_LIM_FP(f.target,struct('model',f.model,'alpha',f.alpha),values{:});
    r.wall_s=toc(timer); r.cpu_s=cputime-cpu0;
    r.R_hat=R; r.relative_error=abs(R-Rref)/Rref; r.signed_error=(R-Rref)/Rref;
    r.trajectory_evaluations=nnz(L.time_steps_sim>0);
    r.n_tipo3_iterations=nnz(L.tipo==3); r.n_tipo2_after_automatic=nnz(L.tipo==2);
    r.horizon_exhausted_proxy=nnz(L.time_steps_sim>=floor(p.tfinal/p.Ts));
    r.first_x0_x=L.x0(1,1); r.first_x0_v=L.x0(1,2);
    radius=hypot(L.x0(:,1),L.x0(:,2)); energy=.5*L.x0(:,2).^2+1-cos(L.x0(:,1));
    r.max_radius_excess=max(radius)-pi; r.energy_cap_excess=max(energy)-pi^2/2;
    r.tail_relative_change=abs(L.R(floor(.8*s.number_of_steps)+1)-R)/max(abs(R),eps);
    r.status="ok";
    if ~isfinite(R) || numel(L.tipo)~=s.number_of_steps, r.status="invalid_output"; end
    if r.max_radius_excess>1e-10 || r.energy_cap_excess>1e-8 || abs(L.R(1)-pi)>1e-10
        r.status="search_contract_violation";
    end
    n=numel(L.tipo);
    H=table((1:n)',L.R(1:n),L.R(2:n+1),L.x0(:,1),L.x0(:,2),radius,energy,L.tipo(:), ...
        L.time_steps_sim(:),L.time_sim(:),L.time_x0(:),'VariableNames', ...
        {'iteration','R_before','R_after','x0','v0','radius','energy','tipo_after_automatic', ...
        'output_samples','integration_wall_s','GA_selection_wall_s'});
catch ME
    r.wall_s=toc(timer); r.cpu_s=cputime-cpu0; r.status="failed";
    r.error_message=string(getReport(ME,'basic','hyperlinks','off'));
end
r.timing_review_flag=r.wall_s>30 && r.wall_s>5*max(r.cpu_s,1);
end

function [S,P]=reports(raw,seeds)
ss=cell(0,1); pp=cell(0,1);
for profile=["historical_cosine","physics_rule"]
    g=raw(raw.profile==profile,:); ok=g.status=="ok" & isfinite(g.relative_error);
    e=sort(g.relative_error(ok)); p95=NaN; if ~isempty(e), p95=e(ceil(.95*numel(e))); end
    ss{end+1,1}=struct('profile',profile,'n_runs',height(g),'n_completed',nnz(ok), ...
        'median_R_hat',median(g.R_hat(ok),'omitnan'),'median_relative_error',median(e,'omitnan'), ...
        'p95_relative_error',p95,'median_signed_error',median(g.signed_error(ok),'omitnan'), ...
        'within_1pct_rate',mean(ok & g.relative_error<=.01), ...
        'within_2pct_rate',mean(ok & g.relative_error<=.02), ...
        'within_5pct_rate',mean(ok & g.relative_error<=.05), ...
        'median_wall_s',median(g.wall_s(ok),'omitnan'),'median_cpu_s',median(g.cpu_s(ok),'omitnan'), ...
        'total_tipo3_iterations',sum(g.n_tipo3_iterations(ok)), ...
        'horizon_exhausted_proxy',sum(g.horizon_exhausted_proxy(ok)), ...
        'n_timing_flags',nnz(g.timing_review_flag),'n_failed',nnz(~ok)); %#ok<AGROW>
end
for seed=seeds
    A=raw(raw.seed==seed & raw.profile=="historical_cosine",:);
    B=raw(raw.seed==seed & raw.profile=="physics_rule",:);
    pp{end+1,1}=struct('seed',seed,'pair_complete',A.status=="ok" && B.status=="ok", ...
        'same_first_initial_point',max(abs([A.first_x0_x A.first_x0_v]-[B.first_x0_x B.first_x0_v]))<1e-12, ...
        'historical_R_hat',A.R_hat,'physics_R_hat',B.R_hat, ...
        'historical_error',A.relative_error,'physics_error',B.relative_error, ...
        'error_change',B.relative_error-A.relative_error,'wall_ratio',B.wall_s/A.wall_s, ...
        'either_timing_flag',A.timing_review_flag || B.timing_review_flag); %#ok<AGROW>
end
S=struct2table(vertcat(ss{:})); P=struct2table(vertcat(pp{:}));
end

function diagnostic_costs(root)
% Sum unique checkpoint measurements, not repeated cache reads on resumption.
rr=cell(0,1);
for split=["calibration","holdout"]
    file=fullfile(root,char(split+"_truth.csv"));
    if ~isfile(file), continue; end
    Q=readtable(file,'TextType','string');
    rr{end+1,1}=struct('stage',split+"_oracle",'n_point_evaluations',height(Q), ...
        'wall_s',sum(Q.truth_wall_s)); %#ok<AGROW>
end
files=dir(fullfile(root,'classifier_cache','*.csv'));
for i=1:numel(files)
    Q=readtable(fullfile(files(i).folder,files(i).name),'TextType','string');
    rr{end+1,1}=struct('stage',string(files(i).name),'n_point_evaluations',height(Q), ...
        'wall_s',sum(Q.classifier_wall_s)); %#ok<AGROW>
end
if ~isempty(rr), csv(struct2table(vertcat(rr{:})),fullfile(root,'diagnostic_costs.csv')); end
end

function snapshot(here,funcDir,root,dest,verify)
names={'run_experiment_C_cosine_transfer.m','experiment_C_cosine_settings.m', ...
    'experiment_C_rule_defaults.m','experiment_C_rule_physics.m','experiment_C_rule_diagnostics.m', ...
    'experiment_C_rule_decision.m'};
for i=1:numel(names), copy_checked(fullfile(here,names{i}),fullfile(dest,'experiment',names{i}),verify); end
files=dir(fullfile(funcDir,'*.m')); assert(~isempty(files),'Original DynIn functions missing.');
for i=1:numel(files), copy_checked(fullfile(files(i).folder,files(i).name),fullfile(dest,'dynin',files(i).name),verify); end
copy_checked(fullfile(here,'transfer_2d_model','sistema.m'),fullfile(dest,'model','sistema.m'),verify);
copy_checked(fullfile(root,'four_model_five_method_suite','functions','+fourbench','reference.m'), ...
    fullfile(dest,'reference','+fourbench','reference.m'),verify);
end

function copy_checked(src,dst,verify)
if verify
    assert(isfile(dst) && strcmp(fileread(src),fileread(dst)),'Source changed since start: %s',src);
else
    folder=fileparts(dst); if ~isfolder(folder), mkdir(folder); end
    copyfile(src,dst);
end
end

function csv(T,file)
[folder,name,ext]=fileparts(file); tmp=fullfile(folder,[name '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end

function atomic_save(file,data)
[folder,name,ext]=fileparts(file); tmp=fullfile(folder,[name '_writing' ext]);
save(tmp,'-struct','data'); movefile(tmp,file,'f');
end
