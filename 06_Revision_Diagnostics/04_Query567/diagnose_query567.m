function out=diagnose_query567(o)
% AI-assisted observational replay. The seven copied algorithm files are
% byte-identical to the completed 90-case run; no rules are patched here.
root=fileparts(mfilename('fullpath')); oldPath=path; oldDir=pwd; oldRng=rng;
restore=onCleanup(@() restore_environment(oldPath,oldDir,oldRng)); %#ok<NASGU>
cd(root); addpath(root);
assert(o.queryId==567,'This package diagnoses query 567 of quadratic-cubic seed 30.');
protected={canonical(o.sourceResults),canonical(o.originalArchive)};
assert(all(cellfun(@isfolder,protected)),'A protected input folder is missing.');
out=fullfile(o.outputRoot,datestr(now,'yyyymmdd_HHMMSS_FFF'));
for k=1:numel(protected)
    assert(~startsWith(lower([canonical(out) filesep]),lower([protected{k} filesep])), ...
        'Output must be outside every protected input folder.');
end
assert(~isfolder(out),'Output already exists.'); mkdir(out);
diary(fullfile(out,'run.log')); diaryGuard=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Read-only source run: %s\nDiagnostic output: %s\n',protected{1},out);
source=protected{1}; before=protected_hashes(protected);
writetable(before,fullfile(out,'protected_files_before.csv'));
root_id=(1:numel(protected)).'; protected_path=string(protected(:));
writetable(table(root_id,protected_path),fullfile(out,'protected_roots.csv'));
integrity=onCleanup(@() check_integrity(protected,before,out)); %#ok<NASGU>
status=struct('reproduced',false,'diagnosis_available',false, ...
    'executed_branch',"not_established",'message',"");
try
    verify_copies(root,source,out);
    mkdir(fullfile(out,'source_snapshot'));
    for folder=["engine","native","model"]
        copyfile(fullfile(root,char(folder)),fullfile(out,'source_snapshot',char(folder)));
    end
    copyfile(fullfile(root,'*.m'),fullfile(out,'source_snapshot'));
    caseDir=fullfile(source,'quadratic_cubic_seed_30');
    f=load(fullfile(caseDir,'no_negative_reuse.mat'),'r','details');
    settings=load(fullfile(caseDir,'effective_settings.mat'));
    d=settings.d; assert(string(d.model_id)=="quadratic_cubic");
    assert(isequaln(settings.c.nativeConfig,d));
    originalModelDir=d.modelDir; d.modelDir=fullfile(root,'model');
    restored=d; restored.modelDir=originalModelDir; assert(isequaln(restored,settings.d));
    saved=f.details.query_records; qid=o.queryId; assert(numel(saved)>=qid);
    expected=saved{qid};
    assert(expected.native_tipo==4 && string(expected.label)=="non_target");
    assert(string(expected.classification_reason)=="native_non_target_recurrence");
    assert(abs(expected.initial_radius-f.r.R_hat)<1e-10);
    meta=readtable(fullfile(caseDir,'all_results.csv'),'TextType','string');
    meta=meta(meta.condition=="no_negative_reuse",:);
    assert(height(meta)==1 && meta.seed==30 && meta.winning_query==qid);
    environment=struct('matlab_version',version,'options',o,'source_case',caseDir, ...
        'saved_effective_settings',settings,'replay_config',d);
    save(fullfile(out,'diagnostic_settings.mat'),'environment');
    activate(root);
    counter_tests(out);
    replayTimer=tic;
    api=sampled_forward_classifier(d,@() toc(replayTimer)<settings.s.maxSeconds);
    checks=cell(qid,1);
    for k=1:qid
        if k==qid, gBefore=api.state(); end
        e=saved{k};
        [actual,~]=api.classify(e.initial_state);
        stateError=norm(reshape(actual.min_point,1,[])-reshape(e.min_point,1,[]),Inf);
        radiusError=abs(actual.min_radius-e.min_radius);
        matches=string(actual.label)==string(e.label) && ...
            string(actual.classification_reason)==string(e.classification_reason) && ...
            actual.native_tipo==e.native_tipo && actual.sample_count==e.sample_count && ...
            actual.integration_count==e.integration_count && actual.rhs_count==e.rhs_count && ...
            actual.grid_cache_kind==e.grid_cache_kind && actual.grid_cache_hit==e.grid_cache_hit && ...
            actual.forced_non_target==e.forced_non_target && ...
            abs(actual.end_time-e.end_time)<=1e-10 && radiusError<=1e-8 && stateError<=1e-8;
        checks{k}=struct('query',k,'matches_saved',matches,'actual_label',string(actual.label), ...
            'actual_reason',string(actual.classification_reason),'saved_reason',string(e.classification_reason), ...
            'actual_kind',actual.native_tipo,'saved_kind',e.native_tipo, ...
            'sample_count',actual.sample_count,'saved_sample_count',e.sample_count, ...
            'end_time',actual.end_time,'saved_end_time',e.end_time, ...
            'rhs_count',actual.rhs_count,'saved_rhs_count',e.rhs_count, ...
            'min_radius_difference',radiusError,'min_point_difference',stateError);
        if mod(k,100)==0 || k==qid || ~matches
            writetable(struct2table(vertcat(checks{1:k})),fullfile(out,'replay_checks.csv'));
            fprintf('Replayed query %d/%d; current match=%d\n',k,qid,matches);
        end
        assert(matches,'Replay mismatch at query %d. No branch conclusion may be drawn.',k);
    end
    % Reintegrate just the decisive query using the exact pre-query cache.
    % The unmodified native integrator returns its sampled states and cells.
    [xt,cells,kind,count,rhsCalls]=sampled_forward_integrate(d,gBefore,expected.initial_state);
    assert(kind==expected.native_tipo && count==expected.sample_count && rhsCalls==expected.rhs_count);
    distance=sqrt(sum((xt-d.target).^2.*d.weight,2));
    [minimum,j]=min(distance);
    assert(abs(minimum-expected.min_radius)<=1e-8 && ...
        norm(xt(j,:)-reshape(expected.min_point,1,[]),Inf)<=1e-8);
    assert(abs((count-1)*d.Ts-expected.end_time)<=1e-10);
    time=(0:count-1).'*d.Ts;
    save(fullfile(out,'query567_native_trajectory.mat'), ...
        'time','xt','cells','gBefore','d','expected','kind','count','rhsCalls','-v7.3');
    trajectory=table((1:count).',time,xt(:,1),xt(:,2),cells,distance, ...
        'VariableNames',{'sample_index','time','x','v','cell_id','distance_to_target'});
    writetable(trajectory,fullfile(out,'query567_native_trajectory.csv'));
    status.reproduced=true;
    trigger=audit_query567_samples(xt,cells,gBefore,d,out);
    copyfile(fullfile(caseDir,'independent_postcheck','independent_validation.csv'), ...
        fullfile(out,'previous_independent_validation.csv'));
    status.diagnosis_available=true; status.executed_branch=trigger.executed_branch;
    write_explanation(out,trigger,expected,meta.R_reference);
    fprintf('\nTRIGGER: %s at t=%.12g, sample %d, cell %d\n', ...
        trigger.executed_branch,trigger.time,trigger.sample_index,trigger.cell_id);
    fprintf('Prior visits=%d; adjacent gaps=%d (threshold %g); nonadjacent gaps=%d (threshold %g)\n', ...
        trigger.previous_visit_count,trigger.adjacent_gap_count,trigger.rep_fix_point, ...
        trigger.nonadjacent_gap_count,trigger.rep_periodic);
