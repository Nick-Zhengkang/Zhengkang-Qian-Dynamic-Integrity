% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Proposed-method implementation, comparison, or supporting model code.
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
function varargout=sampled_forward_io(action,varargin)
switch action
    case 'save'
        file=varargin{1}; payload=varargin{2}; tmp=[file '.writing.mat'];
        save(tmp,'-struct','payload','-v7'); movefile(tmp,file,'f');
    case 'table'
        T=varargin{1}; file=varargin{2}; tmp=[file '.writing.csv'];
        writetable(T,tmp); movefile(tmp,file,'f');
    case 'signature'
        root=varargin{1}; repo=varargin{2};
        folders={root,fullfile(repo,'six_model_dynin_vs_proposed'), ...
            fullfile(repo,'habib_4d_adaptive_radial'),fullfile(repo,'separable_4d_analytic_benchmark')};
        files=strings(0,1);
        for k=1:numel(folders)
            a=dir(fullfile(folders{k},'*.m'));
            files=[files;string(fullfile({a.folder},{a.name})).']; %#ok<AGROW>
        end
        folders={fullfile(repo,'four_model_five_method_suite','functions'), ...
            fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions'), ...
            fullfile(repo,'work','DynIn','DynIn_v1.1.0','VanDerPolDuffing_NLTVA')};
        for k=1:numel(folders)
            a=dir(fullfile(folders{k},'**','*.m'));
            files=[files;string(fullfile({a.folder},{a.name})).']; %#ok<AGROW>
        end
        files=sort(unique(files));
        % The user edits this launcher to set resumeDirectory. Numerical
        % options are checked separately in study_definition.mat.
        files(endsWith(files,filesep+"test_sampled_forward_comparison.m"))=[];
        relative=strings(size(files)); digest=relative;
        for k=1:numel(files)
            relative(k)=extractAfter(files(k),strlength(string(repo))+1);
            fid=fopen(files(k),'rb'); assert(fid>=0); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
            md=java.security.MessageDigest.getInstance('SHA-256'); md.update(typecast(bytes(:),'int8'));
            digest(k)=string(lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[])));
        end
        varargout{1}=table(relative,digest,'VariableNames',{'relative_path','sha256'});
    case 'snapshot'
        T=varargin{1}; repo=varargin{2}; out=varargin{3};
        for k=1:height(T)
            dest=fullfile(out,'source_snapshot',T.relative_path(k));
            folder=fileparts(dest); if ~isfolder(folder), mkdir(folder); end
            copyfile(fullfile(repo,T.relative_path(k)),dest);
        end
        sampled_forward_io('table',T,fullfile(out,'source_signature.csv'));
        % Archive the editable launcher too, but do not hash it for resume.
        copyfile(fullfile(repo,'six_model_sampled_forward_comparison','test_sampled_forward_comparison.m'), ...
            fullfile(out,'source_snapshot','six_model_sampled_forward_comparison','test_sampled_forward_comparison.m'));
    case 'export'
        out=varargin{1}; schedule=varargin{2}; rows=cell(0,1);
        for k=1:height(schedule)
            file=fullfile(out,'runs',char(schedule.run_key(k)+".mat"));
            if ~isfile(file), continue; end
            a=load(file); rows{end+1,1}=a.row; %#ok<AGROW>
            if isfield(a.details,'query_records') && ~isempty(a.details.query_records)
                records=a.details.query_records;
                Q=struct2table(vertcat(records{:}));
                sampled_forward_io('table',Q,fullfile(out,'runs',char(schedule.run_key(k)+"_queries.csv")));
            end
        end
        raw=struct2table(vertcat(rows{:}));
        raw=sortrows(raw,'execution_order');
        sampled_forward_io('table',raw,fullfile(out,'raw_data_all_runs.csv'));
        [summary,paired,reasons]=summarize(raw,out);
        sampled_forward_io('table',summary,fullfile(out,'summary_by_model_and_method.csv'));
        sampled_forward_io('table',paired,fullfile(out,'paired_contrasts_by_seed.csv'));
        sampled_forward_io('table',reasons,fullfile(out,'classification_reason_counts.csv'));
        varargout{1}=raw;
    case 'summary'
        [varargout{1:nargout}]=summarize(varargin{:});
    otherwise, error('Unknown IO action: %s',action);
end
end

