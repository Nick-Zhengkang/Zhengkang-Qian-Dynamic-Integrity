function outDir=run_experiment_C_domain_diagnostics(sourceDir,alphaValues,resumeDir)
% Paired domain-only diagnostics. No GA, analytic LIM, or changes to DynIn.
if nargin<2, alphaValues=[0.2 0.7 1]; end
if nargin<3, resumeDir=''; end
validateattributes(alphaValues,{'numeric'},{'vector','positive','finite','nonempty'});
alphaValues=reshape(alphaValues,1,[]);
assert(numel(unique(alphaValues))==numel(alphaValues));
here=fileparts(mfilename('fullpath'));
funcDir=fullfile(fileparts(here),'work','DynIn','DynIn_v1.1.0','functions');
modelDir=fullfile(here,'transfer_2d_model');
oldPath=path; guard=onCleanup(@()path(oldPath));
restoredefaultpath; addpath(here,funcDir,modelDir,'-begin');
assert(strcmpi(which('simulation_DI'),fullfile(funcDir,'simulation_DI.m')));
assert(strcmpi(which('sistema'),fullfile(modelDir,'sistema.m')));
manifest=experiment_C_domain_read_table(fullfile(sourceDir,'case_manifest.csv'), ...
    ["case_index","alpha","case_directory"],["case_index","alpha"]);
