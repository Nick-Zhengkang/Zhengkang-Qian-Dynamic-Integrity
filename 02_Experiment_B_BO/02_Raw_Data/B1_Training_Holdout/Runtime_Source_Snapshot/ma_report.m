function varargout=ma_report(action,T)
switch action
    case 'profile'
        alphas=unique(T.alpha); roles=unique(T.role); rows=cell(0,1);
        for a=alphas'
            for role=roles'
                G=T(T.alpha==a & T.role==role,:);
                if isempty(G), continue; end
                row=stats(G); row.alpha=a; row.role=role;
                rows{end+1,1}=row; %#ok<AGROW>
            end
        end
        varargout{1}=struct2table(vertcat(rows{:}));
    case 'compare'
        B=sortrows(T(T.role=="baseline",:),{'alpha','seed'});
        Q=sortrows(T(T.role=="candidate",:),{'alpha','seed'});
        assert(isequal(B(:,{'alpha','seed'}),Q(:,{'alpha','seed'})));
        P=B(:,{'alpha','seed','reference_LIM'});
        P.baseline_R=B.R_hat; P.candidate_R=Q.R_hat;
        P.baseline_absolute_error=B.absolute_error; P.candidate_absolute_error=Q.absolute_error;
        P.both_valid=B.success & Q.success;
        P.candidate_minus_baseline_error=Q.absolute_error-B.absolute_error;
        P.candidate_minus_baseline_wall_s=Q.core_wall_time_s-B.core_wall_time_s;
        P.candidate_minus_baseline_cpu_s=Q.core_cpu_time_s-B.core_cpu_time_s;
        alphas=unique(B.alpha); rows=cell(0,1);
        for a=[NaN;alphas]'
            if isnan(a), b=B; q=Q; else, b=B(B.alpha==a,:); q=Q(Q.alpha==a,:); end
            bs=stats(b); qs=stats(q);
            row=struct('alpha',a,'baseline_median_absolute_error',bs.median_absolute_error, ...
                'candidate_median_absolute_error',qs.median_absolute_error, ...
                'reduction_percent',NaN,'improvement_factor',NaN, ...
                'baseline_p95_absolute_error',bs.p95_absolute_error, ...
                'candidate_p95_absolute_error',qs.p95_absolute_error, ...
                'baseline_median_wall_s',bs.median_wall_s,'candidate_median_wall_s',qs.median_wall_s, ...
                'baseline_median_cpu_s',bs.median_cpu_s,'candidate_median_cpu_s',qs.median_cpu_s, ...
                'complete',bs.complete && qs.complete,'candidate_has_lower_median',false);
            if row.complete
                row.candidate_has_lower_median=qs.median_absolute_error<bs.median_absolute_error;
                if bs.median_absolute_error>0
                    row.reduction_percent=100*(1-qs.median_absolute_error/bs.median_absolute_error);
                end
                if qs.median_absolute_error>0
                    row.improvement_factor=bs.median_absolute_error/qs.median_absolute_error;
                end
            end
            rows{end+1,1}=row; %#ok<AGROW>
        end
        C=struct2table(vertcat(rows{:})); varargout={C,P};
    otherwise
        error('Unknown report action.');
end
end

function row=stats(G)
row=struct('n',height(G),'n_success',sum(G.success),'complete',all(G.success), ...
    'median_absolute_error',NaN,'p95_absolute_error',NaN, ...
    'median_relative_error_percent',NaN,'p95_relative_error_percent',NaN, ...
    'median_R',NaN,'median_wall_s',NaN,'median_cpu_s',NaN, ...
    'within_1pct',sum(G.success & G.relative_error_percent<=1), ...
    'severe_error_above_50pct',sum(G.success & G.relative_error_percent>50));
if row.complete
    assert(all(isfinite(G.absolute_error)));
    row.median_absolute_error=median(G.absolute_error);
    row.p95_absolute_error=percentile95(G.absolute_error);
    row.median_relative_error_percent=median(G.relative_error_percent);
    row.p95_relative_error_percent=percentile95(G.relative_error_percent);
    row.median_R=median(G.R_hat); row.median_wall_s=median(G.core_wall_time_s);
    row.median_cpu_s=median(G.core_cpu_time_s);
end
end

function y=percentile95(x)
x=sort(x); n=numel(x);
if n==1, y=x; else, y=interp1([0;((1:n)'-.5)/n;1],[x(1);x;x(end)],.95); end
end
