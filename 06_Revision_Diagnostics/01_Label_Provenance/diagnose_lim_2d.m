function out = diagnose_lim_2d(o)
% AI-assisted code: inventory all 90 runs, then trace representative queries.
% Native source snapshot and historical MAT/CSV files are read-only inputs.
root=fileparts(mfilename('fullpath'));
oldPath=path; oldDir=pwd;
restore=onCleanup(@() restore_environment(oldPath,oldDir)); %#ok<NASGU>
addpath(root); cd(root);
data=char(java.io.File(o.dataDirectory).getCanonicalPath());
assert(isfolder(data),'Original data directory does not exist.');
out=fullfile(o.outputRoot,datestr(now,'yyyymmdd_HHMMSS_FFF'));
outCanonical=char(java.io.File(out).getCanonicalPath());
assert(~startsWith(lower([outCanonical filesep]),lower([data filesep])), ...
    'Diagnostics must not be written inside the original data directory.');
assert(~isfolder(out),'Output directory already exists.');
mkdir(out);
diary(fullfile(out,'run.log')); diaryGuard=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Read-only source: %s\nDiagnostic output: %s\n',data,out);
snapshot=fullfile(data,'source_snapshot');
native=fullfile(snapshot,'work','DynIn','DynIn_v1.1.0','functions');
sampled=fullfile(snapshot,'six_model_sampled_forward_comparison');
addpath(native,'-begin'); addpath(sampled,'-begin');
assert(strcmpi(which('sampled_forward_integrate'),fullfile(sampled,'sampled_forward_integrate.m')));
assert(strcmpi(which('sampled_forward_step'),fullfile(sampled,'sampled_forward_step.m')));
assert(strcmpi(which('find_index'),fullfile(native,'find_index.m')));
auditBefore=diagnostic_hashes(data);
writetable(auditBefore,fullfile(out,'original_files_before.csv'));
hashGuard=onCleanup(@() check_integrity(data,auditBefore,out)); %#ok<NASGU>
environment=struct('matlabVersion',version,'computer',computer,'options',o, ...
    'sourceDirectory',data,'diagnosticDirectory',root);
save(fullfile(out,'diagnostic_settings.mat'),'environment');
copyfile(fullfile(root,'*.m'),out);
models=["quadratic_cubic","bistable_duffing","genda_cosine_quadratic_drag"];
inventory=cell(0,1);
for id=models
    files=dir(fullfile(data,'runs',char(id+"__proposed_sampled_forward__seed_*.mat")));
    assert(numel(files)==30,'Expected 30 original runs for %s.',id);
    settings=load(fullfile(data,char(id+"_settings.mat")));
    for k=1:numel(files)
        f=load(fullfile(files(k).folder,files(k).name));
        row=f.row; qs=f.details.query_records;
        radii=cellfun(@(q) double(q.initial_radius),qs);
        unsafe=cellfun(@(q) string(q.label)=="non_target",qs);
        assert(any(unsafe));
        candidates=find(unsafe); [best,j]=min(radii(candidates)); win=candidates(j);
        assert(abs(best-row.R_hat)<1e-10,'Saved radius is not the minimum non-target query.');
        first=find(unsafe & radii<row.R_reference-1e-10,1);
        if isempty(first), first=NaN; end
        q=qs{win}; z=reshape(q.initial_state,1,[]);
        reconstructed=sqrt(sum((z-settings.dynin.target).^2.*settings.dynin.weight));
        assert(abs(reconstructed-best)<1e-10,'Distance/coordinate mismatch.');
        inventory{end+1,1}=struct('model',id,'seed',double(row.seed), ...
            'algorithm_seed',double(row.algorithm_seed),'R_hat',double(row.R_hat), ...
            'R_reference',double(row.R_reference),'signed_relative_error', ...
            (row.R_hat-row.R_reference)/row.R_reference,'under_reference',best<row.R_reference-1e-10, ...
            'winning_query',win,'first_under_query',first,'x0',z(1),'v0',z(2), ...
            'winning_reason',string(q.classification_reason),'winning_time',double(q.end_time), ...
            'query_count',numel(qs),'run_file',string(fullfile(files(k).folder,files(k).name))); %#ok<AGROW>
    end
