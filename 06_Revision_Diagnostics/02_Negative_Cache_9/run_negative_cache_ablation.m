function out=run_negative_cache_ablation(o)
% AI-assisted paired ablation runner. Do not edit the original study.
root=fileparts(mfilename('fullpath')); oldPath=path; oldDir=pwd; oldRng=rng;
restore=onCleanup(@() restore_environment(oldPath,oldDir,oldRng)); %#ok<NASGU>
cd(root); addpath(root);
data=char(java.io.File(o.dataDirectory).getCanonicalPath());
assert(isfolder(data),'Original experiment directory not found.');
out=fullfile(o.outputRoot,datestr(now,'yyyymmdd_HHMMSS_FFF'));
canonical=char(java.io.File(out).getCanonicalPath());
assert(~startsWith(lower([canonical filesep]),lower([data filesep])), ...
    'Output must not be inside the original experiment.');
assert(~isfolder(out),'Output already exists.'); mkdir(out);
diary(fullfile(out,'run.log')); diaryGuard=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Original data (read only): %s\nOutput: %s\n',data,out);
audit=diagnostic_hashes(data); writetable(audit,fullfile(out,'original_files_before.csv'));
integrity=onCleanup(@() check_integrity(data,audit,out)); %#ok<NASGU>
verify_ablation_sources(root,data,out);
mkdir(fullfile(out,'source_snapshot'));
for folder=["engines","shared","models"]
    copyfile(fullfile(root,char(folder)),fullfile(out,'source_snapshot',char(folder)));
end
copyfile(fullfile(root,'*.m'),fullfile(out,'source_snapshot'));
copyfile(fullfile(root,'README.txt'),fullfile(out,'source_snapshot'));
environment=struct('matlab_version',version,'options',o,'original_data',data);
save(fullfile(out,'environment.mat'),'environment');
model=[repmat("quadratic_cubic",3,1);repmat("bistable_duffing",3,1); ...
    repmat("genda_cosine_quadratic_drag",3,1)];
