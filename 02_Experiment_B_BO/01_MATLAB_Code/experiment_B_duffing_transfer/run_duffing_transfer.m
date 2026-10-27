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
function outDir=run_duffing_transfer(mode,resumeDir)
% Paired cross-model test; no Bayesian optimization or candidate selection.
if nargin<1, mode='pilot'; end
if nargin<2, resumeDir=''; end
assert(any(strcmp(mode,{'pilot','full'})));
root=fileparts(mfilename('fullpath')); repo=fileparts(root);
source=fullfile(repo,'experiment_B_multi_alpha','outputs_multi_alpha_full_20261023_055518_403');
helpers=fullfile(source,'source_snapshot');
oldPath=path; oldRng=rng;
cleanup=onCleanup(@() restore(oldPath,oldRng));
addpath(root,'-begin'); addpath(helpers,'-begin');
for name={'ma_job','ma_design','ma_report','ma_io'}
    assert(strcmpi(which(name{1}),fullfile(helpers,[name{1} '.m'])));
end
assert(strcmpi(which('duffing_transfer_reference'),fullfile(root,'duffing_transfer_reference.m')));
assert(isfile(fullfile(source,'study_finished.mat')),'Source BO study is not complete.');
frozen=load(fullfile(source,'frozen_candidate.mat'));
original=load(fullfile(source,'definition.mat'));
assert(strcmp(original.options.model,'quadratic_cubic') && frozen.selectedBeforeValidation);
x=frozen.winner; bx=ma_design('baseline');
assert(isequal(size(x),[1 8]) && all(x(1:7)==[5 1012 7 20 12 3 171]));
assert(abs(x(8)-0.0920905251923764)<1e-15);
o=struct('mode',mode,'model','bistable_duffing','alpha',(1:40)/20, ...
    'seeds',110101:110110,'pairOrderSeed',110001,'numWorkers',6);
if strcmp(mode,'full'), o.seeds=110101:110200; end
assert(isempty(intersect(o.seeds,[original.options.trainSeeds original.options.validationSeeds])));
native=fullfile(helpers,'native');
definition=struct('options',o,'winner',x,'baseline',bx,'source',source, ...
    'sourceSignature',ma_io('signature',helpers,native), ...
    'runnerHash',ma_io('hash',uint8(fileread([mfilename('fullpath') '.m']))), ...
    'referenceHash',ma_io('hash',uint8(fileread(fullfile(root,'duffing_transfer_reference.m')))), ...
    'matlabVersion',version);
