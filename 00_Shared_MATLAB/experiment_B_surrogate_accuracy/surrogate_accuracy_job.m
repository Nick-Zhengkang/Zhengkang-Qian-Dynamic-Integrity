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
function rows=surrogate_accuracy_job(c,x,seed,phase,tag,order,file)
% A worker owns one seed, or one complete confirmation pair.
paired=strcmp(phase,'confirmation');
X=x; roles="candidate";
if paired
    X=[c.bx;x]; roles=["baseline";"candidate"];
elseif strcmp(phase,'baseline')
    roles="baseline";
end
assert(isequal(sort(order),1:size(X,1)));
if isfile(file)
    a=load(file,'rows'); rows=a.rows;
    assert(numel(rows)==size(X,1) && all([rows.seed]==seed));
    for j=1:size(X,1)
        assert(rows(j).config_id==string(bayes_A_design('key',X(j,:))));
        assert(rows(j).phase==string(phase) && rows(j).evaluation_id==string(tag));
        assert(rows(j).execution_order==find(order==j));
    end
    return
end
cells=cell(size(X,1),1);
for pos=1:numel(order)
    j=order(pos);
    cells{j}=execute_one(c,X(j,:),seed,phase,tag,roles(j),pos);
end
rows=vertcat(cells{:});
surrogate_accuracy_util('save',file,struct('rows',rows));
end

function row=execute_one(c,x,seed,phase,tag,role,order)
cfg=bayes_A_design('config',x,c.base);
old=rng; cleanup=onCleanup(@() rng(old));
rng(100000+seed,'twister');
if c.options.synthetic
    z=(x-c.options.lower)./(c.options.upper-c.options.lower);
    e=.001+.02*sum((z-.35).^2)+rand*1e-5;
    result=struct('success',true,'R_hat',c.base.reference_LIM+e, ...
        'wall_runtime_s',1+sum(z),'algorithm_runtime_s',1+sum(z), ...
        'trajectory_evaluations',100,'internal_unresolved_count',0,'error_message',"");
else
    result=original_A_adapter('execute',cfg,c.base);
end
row=cfg;
row.config_id=string(bayes_A_design('key',x));
row.seed=seed; row.phase=string(phase); row.evaluation_id=string(tag);
row.role=role; row.execution_order=order;
row.worker_task_id=0;
if c.options.useParallel
    task=getCurrentTask();
    assert(~isempty(task),'Expected a process worker.');
    row.worker_task_id=task.ID;
end
row.saved_at=string(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSS'));
row.synthetic=c.options.synthetic; row.reference_LIM=c.base.reference_LIM;
row.success=result.success; row.R_hat=result.R_hat;
row.absolute_error=abs(result.R_hat-c.base.reference_LIM);
row.relative_error_percent=100*row.absolute_error/c.base.reference_LIM;
row.core_wall_time_s=result.wall_runtime_s;
row.algorithm_runtime_s=result.algorithm_runtime_s;
row.trajectory_evaluations=result.trajectory_evaluations;
row.internal_unresolved_count=result.internal_unresolved_count;
row.error_message=string(result.error_message);
% Time never affects the score or eligibility.
row.valid_for_score=row.success && isfinite(row.absolute_error);
end
