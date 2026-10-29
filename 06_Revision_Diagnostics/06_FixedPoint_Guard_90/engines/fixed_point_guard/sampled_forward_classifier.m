function api=sampled_forward_classifier(d,canStart)
% Native sampled rules and label propagation, with one continuous ODE call.
% AI-assisted repair: confirm fixed-point candidates with a model-specific
% non-target-well certificate. Other labels and cache writes are unchanged.
if nargin<2, canStart=@() true; end
g=sampled_forward_geometry(d); dim=numel(d.target);
initialTarget=g.cell_c;
api=struct('classify',@classify,'stats',@stats,'state',@state);

    function [r,nIntegrations]=classify(z0,varargin)
        z0=reshape(z0,1,[]);
        assert(numel(z0)==dim && all(isfinite(z0)));
        r=struct('label',"unresolved",'classification_reason',"", ...
            'first_attempt_reason',"",'min_radius',NaN,'min_point',nan(size(z0)), ...
            'horizon_used',d.tfinal,'end_time',0,'retried',false, ...
            'integration_runtime_s',0,'sample_count',0,'from_cache',false, ...
            'rhs_count',0,'integration_count',0,'grid_cache_hit',false, ...
            'grid_cache_kind',0,'native_tipo',0,'forced_non_target',false);
        nIntegrations=0;
        r.fp_candidate_count=0; r.fp_accepted_count=0; r.fp_rejected_count=0;
        r.fp_events=zeros(0,8);
        if ~canStart()
            r.classification_reason="wall_guard_before_native_query";
            return
        end
        % Such a query has no valid initial grid cell. Do not create a
        % false radial boundary from a state outside the allowed search.
        if any(z0<d.domain(1:dim)) || any(z0>d.domain(dim+1:end))
            r.classification_reason="initial_state_outside_domain";
            return
        end
        for j=1:dim
            if ~any(g.cell_pos(:,j)>=z0(j)-g.dh(j)/2 & g.cell_pos(:,j)<=z0(j)+g.dh(j)/2)
                r.classification_reason="initial_grid_lookup_unresolved";
                return
            end
        end
        timer=tic;
        [xt,cells,tipo,count,rhsCalls,fpEvents]=sampled_forward_integrate(d,g,z0);
        r.fp_events=fpEvents;
        r.fp_candidate_count=size(fpEvents,1);
        r.fp_accepted_count=nnz(fpEvents(:,6));
        r.fp_rejected_count=r.fp_candidate_count-r.fp_accepted_count;
        r.integration_runtime_s=toc(timer);
        assert(count>=2 && size(xt,1)>=count && numel(cells)>=count);
        xt=xt(1:count,:); cells=cells(1:count);
        assert(all(isfinite(xt),'all'),'Native solver returned a nonfinite trajectory.');
        nIntegrations=1;
        r.rhs_count=rhsCalls;
        r.integration_count=nIntegrations; r.sample_count=count;
        r.end_time=(count-1)*d.Ts; r.native_tipo=tipo;
        distances=sqrt(sum((xt-d.target).^2.*d.weight,2));
        [r.min_radius,j]=min(distances); r.min_point=xt(j,:);
        r.forced_non_target=tipo==0;
        if tipo==0
            % Match compute_LIM_FP automatic=1, and expose this convention.
            tipo=2; r.classification_reason="horizon_forced_non_target";
        elseif tipo==1
            r.classification_reason="native_target_neighbourhood";
            if ~ismember(cells(end),initialTarget)
                r.classification_reason="known_target_grid_cell";
                r.grid_cache_hit=true; r.grid_cache_kind=1;
            end
        elseif tipo==2
            r.classification_reason="known_non_target_grid_cell";
            r.grid_cache_hit=true; r.grid_cache_kind=2;
        elseif tipo==3
            outside=any(xt(end,:)<=d.domain(1:dim) | xt(end,:)>=d.domain(dim+1:end));
            if outside
                r.classification_reason="left_computational_domain";
            else
                r.classification_reason="known_domain_exit_grid_cell";
                r.grid_cache_hit=true; r.grid_cache_kind=3;
            end
        elseif tipo==4
            r.classification_reason="native_non_target_recurrence";
        else
            error('Unexpected native classification: %g.',tipo);
        end
        r.from_cache=r.grid_cache_hit;
        if tipo==1, r.label="target"; else, r.label="non_target"; end
        % Preserve native stable-unique ordering and terminal-cell exclusion.
        cells=unique(cells,'stable'); learned=cells(1:end-1);
        if tipo==1
            g.cell_c=[g.cell_c;learned];
        elseif tipo==3
            g.cell_dout=[g.cell_dout;learned];
        else
            g.cell_d=[g.cell_d;learned];
        end
    end

    function s=stats()
        s=struct('target',numel(unique(g.cell_c)), ...
            'non_target',numel(unique(g.cell_d)), ...
            'exit',numel(unique(g.cell_dout)));
    end
    function s=state()
        s=g;
    end
end

