function outDir=run_experiment_C_duffing_transfer(mode,alphaValues,resumeDir)
% Reuse the tested rule runner without altering its source or past snapshots.
% The 2% evaluation protocol is saved before any diagnostics or LIM runs.
if nargin<1, mode='develop'; end
if nargin<2, alphaValues=[0.2 0.7 1.0]; end
if nargin<3, resumeDir=''; end
mode=validatestring(char(mode),{'smoke','develop','confirm'});
validateattributes(alphaValues,{'numeric'},{'vector','positive','finite','real','nonempty'});
alphaValues=reshape(alphaValues,1,[]);
assert(numel(unique(alphaValues))==numel(alphaValues),'Duplicate damping cases.');
here=fileparts(mfilename('fullpath'));
cfg=experiment_C_rule_defaults(mode);
% Keep the inherited 1%-named child reports truthful. The suite-level protocol
% below sets 2% for evaluation only, independently of all calibration decisions.
assert(cfg.targetRelativeError==0.01,'Inherited reports assume literal 1 percent.');
protocol=struct('version','duffing_transfer_v1','model','bistable_duffing', ...
    'mode',mode,'alphaValues',alphaValues,'cfg',cfg, ...
    'primaryTolerance',0.02,'reportedTolerances',[0.01 0.02 0.05], ...
    'requiredSuccessRate',0.90,'referenceUsedForTuning',false);
