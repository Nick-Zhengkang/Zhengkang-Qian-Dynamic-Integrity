function [R_bis,stats,best_xt,best_tipo] = adaptive_boundary_bisection(dim,par,xe,weight,tfinal,Ts,tols,spaceboundary,adaptive_grid,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,bis_iter,max_pairs,current_R,automatic,eta_bisect,use_LIM_oriented_refinement)
%ADAPTIVE_BOUNDARY_BISECTION Refine LIM candidate from fine-cell boundary pairs.
% This routine does not introduce a new convergence criterion. Every
% midpoint is classified by simulation_DI_adaptive, and only nonconverging
% trajectories can produce a LIM candidate through findradius.

if nargin < 17 || isempty(automatic)
    automatic = 1;
end
if nargin < 18 || isempty(eta_bisect)
    eta_bisect = Inf;
end
if nargin < 19 || isempty(use_LIM_oriented_refinement)
    use_LIM_oriented_refinement = 0;
end

stats = init_bisection_stats();
stats.number_of_bisection_calls = 1;
R_bis = Inf;
best_xt = [];
best_tipo = 0;
if isvector(xe)
    xe_for_radius = xe;
else
    xe_for_radius = xe(1,:);
end

[pairs, pair_stats] = adaptive_grid.find_fine_boundary_pairs(max_pairs,xe,weight,current_R,eta_bisect,use_LIM_oriented_refinement);
stats.number_of_bisection_pairs_total = pair_stats.number_of_bisection_pairs_total;
stats.number_of_bisection_pairs_near_LIM = pair_stats.number_of_bisection_pairs_near_LIM;
stats.number_of_fine_boundary_pairs_found = pair_stats.number_of_bisection_pairs_total;
stats.number_of_bisection_pairs_tested = length(pairs);

if isempty(pairs)
    return
end

for k = 1:length(pairs)
    x_conv = pairs(k).conv_point;
    x_nonconv = pairs(k).nonconv_point;

    if any(~isfinite(x_conv)) || any(~isfinite(x_nonconv))
        continue
    end

    stats.number_of_valid_bisection_pairs = stats.number_of_valid_bisection_pairs + 1;

    for iter = 1:bis_iter
        x_mid = 0.5*(x_conv + x_nonconv);
        [xt_mid,~,visited_keys,tipo_mid,~,~,early_stop_level_mid] = simulation_DI_adaptive(dim,par,x_mid,tfinal,Ts,tols,spaceboundary,adaptive_grid,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight);
        stats.number_of_bisection_midpoints_simulated = stats.number_of_bisection_midpoints_simulated + 1;

        if tipo_mid == 1
            adaptive_grid.update_cells(visited_keys,'converging');
            x_conv = x_mid;
        elseif tipo_mid > 1
            adaptive_grid.update_cells(visited_keys,'nonconverging');
            x_nonconv = x_mid;
            stats.number_of_bisection_nonconv_found = stats.number_of_bisection_nonconv_found + 1;

            R_candidate = findradius(xt_mid,xe_for_radius,weight);
            if R_candidate < R_bis
                R_bis = R_candidate;
                best_xt = xt_mid;
                best_tipo = tipo_mid;
                [closest_point,closest_distance] = closest_point_to_target(xt_mid,xe_for_radius,weight);
                stats.last_update.source = 'bisection_midpoint';
                stats.last_update.initial_condition = x_mid;
                stats.last_update.closest_point = closest_point;
                stats.last_update.closest_distance = closest_distance;
                stats.last_update.classification = tipo_mid;
                stats.last_update.stopped_by_cell = ~isempty(early_stop_level_mid);
                stats.last_update.inherited_label = 'nonconverging';
                stats.last_update.early_stop_level = early_stop_level_mid;
                stats.last_update.visited_first_cell = '';
                stats.last_update.visited_last_cell = '';
                if ~isempty(visited_keys)
                    stats.last_update.visited_first_cell = visited_keys{1};
                    stats.last_update.visited_last_cell = visited_keys{end};
                end
                stats.last_update.R_candidate = R_candidate;
                stats.last_update.bisection_pair_index = k;
                stats.last_update.bisection_inner_iter = iter;
            end
        else
            stats.number_of_bisection_undefined_midpoints = stats.number_of_bisection_undefined_midpoints + 1;
            break
        end
    end
end

stats.best_R_bis = R_bis;
if isfinite(R_bis) && R_bis < current_R
    stats.number_of_bisection_LIM_updates = 1;
end
end

function stats = init_bisection_stats()
stats.number_of_bisection_calls = 0;
stats.number_of_fine_boundary_pairs_found = 0;
stats.number_of_bisection_pairs_tested = 0;
stats.number_of_valid_bisection_pairs = 0;
stats.number_of_bisection_midpoints_simulated = 0;
stats.number_of_bisection_nonconv_found = 0;
stats.number_of_bisection_undefined_midpoints = 0;
stats.number_of_bisection_LIM_updates = 0;
stats.number_of_bisection_pairs_total = 0;
stats.number_of_bisection_pairs_near_LIM = 0;
stats.best_R_bis = Inf;
stats.last_update = empty_update_debug();
end

function s = empty_update_debug()
s.source = '';
s.initial_condition = [];
s.closest_point = [];
s.closest_distance = Inf;
s.classification = 0;
s.stopped_by_cell = false;
s.inherited_label = '';
s.early_stop_level = '';
s.visited_first_cell = '';
s.visited_last_cell = '';
s.R_candidate = Inf;
s.bisection_pair_index = NaN;
s.bisection_inner_iter = NaN;
end

function [closest_point,closest_distance] = closest_point_to_target(xt,xe,weight)
if isempty(xt)
    closest_point = [];
    closest_distance = Inf;
    return
end
xe = xe(:).';
weight = weight(:).';
n = min([size(xt,2),numel(xe),numel(weight)]);
delta = xt(:,1:n) - xe(1:n);
distances = sqrt(sum(delta.^2 .* weight(1:n),2));
[closest_distance,idx] = min(distances);
closest_point = xt(idx,:);
end
