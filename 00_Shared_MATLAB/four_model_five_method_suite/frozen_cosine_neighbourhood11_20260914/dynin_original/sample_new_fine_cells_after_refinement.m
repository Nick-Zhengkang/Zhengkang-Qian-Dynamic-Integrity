function [R_after,stats] = sample_new_fine_cells_after_refinement(dim,par,new_fine_keys,R_current,target_points,weight,tfinal,Ts,tols,spaceboundary,adaptive_grid,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,sample_only_fine_cells_near_LIM,eta_fine_sample)
%SAMPLE_NEW_FINE_CELLS_AFTER_REFINEMENT Classify newly created fine cells.
% Each new fine-cell center is simulated with the adaptive finest-cell
% lookup. Decided trajectories label visited cells and nonconverging
% trajectories may update LIM through the original findradius rule.

R_after = R_current;
stats = struct( ...
    'number_of_new_fine_cells_sampled',0, ...
    'number_of_new_fine_cells_labelled_converging',0, ...
    'number_of_new_fine_cells_labelled_nonconverging',0, ...
    'number_of_new_fine_cells_labelled_unknown',0, ...
    'number_of_fine_cell_LIM_updates_from_sampling',0, ...
    'last_update',empty_update_debug());

if isempty(new_fine_keys)
    return
end
if nargin < 16 || isempty(sample_only_fine_cells_near_LIM)
    sample_only_fine_cells_near_LIM = true;
end
if nargin < 17 || isempty(eta_fine_sample)
    eta_fine_sample = 0.05;
end
if isvector(target_points)
    target_for_radius = target_points;
else
    target_for_radius = target_points(1,:);
end

new_fine_keys = unique(new_fine_keys,'stable');
for kk = 1:numel(new_fine_keys)
    key = new_fine_keys{kk};
    center = adaptive_grid.get_fine_cell_center(key);
    distance_to_target = adaptive_grid.get_distance_to_target(center,target_points,weight);

    if sample_only_fine_cells_near_LIM
        near_shell = abs(distance_to_target - R_current) < eta_fine_sample;
        inside_shell_band = distance_to_target < R_current + eta_fine_sample;
        if ~(near_shell || inside_shell_band)
            continue
        end
    end

    info = adaptive_grid.get_info_by_key(key);
    info.label = 'unknown';
    info.n_conv = 0;
    info.n_nonconv = 0;

    stats.number_of_new_fine_cells_sampled = stats.number_of_new_fine_cells_sampled + 1;
    [xt,~,visited_keys,tipo,~,~,early_stop_level] = simulation_DI_adaptive(dim,par,center,tfinal,Ts,tols,spaceboundary,adaptive_grid,rep_fix_point,rep_periodic,min_periodic_radius,check_min_periodic,weight);

    if tipo == 1
        adaptive_grid.update_cells(visited_keys,'converging');
        stats.number_of_new_fine_cells_labelled_converging = stats.number_of_new_fine_cells_labelled_converging + 1;
    elseif tipo > 1
        adaptive_grid.update_cells(visited_keys,'nonconverging');
        stats.number_of_new_fine_cells_labelled_nonconverging = stats.number_of_new_fine_cells_labelled_nonconverging + 1;
        R_candidate = findradius(xt,target_for_radius,weight);
        if R_candidate < R_after
            R_after = R_candidate;
            stats.number_of_fine_cell_LIM_updates_from_sampling = stats.number_of_fine_cell_LIM_updates_from_sampling + 1;
            [closest_point,closest_distance] = closest_point_to_target(xt,target_for_radius,weight);
            stats.last_update.source = 'fine_cell_sampling';
            stats.last_update.initial_condition = center;
            stats.last_update.closest_point = closest_point;
            stats.last_update.closest_distance = closest_distance;
            stats.last_update.classification = tipo;
            stats.last_update.stopped_by_cell = ~isempty(early_stop_level);
            stats.last_update.inherited_label = 'nonconverging';
            stats.last_update.early_stop_level = early_stop_level;
            stats.last_update.visited_first_cell = '';
            stats.last_update.visited_last_cell = '';
            if ~isempty(visited_keys)
                stats.last_update.visited_first_cell = visited_keys{1};
                stats.last_update.visited_last_cell = visited_keys{end};
            end
            stats.last_update.R_candidate = R_candidate;
        end
    else
        info = adaptive_grid.get_info_by_key(key);
        info.label = 'unknown';
        info.n_conv = 0;
        info.n_nonconv = 0;
        stats.number_of_new_fine_cells_labelled_unknown = stats.number_of_new_fine_cells_labelled_unknown + 1;
    end
end
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