catch ME
    status.message=string(getReport(ME,'extended','hyperlinks','off'));
    fid=fopen(fullfile(out,'ERROR.txt'),'w'); fprintf(fid,'%s',status.message); fclose(fid);
    fprintf(2,'%s\n',status.message);
end
writetable(struct2table(status),fullfile(out,'diagnostic_status.csv'));
end

function activate(root)
clear sampled_forward_classifier sampled_forward_geometry sampled_forward_integrate sampled_forward_step sistema
addpath(fullfile(root,'engine'),fullfile(root,'native'),fullfile(root,'model'),'-begin'); rehash;
for name=["sampled_forward_classifier","sampled_forward_geometry","sampled_forward_integrate","sampled_forward_step"]
    assert(samepath(which(char(name)),fullfile(root,'engine',char(name+".m"))));
end
for name=["find_index","find_cells_around_a_cell"]
    assert(samepath(which(char(name)),fullfile(root,'native',char(name+".m"))));
end
assert(samepath(which('sistema'),fullfile(root,'model','sistema.m')));
end

function verify_copies(root,source,out)
snapshot=fullfile(source,'source_snapshot'); rows=cell(0,1);
for name=["sampled_forward_classifier","sampled_forward_geometry","sampled_forward_integrate","sampled_forward_step"]
    rows{end+1,1}=copy_record(fullfile(snapshot,'engines','no_negative_reuse',char(name+".m")), ...
        fullfile(root,'engine',char(name+".m"))); %#ok<AGROW>
end
for name=["find_index","find_cells_around_a_cell"]
    rows{end+1,1}=copy_record(fullfile(snapshot,'shared','native',char(name+".m")), ...
        fullfile(root,'native',char(name+".m"))); %#ok<AGROW>
end
rows{end+1,1}=copy_record(fullfile(snapshot,'models','quadratic_cubic','sistema.m'), ...
    fullfile(root,'model','sistema.m'));
T=struct2table(vertcat(rows{:})); writetable(T,fullfile(out,'source_verification.csv'));
assert(all(T.identical),'A copied algorithm file differs from the completed run.');
end
function r=copy_record(a,b)
r=struct('source',string(a),'copy',string(b),'identical',isequal(bytes(a),bytes(b)));
end
function b=bytes(file)
fid=fopen(file,'rb'); assert(fid>=0,'Cannot open %s',file);
guard=onCleanup(@() fclose(fid)); %#ok<NASGU>
b=fread(fid,Inf,'*uint8');
end