function [summary,paired,reasons]=summarize(raw,out)
rows=cell(0,1); contrasts=cell(0,1); counts=cell(0,1);
for id=reshape(unique(raw.model_id,'stable'),1,[])
    for method=reshape(unique(raw.method(raw.model_id==id),'stable'),1,[])
        g=raw(raw.model_id==id & raw.method==method,:);
        valid=g.execution_ok & g.valid_estimate;
        scored=valid & isfinite(g.relative_error);
        r=struct('model_id',id,'method',method,'runs',height(g), ...
            'execution_ok',sum(g.execution_ok),'finite_estimates',sum(g.estimate_available), ...
            'valid_estimates',sum(valid),'converged_runs',sum(g.converged), ...
            'review_required_runs',sum(g.review_required),'reference_kind',g.reference_kind(1), ...
            'R_reference',g.R_reference(1),'median_R_hat_all_finite',med(g.R_hat), ...
            'median_R_hat_valid',med(g.R_hat(valid)), ...
            'median_relative_error_valid',med(g.relative_error(scored)), ...
            'p95_relative_error_valid',pct95(g.relative_error(scored)), ...
            'error_scored_runs',sum(scored),'within_1pct_count',sum(scored & g.relative_error<=.01), ...
            'within_2pct_count',sum(scored & g.relative_error<=.02), ...
            'median_algorithm_runtime_s',med(g.algorithm_runtime_s(g.execution_ok)), ...
            'median_wall_runtime_s',med(g.wall_runtime_s(g.execution_ok)), ...
            'median_query_count',med(g.query_count(g.execution_ok)), ...
            'median_trajectory_count',med(g.trajectory_count(g.execution_ok)), ...
            'median_ode_solver_calls',med(g.ode_solver_calls(g.execution_ok)), ...
            'median_rhs_count',med(g.rhs_count(g.execution_ok)), ...
            'median_sample_check_count',med(g.sample_check_count(g.execution_ok)), ...
            'median_unresolved_count',med(g.unresolved_count),'median_forced_non_target_count',med(g.forced_non_target_count), ...
            'median_retry_count',med(g.retry_count), ...
            'median_grid_cache_hit_count',med(g.grid_cache_hit_count), ...
            'median_grid_cache_target_hit_count',med(g.grid_cache_target_hit_count), ...
            'median_grid_cache_non_target_hit_count',med(g.grid_cache_non_target_hit_count), ...
            'median_cached_target_cells',med(g.cached_target_cells), ...
            'median_cached_non_target_cells',med(g.cached_non_target_cells), ...
            'median_cached_exit_cells',med(g.cached_exit_cells));
        if ~isfinite(r.R_reference), r.within_1pct_count=NaN; r.within_2pct_count=NaN; end
        rows{end+1,1}=r; %#ok<AGROW>
    end
    for seed=reshape(unique(raw.seed(raw.model_id==id)),1,[])
        a=raw(raw.model_id==id & raw.seed==seed & raw.method=="dynin_original_ga",:);
        b=raw(raw.model_id==id & raw.seed==seed & raw.method=="proposed_sampled_forward",:);
        if isempty(a) || isempty(b), continue; end
        contrasts{end+1,1}=struct('model_id',id,'seed',seed, ...
            'both_valid',a.valid_estimate && b.valid_estimate && a.execution_ok && b.execution_ok, ...
            'dynin_R_hat',a.R_hat,'proposed_R_hat',b.R_hat, ...
            'proposed_minus_dynin_R',b.R_hat-a.R_hat, ...
            'proposed_minus_dynin_relative_error',b.relative_error-a.relative_error, ...
            'proposed_minus_dynin_runtime_s',b.algorithm_runtime_s-a.algorithm_runtime_s, ...
            'proposed_to_dynin_runtime_ratio',b.algorithm_runtime_s/a.algorithm_runtime_s, ...
            'proposed_unresolved_count',b.unresolved_count,'proposed_stop_status',b.stop_status); %#ok<AGROW>
    end
end
if nargin>1
    for k=1:height(raw)
        if raw.method(k)~="proposed_sampled_forward", continue; end
        a=load(fullfile(out,'runs',char(raw.run_key(k)+".mat")),'details');
        if ~isfield(a.details,'query_records') || isempty(a.details.query_records), continue; end
        records=a.details.query_records; labels=strings(numel(records),1);
        for j=1:numel(records), labels(j)=records{j}.classification_reason; end
        for reason=reshape(unique(labels),1,[])
            counts{end+1,1}=struct('model_id',raw.model_id(k),'seed',raw.seed(k), ...
                'reason',reason,'query_count',sum(labels==reason)); %#ok<AGROW>
        end
    end
end
summary=struct2table(vertcat(rows{:}));
if isempty(contrasts)
    paired=table(strings(0,1),zeros(0,1),'VariableNames',{'model_id','seed'});
else
    paired=struct2table(vertcat(contrasts{:}));
end
if isempty(counts)
    reasons=table(strings(0,1),zeros(0,1),strings(0,1),zeros(0,1), ...
        'VariableNames',{'model_id','seed','reason','query_count'});
else
    reasons=struct2table(vertcat(counts{:}));
end
end

function y=med(x)
x=x(isfinite(x)); if isempty(x), y=NaN; else, y=median(x); end
end
function y=pct95(x)
x=sort(x(isfinite(x))); n=numel(x);
if n==0, y=NaN; return; end
% MATLAB's midpoint-position percentile convention, without extra toolbox.
t=min(n,max(1,n*.95+.5)); lo=floor(t); hi=ceil(t);
y=x(lo)+(t-lo)*(x(hi)-x(lo));
end


