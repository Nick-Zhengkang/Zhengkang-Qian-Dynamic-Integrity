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
function varargout = optimization_statistics(action,varargin)
switch char(action)
    case 'summary'
        varargout{1}=summarize(varargin{:});
    case 'select'
        varargout{1}=select_candidates(varargin{:});
    case 'bootstrap'
        varargout{1}=paired_bootstrap(varargin{:});
    otherwise
        error('Unknown statistics action.');
end
end

function S=summarize(raw,baselineId,o,expectedRuns)
ids=unique(raw.config_id,'stable');
rows=cell(numel(ids),1);
for i=1:numel(ids)
    g=raw(raw.config_id==ids(i),:);
    ok=g.success & g.diagnostic_success & isfinite(g.relative_error) & ...
        isfinite(g.wall_runtime_s) & g.wall_runtime_s>0 & ...
        isfinite(g.false_safe_rate) & isfinite(g.false_unsafe_rate) & ...
        isfinite(g.diagnostic_unresolved_rate) & ...
        isfinite(g.diagnostic_truth_unresolved_rate);
    r=struct('config_id',ids(i),'n_runs',height(g),'n_complete',nnz(ok), ...
        'all_complete',height(g)==expectedRuns && all(ok), ...
        'median_error',finite_median(g.relative_error), ...
        'p95_error',percentile(g.relative_error,0.95), ...
        'pass_rate',mean(ok & g.relative_error<=o.errorThreshold), ...
        'mean_false_safe',finite_mean(g.false_safe_rate), ...
        'mean_false_unsafe',finite_mean(g.false_unsafe_rate), ...
        'max_false_safe',finite_max(g.false_safe_rate), ...
        'mean_unresolved',finite_mean(g.diagnostic_unresolved_rate), ...
        'truth_unresolved',finite_max(g.diagnostic_truth_unresolved_rate), ...
        'median_wall_runtime_s',finite_median(g.wall_runtime_s), ...
        'median_algorithm_runtime_s',finite_median(g.algorithm_runtime_s), ...
        'median_evaluations',finite_median(g.trajectory_evaluations), ...
        'median_processed_samples',finite_median(g.processed_time_samples), ...
        'median_diagnostic_runtime_s',finite_median(g.diagnostic_runtime_s));
    rows{i}=r;
end
S=struct2table(vertcat(rows{:}));
S.is_baseline=S.config_id==baselineId;
b=S(S.config_id==baselineId,:);
assert(height(b)==1,'Stage baseline is missing.');
eps0=1e-12;
S.median_ok=S.median_error<=b.median_error+o.medianErrorMargin+eps0;
S.p95_ok=S.p95_error<=b.p95_error+o.p95ErrorMargin+eps0;
S.pass_rate_ok=S.pass_rate>=b.pass_rate-o.passRateLoss-eps0;
S.false_safe_ok=S.mean_false_safe<=min(o.maxMeanFalseSafe, ...
    b.mean_false_safe+o.falseSafeMargin)+eps0;
S.false_unsafe_ok=S.mean_false_unsafe<=b.mean_false_unsafe+o.falseUnsafeMargin+eps0;
S.unresolved_ok=S.mean_unresolved<=o.maxDiagnosticUnresolved+eps0 & S.truth_unresolved==0;
S.feasible=S.all_complete & b.all_complete & S.median_ok & S.p95_ok & ...
    S.pass_rate_ok & S.false_safe_ok & S.false_unsafe_ok & S.unresolved_ok;
S.runtime_ratio=S.median_wall_runtime_s/b.median_wall_runtime_s;
S.faster_than_baseline=S.runtime_ratio<1;
% Only for promotion during exploratory search, never the final objective.
S.failed_gates=double(~S.median_ok)+double(~S.p95_ok)+double(~S.pass_rate_ok)+ ...
    double(~S.false_safe_ok)+double(~S.false_unsafe_ok)+double(~S.unresolved_ok)+ ...
    10*double(~S.all_complete);
end

function ids=select_candidates(S,baselineId,n,exploratory)
T=S(S.config_id~=baselineId & S.all_complete,:);
if ~exploratory, T=T(T.feasible,:); end
if isempty(T), ids=strings(0,1); return; end
T=sortrows(T,{'failed_gates','median_wall_runtime_s','median_error','config_id'});
ids=T.config_id(1:min(n,height(T)));
if exploratory && n>1
    % Reserve an accuracy anchor so the fastest beam does not dominate.
    A=sortrows(T,{'failed_gates','median_error','p95_error','config_id'});
    if ~any(ids==A.config_id(1))
        ids(end)=A.config_id(1);
    end
end
end

function T=paired_bootstrap(raw,baselineId,candidateId,o)
B=sortrows(raw(raw.config_id==baselineId,:),'seed');
C=sortrows(raw(raw.config_id==candidateId,:),'seed');
assert(isequal(B.seed,C.seed),'Confirmation seeds are not paired.');
n=height(B);
assert(all(B.success & C.success & B.diagnostic_success & C.diagnostic_success), ...
    'Do not bootstrap incomplete confirmation runs.');
stream=RandStream('mt19937ar','Seed',o.bootstrapSeed);
draws=zeros(o.bootstrapReplicates,6);
for k=1:o.bootstrapReplicates
    ix=randi(stream,n,n,1);
    draws(k,:) = contrast_values(B(ix,:),C(ix,:),o);
end
observed=contrast_values(B,C,o);
names=["median_error_difference";"p95_error_difference";"pass_rate_difference"; ...
    "mean_false_safe_difference";"mean_false_unsafe_difference";"median_wall_time_ratio"];
lo=zeros(6,1); hi=lo;
for j=1:6
    lo(j)=percentile(draws(:,j),0.05);
    hi(j)=percentile(draws(:,j),0.95);
end
limit=[o.medianErrorMargin;o.p95ErrorMargin;-o.passRateLoss; ...
    o.falseSafeMargin;o.falseUnsafeMargin;1];
supported=hi<=limit+1e-12;
supported(3)=lo(3)>=limit(3)-1e-12;
supported(6)=hi(6)<1;
T=table(names,observed(:),lo,hi,limit,supported, ...
    'VariableNames',{'metric','estimate','bootstrap_q05','bootstrap_q95','limit','supported'});
end

function v=contrast_values(B,C,o)
v=[median(C.relative_error)-median(B.relative_error), ...
    percentile(C.relative_error,0.95)-percentile(B.relative_error,0.95), ...
    mean(C.relative_error<=o.errorThreshold)-mean(B.relative_error<=o.errorThreshold), ...
    mean(C.false_safe_rate)-mean(B.false_safe_rate), ...
    mean(C.false_unsafe_rate)-mean(B.false_unsafe_rate), ...
    median(C.wall_runtime_s)/median(B.wall_runtime_s)];
end

function v=percentile(x,p)
x=sort(x(isfinite(x)));
if isempty(x), v=NaN; else, v=x(max(1,ceil(p*numel(x)))); end
end
function v=finite_median(x)
x=x(isfinite(x)); if isempty(x), v=NaN; else, v=median(x); end
end
function v=finite_mean(x)
x=x(isfinite(x)); if isempty(x), v=NaN; else, v=mean(x); end
end
function v=finite_max(x)
x=x(isfinite(x)); if isempty(x), v=NaN; else, v=max(x); end
end