function counter_tests(out)
% Synthetic histories test the observer, never the experiment parameters.
d=struct('repFixPoint',40,'repPeriodic',10); cid=17;
histories={repmat(cid,41,1);repmat(cid,42,1);repmat([cid;18],11,1); ...
    repmat([cid;18],12,1);[repmat(cid,22,1);18;repmat(cid,22,1)]; ...
    [repmat(cid,42,1);repmat([18;cid],12,1);18]};
names=["fixed_threshold_equality";"fixed_strict_excess";"periodic_threshold_equality"; ...
    "periodic_strict_excess";"cumulative_pairs_not_current_streak";"fixed_precedes_periodic"];
expected=["none";"rep_fix_point";"none";"rep_periodic";"rep_fix_point";"rep_fix_point"];
passed=false(6,1);
for k=1:6
    s=recurrence_statistics(histories{k},cid,d); passed(k)=s.counter_branch==expected(k);
    if k==5, passed(k)=passed(k) && s.adjacent_gap_count==42 && s.current_streak_including_current==23; end
    if k==6, passed(k)=passed(k) && s.fixed_condition && s.periodic_condition; end
end
writetable(table(names,expected,passed),fullfile(out,'observer_tests.csv'));
assert(all(passed),'The recurrence observer failed its synthetic tests.');
end

function write_explanation(out,t,q,reference)
fid=fopen(fullfile(out,'TRIGGER_EXPLANATION.txt'),'w');
guard=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'READ-ONLY DIAGNOSIS: quadratic-cubic, seed 30, query 567\n');
fprintf(fid,'Queries 1:567 reproduce saved labels, sample counts and numerical checks.\n');
fprintf(fid,'Executed branch: %s\nTime: %.15g\nSample: %d\nCell: %d\n', ...
    t.executed_branch,t.time,t.sample_index,t.cell_id);
fprintf(fid,'Initial state: [%.16g, %.16g]\nTerminal sampled state: [%.16g, %.16g]\n', ...
    q.initial_state(1),q.initial_state(2),t.x,t.v);
fprintf(fid,'Initial radius: %.16g\nAnalytical reference: %.16g\n',q.initial_radius,reference);
fprintf(fid,'rep_fix_point expression: nnz(diff(prior)==1) > repFixPoint\n');
fprintf(fid,'Numerical comparison: %d > %g; condition=%d\n',t.adjacent_gap_count,t.rep_fix_point,t.fixed_condition);
fprintf(fid,'rep_periodic outer expression: numel(prior)>repPeriodic+1 AND prior(end)~=count-1\n');
fprintf(fid,'Prior visits: %d; count gate=%d; not-immediately-previous gate=%d\n', ...
    t.previous_visit_count,t.periodic_count_gate,t.periodic_not_immediate_gate);
fprintf(fid,'rep_periodic inner expression: nnz(diff(prior)~=1) > repPeriodic\n');
fprintf(fid,'Numerical comparison: %d > %g; inner condition=%d\n', ...
    t.nonadjacent_gap_count,t.rep_periodic,t.periodic_gap_condition);
fprintf(fid,'Periodic outer condition actually evaluated: %d\nPeriodic inner condition actually evaluated: %d\n', ...
    t.periodic_outer_condition_evaluated,t.periodic_inner_condition_evaluated);
fprintf(fid,'Current consecutive occupancy including this sample: %d samples\n',t.current_streak_including_current);
fprintf(fid,'The current sample is excluded from prior and from both gap counts.\n');
fprintf(fid,'Adjacent gaps are counted over ALL prior visits to this cell, not only the current occupancy episode.\n');
fprintf(fid,'The fixed-point branch takes precedence over the periodic branch.\n');
fprintf(fid,'No rule, threshold, ODE setting or original record was modified.\n');
fprintf(fid,'The prior independent validation is copied for context; no new long-horizon validation is performed here.\n');
end

function T=protected_hashes(roots)
parts=cell(numel(roots),1);
for k=1:numel(roots)
    parts{k}=diagnostic_hashes(roots{k}); parts{k}.root_id=repmat(k,height(parts{k}),1);
end
T=vertcat(parts{:});
end
function check_integrity(roots,before,out)
after=protected_hashes(roots); writetable(after,fullfile(out,'protected_files_after.csv'));
same=isequal(before,after);
fid=fopen(fullfile(out,'INPUT_INTEGRITY.txt'),'w');
fprintf(fid,'Completed 90-case results and original experiment bytes unchanged: %d\n',same); fclose(fid);
if ~same, warning('A protected input changed during diagnosis. Inspect before interpreting results.'); end
end
function p=canonical(p)
p=char(java.io.File(p).getCanonicalPath());
end
function yes=samepath(a,b)
yes=strcmpi(strrep(a,'\','/'),strrep(b,'\','/'));
end
function restore_environment(p,d,r)
path(p); cd(d); rng(r);
clear sampled_forward_classifier sampled_forward_geometry sampled_forward_integrate sampled_forward_step sistema
end