assert(height(manifest)>0,'Source manifest is empty.');
fprintf('Loaded %d source cases; alpha = %s\n',height(manifest), ...
    strjoin(string(manifest.alpha'),', '));
protocol=struct('version','domain_diagnostics_v1','sourceDir',char(sourceDir), ...
    'alphaValues',alphaValues,'marginFraction',0.05, ...
    'commonOriginalDomainPoints',true,'usesAnalyticLIM',false, ...
    'regressionNotFreshValidation',true);
if isempty(resumeDir)
    outDir=fullfile(here,['outputs_domain_diagnostics_' ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
else
    outDir=char(resumeDir);
    assert(isfile(fullfile(outDir,'domain_protocol.mat')),'Not a domain-diagnostic output root.');
end
names={'run_experiment_C_domain_diagnostics.m','experiment_C_domain_geometry.m', ...
    'experiment_C_domain_pilot.m','experiment_C_domain_read_table.m', ...
    'experiment_C_rule_diagnostics.m','experiment_C_rule_physics.m'};
paths=cellfun(@(n)fullfile(here,n),names,'UniformOutput',false);
files=dir(fullfile(funcDir,'*.m'));
paths=[paths,arrayfun(@(d)fullfile(d.folder,d.name),files,'UniformOutput',false)', ...
    {fullfile(modelDir,'sistema.m')}];
snapshot=fullfile(outDir,'source_snapshot');
if isfile(fullfile(outDir,'domain_protocol.mat'))
    old=load(fullfile(outDir,'domain_protocol.mat'),'protocol');
    assert(isequaln(old.protocol,protocol),'Resume settings changed.');
    verify(paths,snapshot);
else
    mkdir(snapshot);
    for j=1:numel(paths), copyfile(paths{j},snapshot); end
    save(fullfile(outDir,'domain_protocol.mat'),'protocol');
    copyfile(fullfile(here,'test_experiment_C_domain_diagnostics.m'),snapshot);
end
fprintf('\nDomain-only diagnostics, %d damping cases. No GA searches.\nOutput: %s\n', ...
    numel(alphaValues),outDir);
allResults=table(); allPoints=table(); allGeometry=table(); allDecisions=table();
for c=1:numel(alphaValues)
    a=alphaValues(c);
    ix=find(abs(manifest.alpha-a)<1e-12);
    assert(isscalar(ix),'Source does not uniquely identify alpha=%g.',a);
    src=char(manifest.case_directory(ix));
    folder=fullfile(outDir,sprintf('case_%02d',c));
    if ~isfolder(folder), mkdir(folder); end
    % Lock source inputs, while deliberately not reading reference_audit.csv.
    inputs={'physical_features.mat','run_configuration.mat','selected_parameters.csv', ...
        'calibration_truth.csv','holdout_truth.csv'};
    savedInputs=fullfile(folder,'input_snapshot');
    if ~isfolder(savedInputs), mkdir(savedInputs); end
    for j=1:numel(inputs)
        source=fullfile(src,inputs{j}); saved=fullfile(savedInputs,inputs{j});
        if isfile(saved)
            assert(isequal(read_bytes(source),read_bytes(saved)),'Source input changed: %s',source);
        else
            copyfile(source,saved);
        end
    end
    verify({fullfile(here,'experiment_C_rule_diagnostics.m'), ...
        fullfile(here,'experiment_C_rule_physics.m'),fullfile(funcDir,'simulation_DI.m'), ...
        fullfile(modelDir,'sistema.m')},fullfile(src,'source_snapshot'));
    saved=load(fullfile(savedInputs,'physical_features.mat'),'f'); f=saved.f;
    saved=load(fullfile(savedInputs,'run_configuration.mat'),'cfg'); cfg=saved.cfg;
    assert(f.model=="bistable_duffing" && abs(f.alpha-a)<1e-12 && isequal(f.target,[-1 0]));
    P=experiment_C_domain_read_table(fullfile(savedInputs,'selected_parameters.csv'), ...
        ["rule_id","discr","k","Ts","tfinal","rep_periodic"], ...
        ["discr","k","Ts","tfinal","rep_periodic"]);
    base=table2struct(P(string(P.rule_id)=="time_first",:));
    assert(isscalar(base),'Source time_first profile missing.');
    required=["point_id","kind","x0","v0","inside_domain","truth_label"];
    numeric=["point_id","x0","v0","inside_domain","truth_label"];
    D=experiment_C_domain_read_table(fullfile(savedInputs,'calibration_truth.csv'),required,numeric);
    H=experiment_C_domain_read_table(fullfile(savedInputs,'holdout_truth.csv'),required,numeric);
    % Freeze the original eligibility mask, even if padding admits more points.
    for T={D,H}
        actual=all([T{1}.x0 T{1}.v0]>f.domain(1:2) & ...
            [T{1}.x0 T{1}.v0]<f.domain(3:4),2);
        assert(isequal(actual,logical(T{1}.inside_domain)));
    end
    fprintf('\n[case %d/%d] alpha=%g, fixed T=%g, Ts=%.6g, k=%d\n', ...
        c,numel(alphaValues),a,base.tfinal,base.Ts,base.k);
    baseline=fullfile(folder,'original_domain');
    if ~isfolder(baseline), mkdir(baseline); end
    [B,~,~]=experiment_C_rule_diagnostics('classify',D,'calibration',base,f,cfg,baseline);
    trigger=B.n_domain_exit_false_unsafe>0;
    % Build both candidates from calibration only, before reading holdout results.
    Z=[D.x0(logical(D.inside_domain)) D.v0(logical(D.inside_domain))];
    E=0.5*Z(:,2).^2-0.5*Z(:,1).^2+0.25*Z(:,1).^4;
    Emax=max(E);
    energyB=experiment_C_domain_geometry('energy_bounds',Emax);
    [pilotB,pilot]=experiment_C_domain_pilot(D,f,base,cfg,folder);
    ids=["original_domain","energy_envelope","trajectory_envelope"];
    bounds={f.domain,energyB,pilotB};
    results=cell(0,1); geometry=cell(0,1); points=cell(0,1); decisions=cell(0,1);
    originalQueries=struct();
    for j=1:numel(ids)
        id=ids(j); pilotOK=j~=3 || all(isfinite(pilotB));
        if pilotOK
            margin=protocol.marginFraction;
            if j==1, margin=0; end
            [g,p,geo]=experiment_C_domain_geometry('pad',f,base,bounds{j},margin,cfg.maximumGrid);
        else
            [g,p,geo]=experiment_C_domain_geometry('pad',f,base,f.domain,0,cfg.maximumGrid);
        end
        geo.alpha=a; geo.profile=id; geo.energy_ceiling_calibration=Emax;
        geo.calibration_exit_trigger=trigger; geo.pilot_ok=pilotOK;
        geo.k=p.k; geo.tfinal=p.tfinal; geo.Ts=p.Ts;
        geometry{end+1,1}=geo; %#ok<AGROW>
        enabled=pilotOK && geo.within_grid_limit;
        status="evaluated";
        if ~pilotOK, status="pilot_failed";
        elseif ~geo.within_grid_limit, status="grid_limit"; end
        profileDir=fullfile(folder,char(id));
        if ~isfolder(profileDir), mkdir(profileDir); end
        save(fullfile(profileDir,'domain_settings.mat'),'g','p','geo','status');
        pass=true;
        for split=["calibration","holdout"]
            T=D; if split=="holdout", T=H; end
            known=logical(T.inside_domain) & ismember(T.truth_label,[1 2]);
            energies=0.5*T.v0.^2-0.5*T.x0.^2+0.25*T.x0.^4;
            if enabled
                [S,Q,~]=experiment_C_rule_diagnostics('classify',T,split,p,g,cfg,profileDir);
                if j==1
                    originalQ=Q; originalQueries.(char(split))=Q;
                else
                    originalQ=originalQueries.(char(split));
                end
                oldWrong=known & T.truth_label==1 & originalQ.raw_tipo==3;
                fixed=nnz(oldWrong & Q.predicted_label==1);
                remaining=nnz(oldWrong & Q.predicted_label==2);
                unresolved=nnz(oldWrong & Q.predicted_label==0);
                Q.profile=repmat(id,height(Q),1); Q.split=repmat(split,height(Q),1);
                Q.alpha=repmat(a,height(Q),1);
                Q.original_predicted_label=originalQ.predicted_label;
                Q.original_tipo=originalQ.raw_tipo;
                Q.actual_inside_candidate_domain=all([Q.x0 Q.v0]>g.domain(1:2) & ...
                    [Q.x0 Q.v0]<g.domain(3:4),2);
                points{end+1,1}=Q; %#ok<AGROW>
                nTarget=S.n_true_target; nNon=S.n_true_non_target;
                fs=S.false_safe_rate; fu=S.false_unsafe_rate; ur=S.unresolved_rate;
                exits=S.n_domain_exit_false_unsafe; wall=S.classifier_wall_s;
                passed=S.diagnostic_pass && exits==0;
            else
                nTarget=nnz(known & T.truth_label==1); nNon=nnz(known & T.truth_label==2);
                fs=NaN; fu=NaN; ur=NaN; exits=NaN; wall=NaN;
                fixed=NaN; remaining=NaN; unresolved=NaN; passed=false;
            end
            pass=pass && passed;
            results{end+1,1}=struct('alpha',a,'profile',id,'split',split,'status',status, ...
                'discr',p.discr,'k',p.k,'tfinal',p.tfinal,'Ts',p.Ts, ...
                'n_true_target',nTarget,'n_true_non_target',nNon, ...
                'false_safe_rate',fs,'false_unsafe_rate',fu,'unresolved_rate',ur, ...
                'domain_exit_false_unsafe',exits,'corrected_original_exit_errors',fixed, ...
                'original_exit_errors_still_non_target',remaining, ...
                'original_exit_errors_now_unresolved',unresolved, ...
                'n_points_above_calibration_energy',nnz(known & energies>Emax+1e-10), ...
                'classifier_wall_s',wall,'diagnostic_and_exit_check_pass',passed); %#ok<AGROW>
        end
        decision=struct('alpha',a,'profile',id,'calibration_exit_trigger',trigger, ...
            'both_regression_sets_pass',pass,'ready_for_separate_GA_design',pass && j>1, ...
            'fresh_independent_validation',false,'grid_limit',~geo.within_grid_limit);
        decisions{end+1,1}=decision; %#ok<AGROW>
        atomic_csv(struct2table(vertcat(results{:})),fullfile(folder,'summary_domain_diagnostics.csv'));
        atomic_csv(struct2table(vertcat(geometry{:})),fullfile(folder,'domain_geometry.csv'));
        atomic_csv(vertcat(points{:}),fullfile(folder,'pointwise_comparison.csv'));
        atomic_csv(struct2table(vertcat(decisions{:})),fullfile(folder,'domain_decisions.csv'));
        fprintf('[domain %d/3] %s: N=%d; status=%s; both sets pass=%d\n', ...
            j,id,p.discr,status,pass);
    end
    allResults=append(allResults,struct2table(vertcat(results{:})));
    allGeometry=append(allGeometry,struct2table(vertcat(geometry{:})));
    allPoints=append(allPoints,vertcat(points{:}));
    allDecisions=append(allDecisions,struct2table(vertcat(decisions{:})));
    atomic_csv(allResults,fullfile(outDir,'summary_domain_diagnostics.csv'));
    atomic_csv(allGeometry,fullfile(outDir,'domain_geometry.csv'));
    atomic_csv(allPoints,fullfile(outDir,'pointwise_comparison.csv'));
    atomic_csv(allDecisions,fullfile(outDir,'domain_decisions.csv'));
    costs=table(sum(pilot.wall_s),nnz(pilot.timing_review_flag), ...
        'VariableNames',{'pilot_wall_s','pilot_timing_review_flags'});
    atomic_csv(costs,fullfile(folder,'pilot_cost.csv'));
end
fprintf('\nDomain diagnostics finished.\nSummary: %s\nPoints: %s\n', ...
    fullfile(outDir,'summary_domain_diagnostics.csv'),fullfile(outDir,'pointwise_comparison.csv'));
end

function T=append(T,U)
if isempty(T), T=U; else, T=[T;U]; end
end

function verify(paths,snapshot)
for j=1:numel(paths)
    [~,stem,ext]=fileparts(paths{j}); other=fullfile(snapshot,[stem ext]);
    assert(isfile(other) && strcmp(fileread(paths{j}),fileread(other)), ...
        'Source differs from snapshot: %s',paths{j});
end
end

function b=read_bytes(file)
fid=fopen(file,'rb'); assert(fid>=0,'Cannot read %s',file);
guard=onCleanup(@()fclose(fid)); b=fread(fid,Inf,'*uint8');
end

function atomic_csv(T,file)
[folder,stem,ext]=fileparts(file); tmp=fullfile(folder,[stem '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end