seed=[19;12;7;30;1;17;12;26;27]; cases=table(model,seed);
writetable(cases,fullfile(out,'selected_cases.csv'));
rows=cell(0,1); comparisons=cell(0,1); states=cell(0,1);
for k=1:height(cases)
    id=cases.model(k); seed=cases.seed(k);
    caseOut=fullfile(out,sprintf('%s_seed_%d',id,seed)); mkdir(caseOut);
    phase="load"; baselineMatched=NaN;
    fprintf('\nCASE %d/9: %s seed %d\n',k,id,seed);
    try
        old=load(fullfile(data,'runs',sprintf('%s__proposed_sampled_forward__seed_%d.mat',id,seed)));
        settings=load(fullfile(data,char(id+"_settings.mat")));
        d=settings.dynin; p=settings.problem;
        c=settings.proposedClassifier; s=settings.proposedSearch;
        assert(numel(p.target)==2 && isequaln(c.nativeConfig,d));
        assert(all(s.maxSeconds>0) && s.queryBudget>0);
        % Only relocate the model file. Every numerical setting is inherited.
        d.modelDir=fullfile(root,'models',char(id)); c.nativeConfig=d;
        originalModelPath=settings.dynin.modelDir;
        restoredD=d; restoredD.modelDir=originalModelPath;
        restoredC=c; restoredC.nativeConfig.modelDir=originalModelPath;
        assert(isequaln(restoredD,settings.dynin) && ...
            isequaln(restoredC,settings.proposedClassifier));
        save(fullfile(caseOut,'effective_settings.mat'),'d','p','c','s','originalModelPath');
        algorithmSeed=double(old.row.algorithm_seed);
        assert(seed==old.row.seed);
        rows{end+1,1}=summary_row(old.row,id,seed,algorithmSeed,"recorded_original", ...
            old.row.R_reference,old.details,NaN); %#ok<AGROW>
        control=struct();
        if o.runBaselineControl
            phase="baseline_control";
            [control,controlDetails]=run_condition(root,"baseline",d,p,c,s,algorithmSeed);
            save(fullfile(caseOut,'baseline_control.mat'),'control','controlDetails','-v7.3');
            writetable(controlDetails.queries,fullfile(caseOut,'baseline_control_queries.csv'));
            checks=compare_historical(control,controlDetails,old);
            writetable(checks,fullfile(caseOut,'baseline_reproduction_checks.csv'));
            baselineMatched=all(checks.passed);
            rows{end+1,1}=summary_row(control,id,seed,algorithmSeed,"baseline_control", ...
                old.row.R_reference,controlDetails,baselineMatched); %#ok<AGROW>
            assert(baselineMatched, ...
                'Baseline did not reproduce the historical search. Ablation skipped for this case.');
        end
        phase="no_negative_reuse";
        [r,details]=run_condition(root,"no_negative_reuse",d,p,c,s,algorithmSeed);
        assert(r.grid_cache_non_target_hit_count==0, ...
            'Ablation still read a non-target cache label.');
        save(fullfile(caseOut,'no_negative_reuse.mat'),'r','details','-v7.3');
        writetable(details.queries,fullfile(caseOut,'no_negative_reuse_queries.csv'));
        writetable(details.history,fullfile(caseOut,'no_negative_reuse_history.csv'));
        rows{end+1,1}=summary_row(r,id,seed,algorithmSeed,"no_negative_reuse", ...
            old.row.R_reference,details,baselineMatched); %#ok<AGROW>
        qtable=struct2table(vertcat(details.query_records{:}));
        writetable(groupsummary(qtable,'classification_reason'), ...
            fullfile(caseOut,'no_negative_reuse_reason_counts.csv'));
        comparison=make_comparison(id,seed,old.row,r,control,baselineMatched);
        % Save the search comparison even if post-search verification fails.
        comparison.postcheck="not_run";
        comparisons{end+1,1}=comparison; %#ok<AGROW>
        writetable(struct2table(vertcat(comparisons{:})),fullfile(out,'comparison.csv'));
        if o.independentValidation && isfinite(r.R_hat)
            phase="independent_postcheck";
            comparison.postcheck=postcheck(root,id,d,details,old.row.R_reference,caseOut,o);
            comparisons{end,1}=comparison;
        end
        states{end+1,1}=struct('model',id,'seed',seed,'status',"complete", ...
            'phase',phase,'message',""); %#ok<AGROW>
    catch ME
        if phase=="independent_postcheck" && ~isempty(comparisons)
            comparisons{end}.postcheck="failed_see_ERROR";
        end
        msg=string(getReport(ME,'extended','hyperlinks','off'));
        fid=fopen(fullfile(caseOut,'ERROR.txt'),'w'); fprintf(fid,'%s',msg); fclose(fid);
        fprintf(2,'%s\n',msg);
        states{end+1,1}=struct('model',id,'seed',seed,'status',"error", ...
            'phase',phase,'message',msg); %#ok<AGROW>
    end
    if ~isempty(rows), writetable(struct2table(vertcat(rows{:})),fullfile(out,'all_results.csv')); end
    if ~isempty(comparisons), writetable(struct2table(vertcat(comparisons{:})),fullfile(out,'comparison.csv')); end
    writetable(struct2table(vertcat(states{:})),fullfile(out,'case_status.csv'));
end
fprintf('\nFinished. Inspect case_status.csv, comparison.csv and integrity checks.\n');
end

function [r,details]=run_condition(root,mode,d,p,c,s,seed)
guard=activate_condition(root,mode,d); %#ok<NASGU>
ablation_step_selftest(d,mode);
fprintf('  START %s | original seed %d | budget %g | wall guard %gs\n', ...
    mode,seed,s.queryBudget,s.maxSeconds);
