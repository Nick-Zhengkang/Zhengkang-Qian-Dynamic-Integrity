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
function outDir=run_experiment_A_top6_exhaustive(o,resumeDir)
% Exhaustive six-factor screening using unmodified original DynIn GA.
if nargin<1 || isempty(o), o=top6_options('full'); end
if nargin<2, resumeDir=''; end
validateattributes(o.seeds,{'numeric'},{'vector','positive','integer','finite','nonempty'});
assert(numel(unique(o.seeds))==numel(o.seeds),'Duplicate seeds.');
validateattributes(o.exportEvery,{'numeric'},{'scalar','positive','integer'});
validateattributes(o.longRunWarningSeconds,{'numeric'},{'scalar','positive','finite'});
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
original=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
model=fullfile(repo,'work','DynIn','DynIn_v1.1.0','Unforced_Duffing_Oscillator');
assert(isfile(fullfile(original,'compute_LIM_FP.m')),'Original DynIn folder missing.');
oldPath=path; oldRng=rng; oldFolder=pwd;
if ~isempty(resumeDir)
    [exists,info]=fileattrib(char(resumeDir));
    assert(exists && info.directory,'Resume directory does not exist.');
    resumeDir=info.Name; % Resolve relative input before changing the folder.
end
restore=onCleanup(@() restore_session(oldPath,oldRng,oldFolder));
% Current-folder functions outrank addpath, even after restoredefaultpath.
cd(root);
restoredefaultpath; addpath(root,'-begin'); addpath(original,'-begin'); addpath(model,'-begin');
assert_source('original_A_adapter',fullfile(root,'original_A_adapter.m'));
assert_source('optimization_statistics',fullfile(root,'optimization_statistics.m'));
assert_source('compute_LIM_FP',fullfile(original,'compute_LIM_FP.m'));
assert_source('sistema',fullfile(model,'sistema.m'));
base=original_A_adapter('base');
[C,baselineId,meta]=top6_design(o,base);
signature=source_signature(root,original,model);
if isempty(resumeDir)
    outDir=fullfile(root,['outputs_top6_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir); mkdir(fullfile(outDir,'records'));
    stream=RandStream('mt19937ar','Seed',o.scheduleSeed);
    [ci,si]=ndgrid(1:numel(C),1:numel(o.seeds));
    pairs=[ci(:),reshape(o.seeds(si(:)),[],1)];
    pairs=pairs(randperm(stream,size(pairs,1)),:);
    schedule=array2table([(1:size(pairs,1)).' pairs], ...
        'VariableNames',{'execution_order','config_index','seed'});
    schedule.config_id=reshape(string({C(pairs(:,1)).config_id}),[],1);
    atomic_save(fullfile(outDir,'study_definition.mat'),struct('options',o,'base',base, ...
        'configs',C,'baselineId',baselineId,'meta',meta,'schedule',schedule,'source_signature',signature));
    snapshot_sources(root,original,model,outDir);
else
    outDir=char(resumeDir);
    saved=load(fullfile(outDir,'study_definition.mat'));
    assert(isequaln(saved.options,o) && isequaln(saved.configs,C),'Saved design differs.');
    assert(isequal(saved.source_signature,signature),'Numerical source changed; do not mix implementations.');
    schedule=saved.schedule;
end
atomic_table(struct2table(C),fullfile(outDir,'configurations.csv'));
atomic_table(struct2table(o,'AsArray',true),fullfile(outDir,'study_options.csv'));
atomic_table(schedule,fullfile(outDir,'randomized_schedule.csv'));
fprintf('\nTop-six exhaustive Experiment A: %s\nOutput: %s\n',upper(o.mode),outDir);
fprintf('%d configurations x %d seeds = %d planned runs (baseline included).\n', ...
    numel(C),numel(o.seeds),height(schedule));
fprintf('Fixed N=100; divR=40; clones=2; rep_fix_point=40; Ts=0.05.\n');
fprintf('Fixed tfinal=2000; ODE tolerances=1e-8; rep_periodic=10; type_x0=1.\n');
fprintf('Reference=%.4f (published numerical result). Screening, NOT a confirmed optimum.\n',base.reference_LIM);

diagnosticFile=fullfile(outDir,'diagnostic.mat');
if isfile(diagnosticFile)
    x=load(diagnosticFile,'D'); D=x.D;
else
    fprintf('Preparing fixed diagnostic points ...\n'); t=tic;
    D=original_A_adapter('diagnostic',base,o.diagnosticAngles,false);
    atomic_save(diagnosticFile,struct('D',D,'setup_seconds',toc(t)));
end
assert(any(D.true_label==1) && any(D.true_label==2) && all(D.true_label~=0), ...
    'Independent reference labels must resolve both classes.');
atomic_table(D,fullfile(outDir,'diagnostic_points.csv'));
rows=cell(height(schedule),1);
fprintf('Checking saved per-run records ...\n');
for i=1:height(schedule)
    file=record_path(outDir,i);
    if isfile(file)
        x=load(file,'row'); r=x.row;
        assert(r.execution_order==i && r.seed==schedule.seed(i) && ...
            r.config_id==schedule.config_id(i),'Saved record identity mismatch.');
        rows{i}=r;
    end
    if mod(i,1000)==0, fprintf('Checked %d/%d record positions.\n',i,height(schedule)); end
end
done=nnz(~cellfun(@isempty,rows));
fprintf('Resume: %d completed; %d remaining.\n',done,height(schedule)-done);
sessionId=string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
sessionTimer=tic;
try
    if done<height(schedule)
        warm=C(find(string({C.config_id})==baselineId,1)); warm.number_of_steps=2;
        rng(987650,'twister'); warmResult=original_A_adapter('execute',warm,base);
        assert(warmResult.success,'Warm-up failed: %s',char(warmResult.error_message));
        fprintf('Warm-up finished (not part of 9720 recorded full runs).\n');
    end
    for i=1:height(schedule)
        if ~isempty(rows{i}), continue; end
        cfg=C(schedule.config_index(i)); seed=schedule.seed(i);
        fprintf('[run %d/%d] START seed=%d %s\n',i,height(schedule),seed,cfg.config_id);
        rng(100000+seed,'twister');
        [r,~,H]=original_A_adapter('execute',cfg,base);
        fprintf('[run %d/%d] INTEGRATION DONE R=%.6g err=%.3f%% wall=%.2fs; diagnostics ...\n', ...
            i,height(schedule),r.R_hat,100*r.relative_error,r.wall_runtime_s);
        d=original_A_adapter('empty_diagnostic'); diagOk=false; diagError=""; t=tic;
        if r.success
            try
                d=original_A_adapter('evaluate',D,H,cfg,base);
                diagOk=all(isfinite([d.false_safe_rate d.false_unsafe_rate ...
                    d.diagnostic_unresolved_rate d.diagnostic_truth_unresolved_rate]));
            catch ME
                diagError=string(getReport(ME,'basic','hyperlinks','off'));
            end
        end
        r.diagnostic_runtime_s=toc(t);
        row=cfg; row.seed=seed; row.execution_order=i; row.session_id=sessionId;
        row.is_baseline=cfg.config_id==baselineId; row.reference_LIM=base.reference_LIM;
        row=merge_fields(row,r); row=merge_fields(row,d);
        row.diagnostic_success=diagOk; row.diagnostic_error=diagError;
        row.timing_review_required=r.wall_runtime_s>o.longRunWarningSeconds;
        row.diagnostic_timing_review_required=r.diagnostic_runtime_s>o.longRunWarningSeconds;
        atomic_save(record_path(outDir,i),struct('row',row));
        rows{i}=row; done=done+1;
        fprintf('[run %d/%d] DONE success=%d diag=%d; saved=%d/%d; session=%.1f min\n', ...
            i,height(schedule),r.success,diagOk,done,height(schedule),toc(sessionTimer)/60);
        if row.timing_review_required || row.diagnostic_timing_review_required
            fprintf('  TIMING REVIEW: unusually long elapsed time retained; check for sleep/pause/load.\n');
        end
        if mod(done,o.exportEvery)==0, export_raw(rows,outDir); end
        clear H
    end
catch ME
    % MAT records are authoritative even if interruption prevents CSV export.
    export_raw(rows,outDir);
    fprintf('Saved progress is in %s. Resume with the same directory.\n',outDir);
    rethrow(ME)
end
raw=export_raw(rows,outDir);
[S,best,decision]=top6_summarize(raw,C,baselineId,o);
atomic_table(S,fullfile(outDir,'summary_by_configuration.csv'));
atomic_table(S(1:min(20,height(S)),:),fullfile(outDir,'top20_screening_candidates.csv'));
atomic_table(best,fullfile(outDir,'best_screening_parameters.csv'));
atomic_table(raw(raw.timing_review_required | raw.diagnostic_timing_review_required,:), ...
    fullfile(outDir,'timing_review_runs.csv'));
write_json(decision,fullfile(outDir,'decision.json'));
fprintf('\nEXHAUSTIVE SCREENING FINISHED: %s\n',decision.status);
fprintf('Raw: %s\nSummary: %s\nBest screening record: %s\n', ...
    fullfile(outDir,'raw_data_all_runs.csv'),fullfile(outDir,'summary_by_configuration.csv'), ...
    fullfile(outDir,'best_screening_parameters.csv'));
fprintf('No independent confirmation performed. With 3 seeds, empirical P95 is the maximum.\n');
end

function file=record_path(outDir,i)
file=fullfile(outDir,'records',sprintf('run_%05d.mat',i));
end
function raw=export_raw(rows,outDir)
filled=rows(~cellfun(@isempty,rows)); raw=table();
if isempty(filled), return; end
raw=struct2table(vertcat(filled{:}));
atomic_table(raw,fullfile(outDir,'raw_data_all_runs.csv'));
end
function a=merge_fields(a,b)
names=fieldnames(b); for i=1:numel(names), a.(names{i})=b.(names{i}); end
end
function atomic_save(file,data)
temp=[file '.tmp.mat']; save(temp,'-struct','data','-v7');
[ok,msg]=movefile(temp,file,'f'); assert(ok,'%s',msg);
end
function atomic_table(T,file)
temp=[file '.tmp']; writetable(T,temp,'FileType','text','Delimiter',',');
[ok,msg]=movefile(temp,file,'f'); assert(ok,'%s',msg);
end
function write_json(data,file)
temp=[file '.tmp']; fid=fopen(temp,'w'); assert(fid>=0);
try
    fprintf(fid,'%s',jsonencode(data,'PrettyPrint',true)); fclose(fid);
catch ME
    fclose(fid); rethrow(ME)
end
[ok,msg]=movefile(temp,file,'f'); assert(ok,'%s',msg);
end
function assert_source(name,expected)
actual=which(name);
assert(strcmpi(actual,expected),'Unexpected source for %s. Expected: %s. Found: %s.', ...
    name,expected,actual);
end
function restore_session(p,r,folder)
cd(folder); path(p); rng(r);
end
function signature=source_signature(root,original,model)
files=[dir(fullfile(root,'*.m'));dir(fullfile(original,'*.m'));dir(fullfile(model,'*.m'))];
names=string({files.name});
files=files(~startsWith(names,'test_') & ~startsWith(names,'selftest_'));
signature=strings(numel(files),2);
for i=1:numel(files)
    file=fullfile(files(i).folder,files(i).name);
    fid=fopen(file,'rb'); assert(fid>=0); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
    md=java.security.MessageDigest.getInstance('SHA-256'); md.update(typecast(bytes,'int8'));
    digest=typecast(md.digest(),'uint8');
    signature(i,:)=[string(file),string(lower(reshape(dec2hex(digest,2).',1,[])))];
end
signature=sortrows(signature,1);
end
function snapshot_sources(root,original,model,outDir)
target=fullfile(outDir,'source_snapshot'); mkdir(target);
for name={'runner','original_functions','model'}, mkdir(fullfile(target,name{1})); end
copyfile(fullfile(root,'*.m'),fullfile(target,'runner'));
copyfile(fullfile(original,'*.m'),fullfile(target,'original_functions'));
copyfile(fullfile(model,'*.m'),fullfile(target,'model'));
end
