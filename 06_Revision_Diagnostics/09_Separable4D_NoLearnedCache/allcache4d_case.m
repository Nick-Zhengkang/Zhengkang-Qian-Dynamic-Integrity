function row=allcache4d_case(root,out,seed,o)
% AI-assisted paired control/ablation, endpoint validation and label audit.
caseOut=fullfile(out,sprintf('seed_%02d',seed)); mkdir(caseOut);
o.seed=seed;
row=struct('seed',seed,'algorithm_seed',NaN,'reference',NaN, ...
    'original_midpoint',NaN,'previous_midpoint',NaN,'control_matches',false,'repair_completed',false, ...
    'repaired_midpoint',NaN,'repaired_lower',NaN,'repaired_upper',NaN, ...
    'bracket_width',NaN,'midpoint_below_reference',false,'upper_below_reference',false, ...
    'midpoint_error_percent',NaN,'upper_error_percent',NaN,'query_count',NaN, ...
    'unresolved_count',NaN,'forced_non_target_count',NaN,'direct_exit_count',NaN, ...
    'recurrence_count',NaN,'negative_cache_hits',NaN,'learned_target_cache_hits',NaN, ...
    'native_target_neighbourhood_hits',NaN,'stop_status',"not_run", ...
    'previous_lower_reclassified',"not_run",'previous_lower_reason',"not_run", ...
    'previous_lower_independent',"not_run",'previous_lower_agrees',false, ...
    'upper_query',NaN,'upper_reason',"not_run",'lower_validation',"not_run", ...
    'upper_validation',"not_run",'midpoint_validation',"not_run", ...
    'provenance_matches',false,'chain_contradictions',NaN,'chain_unresolved',NaN, ...
    'endpoint_checks_pass',false, ...
    'control_runtime_s',NaN,'repair_runtime_s',NaN,'error_message',"");