[r,details]=sampled_forward_proposed(p,c,s,[],seed);
fprintf('  DONE %s | R=%.12g | queries=%d | RHS=%d | %.2fs | %s\n', ...
    mode,r.R_hat,r.query_count,r.rhs_count,r.algorithm_runtime_s,r.stop_status);
end

function guard=activate_condition(root,mode,d)
old=path; guard=onCleanup(@() path(old));
clear sampled_forward_proposed sampled_forward_classifier sampled_forward_geometry
clear sampled_forward_integrate sampled_forward_step sistema
clear('limbench.angular_with_oracle');
engine=fullfile(root,'engines',char(mode));
addpath(fullfile(root,'shared'),fullfile(root,'shared','native'),engine,d.modelDir,'-begin');
rehash;
for name=["sampled_forward_proposed","sampled_forward_classifier","sampled_forward_geometry", ...
        "sampled_forward_integrate","sampled_forward_step"]
    assert(samepath(which(char(name)),fullfile(engine,char(name+".m"))), ...
        'Wrong source resolved: %s',name);
end
assert(samepath(which('sistema'),fullfile(d.modelDir,'sistema.m')));
assert(samepath(which('limbench.angular_with_oracle'), ...
    fullfile(root,'shared','+limbench','angular_with_oracle.m')));
for name=["find_index","find_cells_around_a_cell"]
    assert(samepath(which(char(name)),fullfile(root,'shared','native',char(name+".m"))));
end
end

function checks=compare_historical(r,details,old)
a=details.query_records; b=old.details.query_records;
names=["final_radius";"query_count";"stop_status";"query_sequence_and_labels"];
passed=[abs(r.R_hat-old.row.R_hat)<=1e-10;numel(a)==numel(b); ...
    string(r.stop_status)==string(old.row.stop_status);false];
if numel(a)==numel(b)
    match=true;
    for k=1:numel(a)
        x=a{k}; y=b{k};
        match=match && norm(x.initial_state-y.initial_state,Inf)<=1e-10 && ...
            x.label==y.label && x.classification_reason==y.classification_reason && ...
            x.sample_count==y.sample_count && x.native_tipo==y.native_tipo && ...
            x.grid_cache_kind==y.grid_cache_kind && x.rhs_count==y.rhs_count && ...
            abs(x.min_radius-y.min_radius)<=1e-8 && norm(x.min_point-y.min_point,Inf)<=1e-8;
        if ~match, break; end
    end
    passed(4)=match;
end
checks=table(names,passed,'VariableNames',{'check','passed'});
end

function t=summary_row(r,id,seed,algorithmSeed,mode,reference,details,matched)
qs=details.query_records;
unsafe=cellfun(@(q) string(q.label)=="non_target",qs);
winningQuery=NaN; x0=NaN; v0=NaN; winningReason="none";
if any(unsafe)
    ids=find(unsafe); radii=cellfun(@(q) double(q.initial_radius),qs(ids));
    [best,j]=min(radii); winningQuery=ids(j); q=qs{winningQuery};
    assert(abs(best-r.R_hat)<1e-10);
    x0=q.initial_state(1); v0=q.initial_state(2); winningReason=string(q.classification_reason);
end
t=struct('model',id,'seed',seed,'algorithm_seed',algorithmSeed,'condition',mode, ...
    'R_reference',reference,'R_hat',r.R_hat, ...
    'signed_error_percent',100*(r.R_hat-reference)/reference, ...
    'absolute_error_percent',100*abs(r.R_hat-reference)/reference, ...
    'runtime_s',r.algorithm_runtime_s,'query_count',r.query_count, ...
    'ode_solver_calls',r.ode_solver_calls,'rhs_count',r.rhs_count, ...
    'target_cache_hits',r.grid_cache_target_hit_count, ...
    'non_target_cache_hits',r.grid_cache_non_target_hit_count, ...
    'domain_exit_count',r.domain_exit_count,'recurrence_count',r.recurrence_count, ...
    'forced_non_target_count',r.forced_non_target_count,'unresolved_count',r.unresolved_count, ...
    'stop_status',string(r.stop_status),'converged',r.converged, ...
    'baseline_reproduced',double(matched),'winning_query',winningQuery, ...
    'winning_x0',x0,'winning_v0',v0,'winning_reason',winningReason);
