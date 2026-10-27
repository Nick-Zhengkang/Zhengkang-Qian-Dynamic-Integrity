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
function [R,S,K] = genda_A_export(outDir)
% Safe to call after Ctrl+C: per-run records are the source of truth.
outDir=char(outDir);
root=fileparts(mfilename('fullpath'));
addpath(fullfile(fileparts(root),'experiment_B_surrogate_accuracy'));
a=load(fullfile(outDir,'study_definition.mat'),'design','options'); D=a.design; o=a.options;
files=dir(fullfile(outDir,'records','*.mat'));
files=files(~endsWith(string({files.name}),'.tmp.mat'));
R=table(); S=table(); K=table();
if isempty(files), return; end
cells=cell(numel(files),1);
for j=1:numel(files)
    data=load(fullfile(files(j).folder,files(j).name),'row'); cells{j}=data.row;
end
R=sortrows(struct2table(vertcat(cells{:})),{'execution_order'});
assert(numel(unique(R.run_key))==height(R),'Duplicate run records.');
assert(all(ismember(R.config_id,D.config_id)) && all(ismember(R.seed,o.seedList)));
surrogate_accuracy_util('table',R,fullfile(outDir,'raw_data_all_runs.csv'));
summaries=cell(height(D),1);
for j=1:height(D)
    g=R(R.config_id==D.config_id(j),:);
    t=struct('config_id',D.config_id(j),'changed_parameter',D.changed_parameter(j), ...
        'level',D.level(j),'value_label',D.value_label(j), ...
        'n_expected',numel(o.seedList),'n_saved',height(g),'n_success',nnz(g.success), ...
        'n_diagnostic_success',nnz(g.diagnostic_success),'complete_valid',false, ...
        'pilot_only',~strcmp(o.mode,'full'));
    metrics={'median_R_hat','median_absolute_error','median_relative_error_percent', ...
        'p95_relative_error_percent','q1_relative_error_percent','q3_relative_error_percent', ...
        'median_core_wall_time_s','median_trajectory_evaluations','within_1pct_count', ...
        'within_2pct_count','median_false_safe_rate','median_false_unsafe_rate', ...
        'median_diagnostic_unresolved_rate','median_diagnostic_runtime_s'};
    for k=1:numel(metrics), t.(metrics{k})=NaN; end
    % Incomplete/failed batches are not silently scored using fewer seeds.
    t.complete_valid=height(g)==numel(o.seedList) && all(g.success) && ...
        all(isfinite(g.absolute_error)) && numel(unique(g.seed))==numel(o.seedList);
    if t.complete_valid
        t.median_R_hat=median(g.R_hat); t.median_absolute_error=median(g.absolute_error);
        e=g.relative_error_percent;
        t.median_relative_error_percent=median(e); t.p95_relative_error_percent=prctile(e,95);
        t.q1_relative_error_percent=prctile(e,25); t.q3_relative_error_percent=prctile(e,75);
        t.median_core_wall_time_s=median(g.core_wall_time_s);
        t.median_trajectory_evaluations=median(g.trajectory_evaluations);
        t.within_1pct_count=nnz(e<=1); t.within_2pct_count=nnz(e<=2);
        if all(g.diagnostic_success)
            t.median_false_safe_rate=median(g.false_safe_rate);
            t.median_false_unsafe_rate=median(g.false_unsafe_rate);
            t.median_diagnostic_unresolved_rate=median(g.diagnostic_unresolved_rate);
            t.median_diagnostic_runtime_s=median(g.diagnostic_runtime_s);
        end
    end
    summaries{j}=t;
end
C=struct2table(vertcat(summaries{:}));
surrogate_accuracy_util('table',C,fullfile(outDir,'summary_by_configuration.csv'));
factors=unique(D.changed_parameter(D.changed_parameter~="baseline"),'stable');
long=cell(numel(factors),1); perFactor=long; ranking=long;
for j=1:numel(factors)
    factor=factors(j);
    b=R(R.config_id=="baseline",:); b.changed_parameter(:)=factor;
    long{j}=[b;R(R.changed_parameter==factor,:)];
    s=C(C.config_id=="baseline" | C.changed_parameter==factor,:);
    s.changed_parameter(:)=factor; perFactor{j}=s;
    k=struct('changed_parameter',factor,'complete_valid',height(s)==3 && all(s.complete_valid), ...
        'error_range_percentage_points',NaN,'runtime_max_min_ratio',NaN, ...
        'pilot_only',~strcmp(o.mode,'full'));
    if k.complete_valid
        k.error_range_percentage_points=max(s.median_relative_error_percent)-min(s.median_relative_error_percent);
        k.runtime_max_min_ratio=max(s.median_core_wall_time_s)/min(s.median_core_wall_time_s);
    end
    ranking{j}=k;
end
S=vertcat(perFactor{:}); L=vertcat(long{:});
K=sortrows(struct2table(vertcat(ranking{:})),'error_range_percentage_points','descend');
surrogate_accuracy_util('table',L,fullfile(outDir,'analysis_long_with_reused_baseline.csv'));
surrogate_accuracy_util('table',S,fullfile(outDir,'summary_by_parameter_and_level.csv'));
surrogate_accuracy_util('table',K,fullfile(outDir,'sensitivity_ranking.csv'));
P=R(:,{'config_id','seed','success','absolute_error','core_wall_time_s'});
P.baseline_absolute_error=NaN(height(P),1); P.baseline_core_wall_time_s=NaN(height(P),1);
B=R(R.config_id=="baseline" & R.success,:);
for j=1:height(B)
    mask=P.seed==B.seed(j) & P.success;
    P.baseline_absolute_error(mask)=B.absolute_error(j);
    P.baseline_core_wall_time_s(mask)=B.core_wall_time_s(j);
end
P.absolute_error_difference=P.absolute_error-P.baseline_absolute_error;
P.runtime_ratio=P.core_wall_time_s./P.baseline_core_wall_time_s;
surrogate_accuracy_util('table',P,fullfile(outDir,'paired_changes_vs_baseline.csv'));
end