if isempty(resumeDir)
    outDir=fullfile(root,['outputs_duffing_transfer_' mode '_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
    mkdir(outDir); mkdir(fullfile(outDir,'records')); mkdir(fullfile(outDir,'source_snapshot'));
    ma_io('save',fullfile(outDir,'definition.mat'),definition);
    copyfile(fullfile(root,'*.m'),fullfile(outDir,'source_snapshot'));
    copyfile(fullfile(root,'*.py'),fullfile(outDir,'source_snapshot'));
    copyfile(fullfile(source,'frozen_candidate.mat'),fullfile(outDir,'frozen_candidate.mat'));
else
    [ok,attr]=fileattrib(resumeDir); assert(ok && attr.directory);
    outDir=attr.Name; saved=load(fullfile(outDir,'definition.mat'));
    assert(isequaln(saved,definition),'Code/options/source changed. Start a new output folder.');
end
fprintf('\nDUFFING TRANSFER %s\n%s\n',upper(mode),outDir);
fprintf('%d alpha values x %d shared seeds x 2 profiles = %d runs; no retuning.\n', ...
    numel(o.alpha),numel(o.seeds),2*numel(o.alpha)*numel(o.seeds));
for role={'baseline','candidate'}
    v=bx; if strcmp(role{1},'candidate'), v=x; end
    writetable(struct2table(ma_design('config',v,o.model)),fullfile(outDir,[role{1} '_parameters.csv']));
end
refFile=fullfile(outDir,'references.mat');
if isfile(refFile)
    saved=load(refFile); reference=saved.reference;
else
    fprintf('Computing Figure 9 analytical envelope and independent reference checks...\n');
    dense=unique([linspace(.05,2,391) .6878800931 o.alpha]);
    values=zeros(size(dense)); audits=cell(numel(dense),1);
    for j=1:numel(dense)
        [values(j),audits{j}]=duffing_transfer_reference(dense(j));
        if mod(j,50)==0 || j==numel(dense)
            fprintf('Analytical reference: %d/%d alpha values checked.\n',j,numel(dense));
        end
    end
    [found,ix]=ismember(o.alpha,dense); assert(all(found)); reference=values(ix);
    [check,~]=duffing_transfer_reference(.7);
    assert(abs(check-.7289278591561151)<1e-9,'Duffing reference regression failed.');
    writetable(table(dense',values','VariableNames',{'alpha','reference_LIM'}),fullfile(outDir,'analytical_curve.csv'));
    writetable(vertcat(audits{:}),fullfile(outDir,'reference_audit.csv'));
    ma_io('save',refFile,struct('reference',reference));
end
if ~isfile(fullfile(outDir,'study_finished.mat'))
    assert(license('test','Distrib_Computing_Toolbox'),'Parallel Computing Toolbox required.');
    pool=gcp('nocreate');
    if isempty(pool)
        cluster=parcluster('Processes'); cluster.NumThreads=1;
        assert(cluster.NumWorkers>=o.numWorkers); pool=parpool(cluster,o.numWorkers);
    end
    assert(isa(pool,'parallel.ProcessPool') && isa(pool.Cluster,'parallel.cluster.Local') ...
        && pool.NumWorkers==o.numWorkers,'Use a local process pool with six workers.');
    execution=struct('workers',pool.NumWorkers,'threads_per_worker',1,'host',string(getenv('COMPUTERNAME')));
    executionFile=fullfile(outDir,'execution.mat');
    if isfile(executionFile)
        previous=load(executionFile); assert(isequaln(previous.execution,execution));
    else
        ma_io('save',executionFile,struct('execution',execution));
    end
    c=struct('options',o,'root',helpers,'native',native,'modelDir',fullfile(helpers,'model'), ...
        'outDir',outDir,'bx',bx,'target',[-1 0]);
    [ai,si]=ndgrid(1:numel(o.alpha),1:numel(o.seeds)); ai=ai(:); si=si(:);
    rng(o.pairOrderSeed,'twister'); first=randi(2,numel(ai),1);
    alphaColumn=reshape(o.alpha(ai),[],1); seedColumn=reshape(o.seeds(si),[],1);
    schedule=table(alphaColumn,seedColumn,first,'VariableNames',{'alpha','seed','first_profile'});
    writetable(schedule,fullfile(outDir,'pair_schedule.csv'));
    n=numel(ai); cells=cell(n,1); completed=0; clock=tic;
    refColumn=reshape(reference(ai),[],1);
    queue=parallel.pool.DataQueue; afterEach(queue,@progress);
    fprintf('Running %d pairs. Each pair is checkpointed; warm-ups are outside timers.\n',n);
    parfor j=1:n
        a=alphaColumn(j); seed=seedColumn(j);
        file=fullfile(outDir,'records',sprintf('a%03d_seed%d.mat',ai(j),seed));
        cells{j}=ma_job(c,x,a,refColumn(j),seed,'validation',first(j),file);
        send(queue,j);
    end
    T=struct2table(vertcat(cells{:})); T=sortrows(T,{'alpha','seed','role'});
    writetable(T,fullfile(outDir,'transfer_raw.csv'));
    writetable(ma_report('profile',T),fullfile(outDir,'summary_by_alpha_and_profile.csv'));
    [C,P]=ma_report('compare',T);
    writetable(C(2:end,:),fullfile(outDir,'comparison_by_alpha.csv'));
    writetable(C(1,:),fullfile(outDir,'comparison_overall.csv'));
    writetable(P,fullfile(outDir,'paired_comparison.csv'));
    ma_io('save',fullfile(outDir,'study_finished.mat'), ...
        struct('completedAt',string(datetime('now')),'failedRuns',sum(~T.success)));
    fprintf('Saved %d runs; failures=%d.\n',height(T),sum(~T.success));
end
python=fullfile(getenv('USERPROFILE'),'.cache','codex-runtimes','codex-primary-runtime','dependencies','python','python.exe');
oldPythonPath=getenv('PYTHONPATH'); envCleanup=onCleanup(@() setenv('PYTHONPATH',oldPythonPath));
setenv('PYTHONPATH',[fullfile(repo,'.thesis_abc_plot_dependencies') pathsep oldPythonPath]);
if isfile(python)
    command=sprintf('"%s" "%s" "%s"',python,fullfile(root,'plot_duffing_transfer.py'),outDir);
    [status,message]=system(command); fprintf('%s\n',message);
    if status~=0, warning('Numerical results saved; Python plot failed. Run plot_duffing_transfer.py separately.'); end
else
    warning('Numerical results saved; configure Python and run plot_duffing_transfer.py on the output folder.');
end
fprintf('Read comparison_overall.csv, comparison_by_alpha.csv and duffing_transfer.png.\n');

    function progress(~)
        completed=completed+1;
        if mod(completed,10)==0 || completed==n
            fprintf('Completed/loaded %d/%d pairs; elapsed %.1f min.\n',completed,n,toc(clock)/60);
        end
    end
end

function restore(p,r)
path(p); rng(r);
end
