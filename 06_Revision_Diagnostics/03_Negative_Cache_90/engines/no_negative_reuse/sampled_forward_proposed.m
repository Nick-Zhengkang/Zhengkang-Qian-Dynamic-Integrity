function [out,details]=sampled_forward_proposed(p,c,s,api,seed)
rng(seed,'twister'); records=cell(0,1); coreTimer=tic;
if numel(p.target)==4, timeLimit=c.maxWallSeconds; else, timeLimit=s.maxSeconds; end
native=sampled_forward_classifier(c.nativeConfig,@() toc(coreTimer)<timeLimit);
c.classifierOverride=native.classify;
if numel(p.target)==4
    [r,details]=api.search(p,c,"adaptive_s3_radial",seed);
    % A zero-direction audit in the frozen engine is vacuously marked pass.
    % This experiment does not run that audit; never save it as validation.
    assert(r.post_audit_query_count==0 && r.post_audit_integration_count==0);
    r.post_audit_pass=false; r.post_audit_status="not_run_disabled";
    r.post_audit_R_hat=NaN; r.post_audit_relative_drop=NaN;
    details.audit_status="not_run_disabled"; details.post_audit_R_hat=NaN;
    out=struct('R_hat',r.R_hat,'algorithm_runtime_s',r.algorithm_runtime_s, ...
        'query_count',r.query_count,'ode_solver_calls',r.integration_count, ...
        'direction_count',r.direction_count,'unresolved_count',r.unresolved_count, ...
        'stop_status',r.stop_status,'converged',r.stop_status=="converged_local_and_global");
    records=details.query_records;
    details.result=r;
else
    [r,history,queries]=limbench.angular_with_oracle(p,s,@oracle);
    details=struct('result',r,'history',history,'queries',queries,'query_records',{records});
    out=struct('R_hat',r.R,'algorithm_runtime_s',r.runtime, ...
        'query_count',r.queries,'ode_solver_calls',0,'direction_count',r.directions, ...
        'unresolved_count',r.unknown,'stop_status',string(r.reason), ...
        'converged',string(r.reason)=="heuristic_plateau_with_coverage");
end
out.algorithm_runtime_s=toc(coreTimer);
out.forced_non_target_count=0;
out.trajectory_count=0; out.retry_count=0; out.rhs_count=0; out.sample_check_count=0;
out.target_query_count=0; out.non_target_query_count=0;
out.domain_exit_count=0; out.recurrence_count=0; out.initial_outside_count=0;
out.ode_failure_count=0; out.grid_cache_hit_count=0;
out.grid_cache_target_hit_count=0; out.grid_cache_non_target_hit_count=0;
odeCalls=0;
for k=1:numel(records)
    q=records{k};
    odeCalls=odeCalls+q.integration_count;
    out.trajectory_count=out.trajectory_count+(q.integration_count>0);
    out.retry_count=out.retry_count+q.retried;
    out.forced_non_target_count=out.forced_non_target_count+q.forced_non_target;
    out.rhs_count=out.rhs_count+q.rhs_count;
    out.sample_check_count=out.sample_check_count+max(0,q.sample_count-1);
    out.target_query_count=out.target_query_count+(q.label=="target");
    out.non_target_query_count=out.non_target_query_count+(q.label=="non_target");
    out.domain_exit_count=out.domain_exit_count+(q.classification_reason=="left_computational_domain");
    out.initial_outside_count=out.initial_outside_count+(q.classification_reason=="initial_state_outside_domain");
    out.recurrence_count=out.recurrence_count+contains(q.classification_reason,"recurrence");
    out.ode_failure_count=out.ode_failure_count+startsWith(q.classification_reason,"ode_failure");
    out.grid_cache_hit_count=out.grid_cache_hit_count+q.grid_cache_hit;
    out.grid_cache_target_hit_count=out.grid_cache_target_hit_count+(q.grid_cache_hit && q.label=="target");
    out.grid_cache_non_target_hit_count=out.grid_cache_non_target_hit_count+(q.grid_cache_hit && q.label=="non_target");
    if q.classification_reason=="wall_guard_before_native_query"
        out.stop_status="time_budget"; out.converged=false;
    end
end
cacheInfo=native.stats();
out.cached_target_cells=cacheInfo.target;
out.cached_non_target_cells=cacheInfo.non_target;
out.cached_exit_cells=cacheInfo.exit;
details.grid_cache_summary=cacheInfo;
assert(numel(records)==out.query_count);
assert(out.target_query_count+out.non_target_query_count+out.unresolved_count==out.query_count);
if numel(p.target)==4, assert(out.ode_solver_calls==odeCalls); end
out.ode_solver_calls=odeCalls;
if numel(p.target)==2
    % Keep trajectory counts tied to actual solver calls, including rejected queries.
    integrated=cellfun(@(q) q.integration_count>0,records);
    cumulative=[0;cumsum(integrated)];
    details.history.ode_trajectories=cumulative(details.history.traj_evals+1);
    details.result.odeCalls=out.trajectory_count;
end
details.result.actual_ode_solver_calls=odeCalls;
details.result.core_runtime_including_cache_setup_s=out.algorithm_runtime_s;
if numel(p.target)==4
    details.result.stop_status=out.stop_status; details.stop_status=out.stop_status;
else
    details.result.reason=out.stop_status;
end
out.estimate_available=isfinite(out.R_hat);
out.valid_estimate=out.estimate_available && out.unresolved_count==0 && out.ode_failure_count==0;
    function [label,nrhs,tend]=oracle(z)
        [q,~]=native.classify(z,p,c);
        q.query_id=numel(records)+1; q.initial_state=z;
        q.initial_radius=sqrt(sum((z-p.target).^2.*p.weight));
        records{end+1,1}=q;
        label=0;
        if q.label=="target", label=1; elseif q.label=="non_target", label=2; end
        nrhs=q.rhs_count; tend=q.end_time;
    end
end


