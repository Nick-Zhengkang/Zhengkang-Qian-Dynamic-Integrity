function rows=ma_job(c,x,alpha,reference,seed,phase,first,file)
% Every task is one alpha/seed, or one consecutive baseline/candidate pair.
paired=strcmp(phase,'validation'); X=x; roles="candidate";
if paired, X=[c.bx;x]; roles=["baseline";"candidate"]; end
if strcmp(phase,'baseline_train'), roles="baseline"; end
if isfile(file)
    saved=load(file); rows=saved.rows;
    assert(isequal(saved.X,X) && saved.alpha==alpha && saved.seed==seed ...
        && strcmp(saved.phase,phase) && saved.first==first);
    assert(numel(rows)==size(X,1) && all([rows.reference_LIM]==reference));
    return
end
oldPath=path; oldFolder=pwd; oldRng=rng; oldThreads=maxNumCompThreads;
cleanup=onCleanup(@() restore(oldPath,oldFolder,oldRng,oldThreads));
maxNumCompThreads(1);
addpath(c.root,'-begin'); addpath(c.modelDir,'-begin'); addpath(c.native,'-begin');
cd(c.native);
persistent warmedStudy
needsWarm=isempty(warmedStudy) || ~strcmp(warmedStudy,c.outDir);
if needsWarm
    clear compute_LIM_FP simulation_DI sys_solver sistema
    rehash;
end
for name={'compute_LIM_FP','simulation_DI','sys_solver','find_cells_around_a_cell'}
    assert(strcmpi(which(name{1}),fullfile(c.native,[name{1} '.m'])), ...
        'Wrong native function: %s',name{1});
end
assert(strcmpi(which('sistema'),fullfile(c.modelDir,'sistema.m')),'Wrong active physical model.');
par=struct('alpha',alpha,'model',c.options.model);
if needsWarm
    warm=ma_design('config',c.bx,c.options.model); warm.number_of_steps=2;
    vals=arguments_for(warm); rng(109901,'twister');
    R=compute_LIM_FP(c.target,par,vals{:});
    assert(isscalar(R) && isfinite(R),'Worker warm-up failed.');
    warmedStudy=c.outDir;
end
order=1:size(X,1); if paired && first==2, order=[2 1]; end
cells=cell(size(X,1),1);
for position=1:numel(order)
    j=order(position); cfg=ma_design('config',X(j,:),c.options.model);
    vals=arguments_for(cfg); rng(100000+seed,'twister');
    row=struct('phase',string(phase),'role',roles(j),'config_id',string(ma_design('key',X(j,:))), ...
        'alpha',alpha,'seed',seed,'rng_seed',100000+seed,'order_in_pair',position, ...
        'reference_LIM',reference,'R_hat',NaN,'success',false, ...
        'absolute_error',NaN,'relative_error_percent',NaN,'signed_relative_error_percent',NaN, ...
        'core_wall_time_s',NaN,'core_cpu_time_s',NaN,'trajectory_evaluations',NaN, ...
        'internal_unresolved_count',NaN,'error_message',"");
    R=NaN; OutL=struct(); cpuStart=cputime; wallStart=tic;
    try
        [R,OutL,~]=compute_LIM_FP(c.target,par,vals{:});
        row.core_wall_time_s=toc(wallStart); row.core_cpu_time_s=cputime-cpuStart;
    catch ME
        row.core_wall_time_s=toc(wallStart); row.core_cpu_time_s=cputime-cpuStart;
        row.error_message=string(getReport(ME,'basic','hyperlinks','off'));
    end
    row.success=isscalar(R) && isfinite(R) && R>=0 && strlength(row.error_message)==0;
    if row.success
        row.R_hat=R; row.absolute_error=abs(R-reference);
        row.relative_error_percent=100*row.absolute_error/reference;
        row.signed_relative_error_percent=100*(R-reference)/reference;
    elseif strlength(row.error_message)==0
        row.error_message="Invalid LIM returned by native solver.";
    end
    if isfield(OutL,'tipo')
        row.trajectory_evaluations=nnz(isfinite(OutL.tipo) & OutL.tipo~=0);
        row.internal_unresolved_count=nnz(isfinite(OutL.tipo) & OutL.tipo==0);
    end
    cells{j}=row;
end
rows=vertcat(cells{:});
ma_io('save',file,struct('rows',rows,'X',X,'alpha',alpha,'seed',seed,'phase',phase,'first',first));
end

function vals=arguments_for(cfg)
order=ma_design('order'); vals=cell(size(order));
for j=1:numel(order), vals{j}=cfg.(order{j}); end
end

function restore(p,f,r,t)
path(p); cd(f); rng(r); maxNumCompThreads(t);
end