end
T=sortrows(struct2table(vertcat(inventory{:})),{'model','seed'});
writetable(T,fullfile(out,'all_90_runs_decisive_points.csv'));
chosen=[]; roles=strings(0,1);
for id=models
    idx=find(T.model==id & T.under_reference);
    if isempty(idx), continue; end
    [~,order]=sort(T.signed_relative_error(idx)); idx=idx(order);
    if o.selection=="all_underestimated"
        selected=idx; selectedRoles=repmat("all_underestimated",numel(idx),1);
    else
        assert(o.selection=="representative");
        selected=idx(unique([1,ceil(numel(idx)/2),numel(idx)],'stable'));
        selectedRoles=["most_underestimated";"median_underestimate";"smallest_underestimate"];
        selectedRoles=selectedRoles(1:numel(selected));
    end
    chosen=[chosen;selected]; roles=[roles;selectedRoles]; %#ok<AGROW>
end
selected=T(chosen,:); selected.selection_role=roles;
writetable(selected,fullfile(out,'selected_cases.csv'));
fprintf('Inventory complete: %d runs, %d underestimated; %d selected cases.\n', ...
    height(T),sum(T.under_reference),height(selected));
status=cell(0,1);
for k=1:height(selected)
    row=selected(k,:); id=row.model; seed=row.seed;
    caseOut=fullfile(out,sprintf('%s_seed_%d',id,seed)); mkdir(caseOut);
    modelDir=fullfile(data,'dynin_models',char(id));
    addpath(modelDir,'-begin'); clear sistema; rehash;
    assert(strcmpi(which('sistema'),fullfile(modelDir,'sistema.m')),'Wrong model resolved.');
    fprintf('\nCASE %d/%d: %s seed %d\n',k,height(selected),id,seed);
    try
        f=load(char(row.run_file)); settings=load(fullfile(data,char(id+"_settings.mat")));
        d=settings.dynin; d.modelDir=modelDir;
        trace=diagnostic_replay(d,f.details.query_records,row,caseOut,o);
        if trace.reproduced && o.independentValidation
            diagnostic_validate(id,d,trace,row,caseOut,o);
        end
        outcome="replay_matches";
        if ~trace.reproduced, outcome="replay_mismatch_no_causal_claim"; end
        status{end+1,1}=struct('model',id,'seed',seed,'status',outcome,'message',""); %#ok<AGROW>
    catch ME
        msg=string(getReport(ME,'extended','hyperlinks','off'));
        fid=fopen(fullfile(caseOut,'ERROR.txt'),'w'); fprintf(fid,'%s',msg); fclose(fid);
        fprintf(2,'%s\n',msg);
        status{end+1,1}=struct('model',id,'seed',seed,'status',"error",'message',msg); %#ok<AGROW>
    end
    writetable(struct2table(vertcat(status{:})),fullfile(out,'case_status.csv'));
    rmpath(modelDir); clear sistema;
end
fprintf('\nFinished diagnostics. Inspect case_status.csv before interpreting results.\n');
end

function restore_environment(p,d)
path(p); cd(d); clear sistema;
end
function check_integrity(data,before,out)
after=diagnostic_hashes(data);
writetable(after,fullfile(out,'original_files_after.csv'));
same=isequal(before,after);
fid=fopen(fullfile(out,'ORIGINAL_DATA_INTEGRITY.txt'),'w');
fprintf(fid,'All original source/data bytes unchanged: %d\n',same); fclose(fid);
if ~same, warning('Original source/data changed during the audit. Investigate before using results.'); end
end

