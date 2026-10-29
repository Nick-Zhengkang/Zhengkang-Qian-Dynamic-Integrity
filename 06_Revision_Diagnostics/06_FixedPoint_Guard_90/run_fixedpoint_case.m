function summary=run_fixedpoint_case(root,o,out,id,seed,queue)
% AI-assisted worker. One process owns each model/seed cache and output.
oldPath=path; oldRng=rng; oldDir=pwd;
restore=onCleanup(@() restore_state(oldPath,oldRng,oldDir)); %#ok<NASGU>
cd(root); addpath(root,'-begin');
folder=fullfile(out,sprintf('%s_seed_%d',id,seed));
assert(~isfolder(folder)); mkdir(folder);
diary(fullfile(folder,'run.log')); logGuard=onCleanup(@() diary('off')); %#ok<NASGU>
summary=empty_summary(id,seed);
send(queue,sprintf('START %s seed %d',id,seed));
try
    prior=fullfile(o.previousResults,sprintf('%s_seed_%d',id,seed));
    E=load(fullfile(prior,'effective_settings.mat'));
    M=load(fullfile(prior,'case_result.mat'),'result');
    H=load(fullfile(prior,'no_negative_reuse.mat'),'r','details');
    assert(string(M.result.status.status)=="complete");
    rows=M.result.rows;
    match=cellfun(@(r) string(r.condition)=="no_negative_reuse",rows);
    assert(nnz(match)==1); meta=rows{find(match,1)};
    assert(meta.seed==seed && string(meta.model)==id);
    assert(abs(meta.R_hat-H.r.R_hat)<1e-10);
    algorithmSeed=double(meta.algorithm_seed);
    d=E.d; p=E.p; c=E.c; s=E.s;
    assert(numel(d.target)==2 && string(d.model_id)==id && isequaln(c.nativeConfig,d));
    d.modelDir=fullfile(root,'models',char(id)); c.nativeConfig=d;
    reverted=d; reverted.modelDir=E.d.modelDir;
    assert(isequaln(reverted,E.d),'A native setting other than path was changed.');
    revertedC=c; revertedC.nativeConfig=E.d;
    assert(isequaln(revertedC,E.c));
    save(fullfile(folder,'effective_settings.mat'),'d','p','c','s','algorithmSeed');
    summary.algorithm_seed=algorithmSeed; summary.alpha=d.par.alpha;
    summary.R_reference=meta.R_reference; summary.previous_R=H.r.R_hat;
    summary.phase="control";
    [control,controlDetails]=condition(root,"control",d,p,c,s,algorithmSeed);
    save(fullfile(folder,'control_replay.mat'),'control','controlDetails','-v7.3');
    checks=compare_control(control,controlDetails,H);
    writetable(checks,fullfile(folder,'control_reproduction_checks.csv'));
    summary.control_reproduced=all(checks.passed);
    summary.control_R=control.R_hat;
    assert(summary.control_reproduced,'Control did not reproduce the prior run. Repair skipped.');
    summary.phase="fixed_point_guard";
    [r,details]=condition(root,"fixed_point_guard",d,p,c,s,algorithmSeed);
    save(fullfile(folder,'fixed_point_guard.mat'),'r','details','-v7.3');
    assert(r.grid_cache_non_target_hit_count==0,'Non-target cache reads were re-enabled.');
    writetable(details.queries,fullfile(folder,'queries.csv'));
    writetable(details.history,fullfile(folder,'history.csv'));
    Q=query_audit(details); writetable(Q,fullfile(folder,'query_classification_audit.csv'));
    summary.R_hat=r.R_hat;
    summary.signed_error_percent=100*(r.R_hat-meta.R_reference)/meta.R_reference;
    summary.absolute_error_percent=abs(summary.signed_error_percent);
    summary.under_reference=isfinite(r.R_hat) && r.R_hat<meta.R_reference-1e-10;
    summary.query_count=r.query_count; summary.rhs_count=r.rhs_count;
    summary.runtime_s=r.algorithm_runtime_s;
    summary.stop_status=string(r.stop_status);
    summary.converged=r.converged;
    summary.time_guard_hit=string(r.stop_status)=="time_budget";
    summary.target_cache_hits=r.grid_cache_target_hit_count;
    summary.non_target_cache_hits=r.grid_cache_non_target_hit_count;
    summary.forced_non_target_count=r.forced_non_target_count;
    summary.unresolved_count=r.unresolved_count;
    summary.fixed_candidates=sum(Q.fp_candidates);
    summary.fixed_rejected=sum(Q.fp_rejected);
    summary.fixed_accepted=sum(Q.fp_accepted);
    summary.periodic_terminations=nnz(Q.terminal_rule=="periodic_recurrence");
    unsafe=Q.label=="non_target";
    if any(unsafe)
        ids=find(unsafe); [best,j]=min(Q.initial_radius(ids)); win=ids(j);
        assert(abs(best-r.R_hat)<1e-10);
        summary.winning_query=win; summary.winning_rule=Q.terminal_rule(win);
        summary.winning_x0=Q.x0(win); summary.winning_v0=Q.v0(win);
    end
    summary.phase="independent_validation";
    guard=activate_guard_engine(root,"fixed_point_guard",d); %#ok<NASGU>
    [summary.winning_validation,summary.all_checked_non_target_supported]= ...
        validate_guard_points(id,d,details,meta.R_reference, ...
        fullfile(folder,'independent_postcheck'),o);
    clear guard
    summary.status="complete"; summary.phase="done";