if isempty(resumeDir)
    outDir=fullfile(here,['outputs_duffing_transfer_' ...
        char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir);
else
    outDir=char(resumeDir);
    assert(isfile(fullfile(outDir,'transfer_protocol.mat')), ...
        'Use this suite''s root directory, not an older followup output or a case subdirectory.');
end
configFile=fullfile(outDir,'transfer_protocol.mat');
names={'run_experiment_C_duffing_transfer.m','experiment_C_transfer_metrics.m', ...
    'run_experiment_C_rule_followup.m','experiment_C_followup_plan.m', ...
    'experiment_C_rule_defaults.m','experiment_C_rule_physics.m', ...
    'experiment_C_rule_diagnostics.m','experiment_C_rule_decision.m', ...
    'estimate_dynin_parameters_from_physics.m','experiment_C_2d_reference.m'};
paths=cellfun(@(n)fullfile(here,n),names,'UniformOutput',false);
funcDir=fullfile(fileparts(here),'work','DynIn','DynIn_v1.1.0','functions');
files=dir(fullfile(funcDir,'*.m'));
assert(~isempty(files),'Original DynIn functions not found.');
paths=[paths,arrayfun(@(d)fullfile(d.folder,d.name),files,'UniformOutput',false)', ...
    {fullfile(here,'transfer_2d_model','sistema.m')}];
snapshot=fullfile(outDir,'source_snapshot');
if isfile(configFile)
    saved=load(configFile,'protocol');
    assert(isequaln(saved.protocol,protocol),'Resume mode, damping list or protocol changed.');
    for i=1:numel(paths)
        [~,stem,ext]=fileparts(paths{i}); prior=fullfile(snapshot,[stem ext]);
        assert(isfile(prior) && strcmp(fileread(prior),fileread(paths{i})), ...
            'Source changed since this suite started: %s',paths{i});
    end
else
    save(configFile,'protocol');
    mkdir(snapshot);
    for i=1:numel(paths), copyfile(paths{i},snapshot); end
    copyfile(fullfile(here,'test_experiment_C_duffing_transfer.m'),snapshot);
    settings=table(0.02,0.01,0.02,0.05,0.90,string(mode), ...
        'VariableNames',{'primary_tolerance','strict_tolerance','main_tolerance', ...
        'relaxed_tolerance','required_success_rate','mode'});
    atomic_csv(settings,fullfile(outDir,'evaluation_protocol.csv'));
end
fprintf('\nBistable Duffing transfer: x'''' + alpha*abs(x'')*x'' - x + x^3 = 0\n');
fprintf('Target=(-1,0); W=I; original DynIn GA type_x0=1.\n');
fprintf('Main accuracy threshold: 2%%; also report 1%% and 5%%.\n');
fprintf('%d cases x 5 profiles x %d seeds = %d GA runs, plus classifier diagnostics.\n', ...
    numel(alphaValues),numel(cfg.seeds),5*numel(alphaValues)*numel(cfg.seeds));
fprintf('Output directory:\n%s\n',outDir);
combinedRaw=table(); combinedSummary=table(); combinedContrasts=table();
caseRows=cell(0,1);
for i=1:numel(alphaValues)
    alpha=alphaValues(i);
    caseDir=fullfile(outDir,sprintf('case_%02d',i));
    if ~isfolder(caseDir), mkdir(caseDir); end
    fprintf('\n[case %d/%d] alpha=%.6g; settings are regenerated from this model.\n', ...
        i,numel(alphaValues),alpha);
    % A deterministic child directory allows recovery even before the first
    % long call returns. The child owns per-point and per-GA checkpoints.
    run_experiment_C_rule_followup('transfer','bistable_duffing',alpha,cfg,'',caseDir);
    raw=readtable(fullfile(caseDir,'raw_data_all_runs.csv'),'TextType','string');
    legacy=readtable(fullfile(caseDir,'summary_by_profile_and_budget.csv'),'TextType','string');
    expected=5*numel(cfg.seeds);
    assert(height(raw)==expected && height(legacy)==5,'Incomplete case output.');
    [R,S]=experiment_C_transfer_metrics(raw,legacy,'bistable_duffing',alpha, ...
        protocol.primaryTolerance,protocol.requiredSuccessRate);
    R.case_index=repmat(i,height(R),1); S.case_index=repmat(i,height(S),1);
    R.suite_run_key="case_"+string(i)+"_"+string(R.run_key);
    C=readtable(fullfile(caseDir,'paired_contrast_summary.csv'),'TextType','string');
    C.model=repmat("bistable_duffing",height(C),1);
    C.alpha=repmat(alpha,height(C),1); C.case_index=repmat(i,height(C),1);
    atomic_csv(R,fullfile(caseDir,'raw_transfer_scored.csv'));
    atomic_csv(S,fullfile(caseDir,'summary_transfer_thresholds.csv'));
    if isempty(combinedRaw)
        combinedRaw=R; combinedSummary=S; combinedContrasts=C;
    else
        combinedRaw=[combinedRaw;R]; %#ok<AGROW>
        combinedSummary=[combinedSummary;S]; %#ok<AGROW>
        combinedContrasts=[combinedContrasts;C]; %#ok<AGROW>
    end
    frozen=load(fullfile(caseDir,'frozen_time_first.mat'),'frozen');
    caseRows{end+1,1}=struct('case_index',i,'alpha',alpha,'case_directory',string(caseDir), ...
        'n_runs',height(R),'n_completed',nnz(string(R.status)=="ok"), ...
        'time_first_classifier_eligible',frozen.frozen.eligible, ...
        'n_timing_review_flags',nnz(R.timing_review_flag)); %#ok<AGROW>
    atomic_csv(combinedRaw,fullfile(outDir,'raw_data_all_runs.csv'));
    atomic_csv(combinedSummary,fullfile(outDir,'summary_transfer_thresholds.csv'));
    atomic_csv(combinedContrasts,fullfile(outDir,'paired_contrast_summary.csv'));
    atomic_csv(struct2table(vertcat(caseRows{:})),fullfile(outDir,'case_manifest.csv'));
    fprintf('[case %d/%d] COMPLETE. Success counts at 1%% / 2%% / 5%%:\n',i,numel(alphaValues));
    for j=1:height(S)
        fprintf('  %-16s %d/%d | %d/%d | %d/%d ; holdout=%d ; stability=%d\n', ...
            string(S.rule_id(j)),round(S.within_1pct_rate(j)*S.n_runs(j)),S.n_runs(j), ...
            round(S.within_2pct_rate(j)*S.n_runs(j)),S.n_runs(j), ...
            round(S.within_5pct_rate(j)*S.n_runs(j)),S.n_runs(j), ...
            S.holdout_pass(j),S.verification_pass(j));
    end
end
fprintf('\nDuffing transfer finished.\nRaw: %s\nSummary: %s\n', ...
    fullfile(outDir,'raw_data_all_runs.csv'),fullfile(outDir,'summary_transfer_thresholds.csv'));
end

function atomic_csv(T,file)
[folder,stem,ext]=fileparts(file);
tmp=fullfile(folder,[stem '_writing' ext]);
writetable(T,tmp); movefile(tmp,file,'f');
end