oldpath=path; oldrng=rng;
cleanup=onCleanup(@() restore(oldpath,oldrng)); %#ok<NASGU>
addpath(root,fullfile(root,'engine'),fullfile(root,'native'),fullfile(root,'model'),'-begin');
try
    assert(strcmp(which('sistema'),fullfile(root,'model','sistema.m')));
    assert(strcmp(which('sampled_forward_integrate'),fullfile(root,'engine','sampled_forward_integrate.m')));
    assert(strcmp(which('sampled_forward_classifier'),fullfile(root,'engine','sampled_forward_classifier.m')));
    assert(strcmp(which('noneg4d_classifier'),fullfile(root,'noneg4d_classifier.m')));
    assert(strcmp(which('allcache4d_classifier'),fullfile(root,'allcache4d_classifier.m')));
    assert(strcmp(which('run_separable_4d_analytic_benchmark'),fullfile(root,'engine','run_separable_4d_analytic_benchmark.m')));
    settings=load(fullfile(root,'input','separable_qc_bd_4d_settings.mat'));
    d=settings.dynin; d.modelDir=fullfile(root,'model');
    p=settings.problem; c=settings.proposedClassifier; c.nativeConfig=d;
    assert(c.postAuditDirections==0 && c.postAuditBudget==0);
    saved=load(fullfile(root,'input','runs', ...
        sprintf('separable_qc_bd_4d__proposed_sampled_forward__seed_%d.mat',seed)));
    assert(saved.row.seed==seed);
    row.algorithm_seed=saved.row.algorithm_seed;
    row.reference=saved.row.R_reference; row.original_midpoint=saved.row.R_hat;
    prior=load(fullfile(root,'input','no_negative_cache_baseline',sprintf('seed_%02d.mat',seed)));
    expected=struct('row',prior.repaired,'details',prior.details);
    assert(prior.details.seed==row.algorithm_seed,'Baseline seed mismatch.');
    assert(isequaln(prior.p,p),'Saved baseline problem changed.');
    priorD=prior.d; priorD.modelDir=d.modelDir;
    priorC=prior.c; priorC.nativeConfig=d;
    assert(isequaln(priorD,d) && isequaln(priorC,c),'Saved baseline controls differ.');
    row.previous_midpoint=prior.repaired.R_hat;
    controlDir=fullfile(caseOut,'control'); mkdir(controlDir);
    [control,controlDetails]=search(p,c,d,false,row.algorithm_seed);
    save(fullfile(controlDir,'search.mat'),'control','controlDetails','p','c','d','-v7.3');
    check=allcache4d_compare(control,controlDetails,expected);
    writetable(check,fullfile(controlDir,'query_reproduction.csv'));
    row.control_matches=all(check.matches) && height(check)==numel(prior.details.query_records);
    row.control_runtime_s=control.algorithm_runtime_s;
    assert(row.control_matches,'Previous no-negative-cache search did not reproduce; repair was not run.');
    repairedDir=fullfile(caseOut,'no_learned_cache'); mkdir(repairedDir);
    [repaired,details]=search(p,c,d,true,row.algorithm_seed);
    save(fullfile(repairedDir,'search.mat'),'repaired','details','p','c','d','-v7.3');
    row.repair_runtime_s=repaired.algorithm_runtime_s;
    row.repair_completed=true; row.repaired_midpoint=repaired.R_hat;
    row.query_count=repaired.query_count; row.unresolved_count=repaired.unresolved_count;
    row.stop_status=repaired.stop_status;
    Q=allcache4d_query_table(details.query_records);
    writetable(Q,fullfile(repairedDir,'queries.csv'));
    writetable(groupsummary(Q,'reason'),fullfile(repairedDir,'classification_reason_counts.csv'));
    row.forced_non_target_count=sum(Q.forced_non_target);
    row.direct_exit_count=sum(Q.reason=="left_computational_domain");
    row.recurrence_count=sum(Q.reason=="native_non_target_recurrence");
    row.negative_cache_hits=sum(Q.cache_kind==2 | Q.cache_kind==3);
    row.learned_target_cache_hits=sum(Q.cache_kind==1);
    row.native_target_neighbourhood_hits=sum(Q.reason=="native_target_neighbourhood");
    assert(row.negative_cache_hits==0 && row.learned_target_cache_hits==0, ...
        'A learned grid label was read despite the ablation.');
    % The old reference is used ONLY after searches, never by either oracle.
    [selection,P]=allcache4d_endpoints(details,p,seed,repaired.R_hat,row.reference);
    writetable(struct2table(selection),fullfile(repairedDir,'endpoint_summary.csv'));
    if ~isfinite(repaired.R_hat)
        error('No finite repaired estimate. Search and query records were saved.');
    end
    row.repaired_lower=selection.lower; row.repaired_upper=selection.upper;
    row.bracket_width=selection.upper-selection.lower;
    row.midpoint_below_reference=selection.midpoint<row.reference-1e-10;
    row.upper_below_reference=selection.upper<row.reference-1e-10;
    row.midpoint_error_percent=100*abs(selection.midpoint-row.reference)/row.reference;
    row.upper_error_percent=100*abs(selection.upper-row.reference)/row.reference;
    row.upper_query=selection.upper_query; row.upper_reason=Q.reason(selection.upper_query);
    validationDir=fullfile(repairedDir,'validation'); mkdir(validationDir);
    A=allcache4d_validate(d,P,validationDir,o);
    row.lower_validation=A.conclusion(A.role=="winning_lower");
    row.upper_validation=A.conclusion(A.role=="winning_upper");
    row.midpoint_validation=A.conclusion(A.role=="reported_midpoint");
    % Recheck the preceding no-negative-cache endpoints with the same rules.
    [~,oldPoints]=allcache4d_endpoints(controlDetails,p,seed,control.R_hat,row.reference);
    oldValidation=fullfile(controlDir,'validation'); mkdir(oldValidation);
    oldAssessment=allcache4d_validate(d,oldPoints,oldValidation,o);
    lowerPoint=oldPoints(oldPoints.role=="winning_lower",:);
    regressionDir=fullfile(caseOut,'previous_lower_regression'); mkdir(regressionDir);
    reg=allcache4d_regression(d,lowerPoint,regressionDir);
    row.previous_lower_reclassified=reg.label;
    row.previous_lower_reason=reg.reason;
    row.previous_lower_independent=oldAssessment.conclusion(oldAssessment.role=="winning_lower");
    row.previous_lower_agrees=(reg.label=="target" && ...
        row.previous_lower_independent=="both_solvers_support_target") || ...
        (reg.label=="non_target" && row.previous_lower_independent=="both_solvers_support_non_target");
    provenanceDir=fullfile(repairedDir,'provenance'); mkdir(provenanceDir);
    trace=allcache4d_provenance(d,details.query_records,selection,provenanceDir,o);
    row.provenance_matches=trace.reproduced;
    if trace.reproduced
        chainPoints=allcache4d_chain_points(trace);
        chainDir=fullfile(provenanceDir,'validation'); mkdir(chainDir);
        chainAssessment=allcache4d_validate(d,chainPoints,chainDir,o);
        row.chain_contradictions=sum(chainAssessment.original_label_contradicted);
        row.chain_unresolved=sum(chainAssessment.conclusion=="unresolved_or_solver_disagreement");
    end
    row.endpoint_checks_pass=row.control_matches && row.provenance_matches && ...
        ~row.upper_below_reference && row.unresolved_count==0 && ...
        ~contains(row.stop_status,"wall") && ~contains(row.stop_status,"time") && ...
        row.upper_validation=="both_solvers_support_non_target" && ...
        row.lower_validation=="both_solvers_support_target" && ...
        row.chain_contradictions==0 && row.chain_unresolved==0;
catch err
    row.error_message=string(getReport(err,'extended','hyperlinks','off'));
    fid=fopen(fullfile(caseOut,'ERROR.txt'),'w');
    if fid>=0, fprintf(fid,'%s\n',row.error_message); fclose(fid); end
end
writetable(struct2table(row),fullfile(caseOut,'case_summary.csv'));
fprintf('Seed %d finished. Control=%d, endpoint checks=%d, upper=%s\n', ...
    seed,row.control_matches,row.endpoint_checks_pass,row.upper_validation);
end

function [result,details]=search(p,c,d,repaired,seed)
rng(seed,'twister'); timer=tic;
if repaired, oracle=allcache4d_classifier(d,@() toc(timer)<c.maxWallSeconds);
else, oracle=noneg4d_classifier(d,@() toc(timer)<c.maxWallSeconds); end
api=run_separable_4d_analytic_benchmark("refinement_api");
c.classifierOverride=oracle.classify;
[result,details]=api.search(p,c,"adaptive_s3_radial",seed);
assert(result.post_audit_query_count==0 && result.post_audit_integration_count==0);
result.post_audit_pass=false; result.post_audit_status="not_run_disabled";
result.post_audit_R_hat=NaN; result.post_audit_relative_drop=NaN;
details.audit_status="not_run_disabled"; details.post_audit_R_hat=NaN;
result.algorithm_runtime_s=toc(timer);
details.result=result; details.grid_cache_summary=oracle.stats();
end

function restore(p,r)
path(p); rng(r);
end