catch ME
    summary.status="error";
    summary.message=string(getReport(ME,'extended','hyperlinks','off'));
    fid=fopen(fullfile(folder,'ERROR.txt'),'w');
    if fid>=0, fprintf(fid,'%s',summary.message); fclose(fid); end
    fprintf(2,'%s\n',summary.message);
end
save(fullfile(folder,'case_result.mat'),'summary');
writetable(struct2table(summary),fullfile(folder,'case_summary.csv'));
send(queue,sprintf('%s %s seed %d | R=%.10g | validation=%s | %s', ...
    upper(summary.status),id,seed,summary.R_hat,summary.winning_validation,summary.phase));
end

function [r,details]=condition(root,mode,d,p,c,s,algorithmSeed)
guard=activate_guard_engine(root,mode,d); %#ok<NASGU>
fprintf('START %s | seed %d | query budget %g | wall guard %gs\n', ...
    mode,algorithmSeed,s.queryBudget,s.maxSeconds);
[r,details]=sampled_forward_proposed(p,c,s,[],algorithmSeed);
fprintf('DONE %s | R %.12g | queries %d | %s\n',mode,r.R_hat,r.query_count,r.stop_status);
end

function T=compare_control(r,details,H)
a=details.query_records; b=H.details.query_records;
names=["radius";"query_count";"stop_status";"all_query_states_labels_and_counts"];
passed=[near(r.R_hat,H.r.R_hat,1e-10);numel(a)==numel(b); ...
    string(r.stop_status)==string(H.r.stop_status);false];
if numel(a)==numel(b)
    same=true;
    for k=1:numel(a)
        x=a{k}; y=b{k};
        same=same && near(x.initial_state,y.initial_state,1e-10) && ...
            string(x.label)==string(y.label) && ...
            string(x.classification_reason)==string(y.classification_reason) && ...
            x.sample_count==y.sample_count && x.native_tipo==y.native_tipo && ...
            x.grid_cache_kind==y.grid_cache_kind && x.rhs_count==y.rhs_count && ...
            x.integration_count==y.integration_count && x.forced_non_target==y.forced_non_target && ...
            near(x.min_radius,y.min_radius,1e-8) && near(x.min_point,y.min_point,1e-8);
        if ~same, break; end
    end
    passed(4)=same;
end
T=table(names,passed);
end
function yes=near(a,b,tol)
yes=isequaln(a,b) || (isequal(size(a),size(b)) && all(abs(a-b)<=tol,'all'));
end

function Q=query_audit(details)
qs=details.query_records; rows=cell(numel(qs),1);
for k=1:numel(qs)
    q=qs{k}; events=q.fp_events; firstTime=NaN; firstX=NaN; firstV=NaN;
    if ~isempty(events), firstTime=events(1,2); firstX=events(1,3); firstV=events(1,4); end
    rule=string(q.classification_reason);
    if q.native_tipo==4
        if q.fp_accepted_count>0, rule="confirmed_non_target_well";
        else, rule="periodic_recurrence"; end
    end
    rows{k}=struct('query',k,'x0',q.initial_state(1),'v0',q.initial_state(2), ...
        'initial_radius',q.initial_radius,'label',string(q.label),'terminal_rule',rule, ...
        'native_tipo',q.native_tipo,'samples',q.sample_count,'end_time',q.end_time, ...
        'cache_kind',q.grid_cache_kind,'fp_candidates',q.fp_candidate_count, ...
        'fp_rejected',q.fp_rejected_count,'fp_accepted',q.fp_accepted_count, ...
        'first_fp_time',firstTime,'first_fp_x',firstX,'first_fp_v',firstV);
end
Q=struct2table(vertcat(rows{:}));
end

function s=empty_summary(id,seed)
s=struct('model',id,'seed',seed,'status',"pending",'phase',"load",'message',"", ...
    'algorithm_seed',NaN,'alpha',NaN,'R_reference',NaN,'previous_R',NaN, ...
    'control_reproduced',false,'control_R',NaN,'R_hat',NaN, ...
    'signed_error_percent',NaN,'absolute_error_percent',NaN,'under_reference',false, ...
    'query_count',NaN,'rhs_count',NaN,'runtime_s',NaN,'stop_status',"not_run", ...
    'converged',false,'time_guard_hit',false,'target_cache_hits',NaN, ...
    'non_target_cache_hits',NaN,'forced_non_target_count',NaN,'unresolved_count',NaN, ...
    'fixed_candidates',NaN,'fixed_rejected',NaN,'fixed_accepted',NaN, ...
    'periodic_terminations',NaN,'winning_query',NaN,'winning_rule',"none", ...
    'winning_x0',NaN,'winning_v0',NaN,'winning_validation',"not_run", ...
    'all_checked_non_target_supported',false);
end
function restore_state(p,r,folder)
path(p); rng(r); cd(folder);
end
