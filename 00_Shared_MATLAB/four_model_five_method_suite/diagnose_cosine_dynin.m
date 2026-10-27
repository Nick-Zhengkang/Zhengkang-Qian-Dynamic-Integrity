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
function outDir=diagnose_cosine_dynin()
% Diagnose saved runs, then change ONE parameter at a time. No source edits.
root=fileparts(mfilename('fullpath'));
inputDir=fullfile(root,'outputs_four_model_five_method_genda_cosine_quadratic_drag_20260914_015731_299');
run_sensitivity=true; % false: inspect existing traces only (fast).
seeds=1:3;
outDir=fullfile(root,['diagnostic_cosine_' datestr(now,'yyyymmdd_HHMMSS')]);
mkdir(outDir);
oldPath=path; oldDir=pwd;
cleanup=onCleanup(@()restore(oldPath,oldDir)); %#ok<NASGU>
addpath(fullfile(root,'dynin_original'),'-begin');
addpath(fullfile(inputDir,'model'),'-begin');
clear sistema compute_LIM_FP simulation_DI
assert(strcmpi(which('sistema'),fullfile(inputDir,'model','sistema.m')),'Wrong sistema path.');
fprintf('Model: %s\nDynIn: %s\n',which('sistema'),which('compute_LIM_FP'));
raw=readtable(fullfile(inputDir,'raw_data_all_runs.csv'));
assert(all(abs(raw.alpha-.05)<1e-12),'Expected alpha=.05.');
Rref=raw.R_ref(1); % Reporting only; never passed to DynIn.
par=struct('alpha',.05,'a',1);
summary=cell(0,10);
for seed=seeds
    file=fullfile(inputDir,sprintf('baseline_trace_alpha_0.05_seed_%02d.mat',seed));
    assert(isfile(file),'Missing saved trace: %s',file);
    S=load(file,'OutL_dynin','args_dynin');
    assert(S.args_dynin.type_x0==2 && S.args_dynin.use_adaptive_grid==0);
    T=audit(S.OutL_dynin,S.args_dynin);
    writetable(T,fullfile(outDir,sprintf('saved_iterations_seed_%02d.csv',seed)));
    bad=find(T.proven_safe_but_non_target,1);
    fprintf('\nSeed %d: %d energy-certified safe points labelled non-target.\n',seed,sum(T.proven_safe_but_non_target));
    if ~isempty(bad)
        disp(T(bad,{'iteration','tipo','x','v','energy','R_before','R_after','elapsed_physical_time'}));
        fprintf('tipo 4 = new solution; tipo 2 = known non-target OR automatic timeout.\n');
    end
    summary(end+1,:)=summarize('saved',seed,S.OutL_dynin,T,Rref,NaN,''); %#ok<AGROW>
    fig=figure('Visible','off','Color','w');
    tiledlayout(2,1);
    nexttile; plot(0:height(T),S.OutL_dynin.R(1:height(T)+1),'-o');
    yline(Rref,'--','Reference (reporting only)'); ylabel('LIM'); xlabel('Iteration');
    nexttile; scatter(T.iteration,T.energy,25,T.tipo,'filled');
    yline(1,'--','Barrier energy'); ylabel('Initial energy'); xlabel('Iteration'); colorbar;
    exportgraphics(fig,fullfile(outDir,sprintf('saved_seed_%02d.png',seed)),'Resolution',160); close(fig);
    if ~run_sensitivity, continue; end
    names={'baseline_repeat','longer_horizon','suppress_periodic_detection', ...
        'suppress_fixed_detection','larger_target_neighbourhood'};
    for k=1:numel(names)
        a=S.args_dynin;
        switch names{k}
            case 'longer_horizon', a.tfinal=4*a.tfinal;
            case 'suppress_periodic_detection', a.rep_periodic=ceil(a.tfinal/a.Ts)+10;
            case 'suppress_fixed_detection', a.rep_fix_point=ceil(a.tfinal/a.Ts)+10;
            case 'larger_target_neighbourhood', a.num_of_cell_around_equilibrium=11;
        end
        % Large repetition counts disable one detector for diagnosis only.
        % This is NOT a recommended production parameter profile.
        f=fieldnames(a); vals=struct2cell(a); nv=reshape([f vals].',1,[]);
        rng(seed,'twister'); timer=tic;
        fprintf('Running seed %d / %s ...\n',seed,names{k});
        try
            [R,L,H]=compute_LIM_FP([0 0],par,nv{:}); elapsed=toc(timer);
            A=audit(L,a);
            save(fullfile(outDir,sprintf('%s_seed_%02d.mat',names{k},seed)),'R','L','H','a','elapsed');
            writetable(A,fullfile(outDir,sprintf('%s_seed_%02d.csv',names{k},seed)));
            summary(end+1,:)=summarize(names{k},seed,L,A,Rref,elapsed,''); %#ok<AGROW>
            fprintf('R=%.9f; false-safe labels=%d\n',R,sum(A.proven_safe_but_non_target));
        catch ME
            summary(end+1,:)={names{k},seed,NaN,NaN,NaN,NaN,NaN,NaN,toc(timer),ME.message}; %#ok<AGROW>
            warning('Diagnostic variant failed: %s',ME.message);
        end
        write_summary(summary,outDir);
    end
end
write_summary(summary,outDir);
fprintf('\nSend diagnostic_summary.csv and saved_iterations_seed_*.csv from:\n%s\n',outDir);
fprintf(['Energy E=v^2/2-cos(x); E<1 inside |x|<pi certifies trapping.\n' ...
    'tipo=4 conflicts with trapping if it claims another attractor in this well.\n' ...
    'tipo=2 alone cannot distinguish inherited labels from timeout.\n' ...
    'Compare one-parameter variants; improvements do not alone prove causality.\n']);
end

function T=audit(L,a)
n=numel(L.tipo); x=L.x0(1:n,1); v=L.x0(1:n,2);
energy=v.^2/2-cos(x);
safe=abs(x)<pi & energy<1-1e-9;
tipo=L.tipo(:); before=L.R(1:n); after=L.R(2:n+1);
physical=max(0,L.time_steps_sim(:)-1)*a.Ts;
% Original simulation's reported time vector starts at Ts, so use count-1.
nearLimit=physical>=a.tfinal-a.Ts;
falseLabel=safe & tipo>=2;
T=table((1:n)',x,v,energy,tipo,before(:),after(:),physical,nearLimit,safe,falseLabel, ...
    'VariableNames',{'iteration','x','v','energy','tipo','R_before','R_after', ...
    'elapsed_physical_time','near_time_limit','energy_certified_safe','proven_safe_but_non_target'});
end

function row=summarize(name,seed,L,T,ref,elapsed,message)
row={name,seed,L.R(end),100*abs(L.R(end)-ref)/ref, ...
    sum(T.proven_safe_but_non_target),sum(T.tipo==4),sum(T.tipo==2), ...
    sum(T.near_time_limit),elapsed,message};
end

function write_summary(rows,outDir)
T=cell2table(rows,'VariableNames',{'variant','seed','R','relative_error_pct', ...
    'certified_safe_misclassified','new_solution_count','known_or_timeout_count', ...
    'near_timeout_count','runtime_s','failure_message'});
writetable(T,fullfile(outDir,'diagnostic_summary.csv'));
end

function restore(p,d)
cd(d); path(p);
end