end

function t=make_comparison(id,seed,old,r,control,matched)
controlR=NaN; controlRuntime=NaN; controlRHS=NaN;
if isfield(control,'R_hat')
    controlR=control.R_hat; controlRuntime=control.algorithm_runtime_s; controlRHS=control.rhs_count;
end
ref=old.R_reference;
t=struct('model',id,'seed',seed,'R_reference',ref,'recorded_R',old.R_hat, ...
    'control_R',controlR,'no_negative_reuse_R',r.R_hat, ...
    'recorded_signed_error_percent',100*(old.R_hat-ref)/ref, ...
    'new_signed_error_percent',100*(r.R_hat-ref)/ref,'radius_change',r.R_hat-old.R_hat, ...
    'recorded_rhs',old.rhs_count,'control_rhs',controlRHS,'new_rhs',r.rhs_count, ...
    'control_runtime_s',controlRuntime,'new_runtime_s',r.algorithm_runtime_s, ...
    'new_non_target_cache_hits',r.grid_cache_non_target_hit_count, ...
    'new_target_cache_hits',r.grid_cache_target_hit_count, ...
    'new_recurrence_count',r.recurrence_count,'new_forced_non_target_count',r.forced_non_target_count, ...
    'new_unresolved_count',r.unresolved_count,'new_stop_status',string(r.stop_status), ...
    'new_converged',r.converged,'baseline_reproduced',double(matched), ...
    'time_guard_hit',string(r.stop_status)=="time_budget");
end

function status=postcheck(root,id,d,details,reference,caseOut,o)
guard=activate_condition(root,"no_negative_reuse",d); %#ok<NASGU>
qs=details.query_records; n=numel(qs);
unsafe=cellfun(@(q) string(q.label)=="non_target",qs);
if ~any(unsafe), status="no_non_target_query"; return; end
radii=cellfun(@(q) double(q.initial_radius),qs);
ids=find(unsafe); [~,i]=min(radii(ids)); win=ids(i);
first=find(unsafe & radii<reference-1e-10,1);
z=vertcat(qs{:}); points=vertcat(z.initial_state);
assert(isequal(size(points),[n,2]));
query=(1:n).'; x0=points(:,1); v0=points(:,2);
parent_query=zeros(n,1); hit_x=nan(n,1); hit_v=hit_x; donor_x=hit_x; donor_v=hit_x;
Q=table(query,x0,v0,parent_query,hit_x,hit_v,donor_x,donor_v);
trace=struct('queries',Q,'winning_chain',win,'first_under_chain',first);
row=struct('winning_query',win);
folder=fullfile(caseOut,'independent_postcheck'); mkdir(folder);
diagnostic_validate(id,d,trace,row,folder,o);
A=readtable(fullfile(folder,'independent_assessment.csv'),'TextType','string');
status=A.conclusion(A.query==win & A.role=="initial_state");
assert(isscalar(status));
end

function check_integrity(data,before,out)
after=diagnostic_hashes(data); writetable(after,fullfile(out,'original_files_after.csv'));
same=isequal(before,after);
fid=fopen(fullfile(out,'ORIGINAL_DATA_INTEGRITY.txt'),'w');
fprintf(fid,'All original source/data bytes unchanged: %d\n',same); fclose(fid);
if ~same, warning('Original files changed during execution. Inspect before interpreting results.'); end
end
function restore_environment(p,d,r)
path(p); cd(d); rng(r);
clear sampled_forward_proposed sampled_forward_classifier sampled_forward_geometry
clear sampled_forward_integrate sampled_forward_step sistema
clear('limbench.angular_with_oracle');
end
function yes=samepath(a,b)
yes=strcmpi(strrep(a,'\','/'),strrep(b,'\','/'));
end
