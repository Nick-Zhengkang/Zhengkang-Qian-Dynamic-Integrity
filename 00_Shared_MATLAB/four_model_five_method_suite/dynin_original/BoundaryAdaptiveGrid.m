classdef BoundaryAdaptiveGrid < handle
    %BOUNDARYADAPTIVEGRID Coarse grid plus boundary-triggered fine cells.
    % This class only manages cell labels and local refinement. It does not
    % change the original DynIn trajectory classification or LIM update rule.

    properties
        x_min
        x_max
        v_min
        v_max
        dx_coarse
        dv_coarse
        refine_factor = 4
        refine_every = 1
        max_refinement_level = 1
        inherit_parent_label_to_children = 0

        coarse_cells
        fine_cells
        refined_coarse_cells
        boundary_candidate_cells

        early_stops_from_coarse_grid = 0
        early_stops_from_fine_grid = 0
        fine_cell_visits = 0
        coarse_cell_visits = 0
        fine_cells_created = 0

        bisection_calls = 0
        fine_boundary_pairs_found = 0
        bisection_pairs_tested = 0
        valid_bisection_pairs = 0
        bisection_midpoints_simulated = 0
        bisection_nonconv_found = 0
        bisection_undefined_midpoints = 0
        bisection_LIM_updates = 0
        best_R_bis = Inf

        adaptive_unresolved_trajectories = 0
        boundary_candidates_total = 0
        boundary_candidates_near_LIM = 0
        refined_cells_near_LIM = 0
        skipped_boundary_candidates_far_from_LIM = 0
        bisection_pairs_total = 0
        bisection_pairs_near_LIM = 0

        new_fine_cells_sampled = 0
        new_fine_cells_labelled_converging = 0
        new_fine_cells_labelled_nonconverging = 0
        new_fine_cells_labelled_unknown = 0
        fine_cell_LIM_updates_from_sampling = 0
    end

    methods
        function obj = BoundaryAdaptiveGrid(x_min,x_max,v_min,v_max,dx_coarse,dv_coarse,refine_factor,refine_every,max_refinement_level,inherit_parent_label_to_children)
            if nargin >= 7 && ~isempty(refine_factor)
                obj.refine_factor = refine_factor;
            end
            if nargin >= 8 && ~isempty(refine_every)
                obj.refine_every = refine_every;
            end
            if nargin >= 9 && ~isempty(max_refinement_level)
                obj.max_refinement_level = max_refinement_level;
            end
            if nargin >= 10 && ~isempty(inherit_parent_label_to_children)
                obj.inherit_parent_label_to_children = inherit_parent_label_to_children;
            end

            obj.x_min = x_min;
            obj.x_max = x_max;
            obj.v_min = v_min;
            obj.v_max = v_max;
            obj.dx_coarse = dx_coarse;
            obj.dv_coarse = dv_coarse;

            obj.coarse_cells = containers.Map('KeyType','char','ValueType','any');
            obj.fine_cells = containers.Map('KeyType','char','ValueType','any');
            obj.refined_coarse_cells = containers.Map('KeyType','char','ValueType','logical');
            obj.boundary_candidate_cells = containers.Map('KeyType','char','ValueType','logical');
        end

        function initialize_equilibrium_cell(obj,xe)
            key = obj.coarse_key_from_point(xe);
            info = obj.get_info_by_key(key);
            info.label = 'converging';
            info.n_conv = max(info.n_conv,1);
        end

        function set_coarse_cells_by_index(obj,cell_indices,label,discr)
            if isempty(cell_indices)
                return
            end
            for kk = 1:numel(cell_indices)
                idx = cell_indices(kk);
                if idx < 1 || isnan(idx)
                    continue
                end
                i = floor((idx-1)/discr) + 1;
                j = mod(idx-1,discr) + 1;
                key = obj.coarse_key_from_indices(i,j);
                info = obj.get_info_by_key(key);
                if strcmp(label,'converging') || isequal(label,1)
                    info.n_conv = max(info.n_conv,1);
                    info.label = 'converging';
                elseif strcmp(label,'nonconverging') || isequal(label,2)
                    info.n_nonconv = max(info.n_nonconv,1);
                    info.label = 'nonconverging';
                end
            end
        end

        function [info,key] = get_cell_info(obj,y)
            coarse_key = obj.coarse_key_from_point(y);
            if isKey(obj.refined_coarse_cells,coarse_key)
                key = obj.fine_key_from_point(y,coarse_key);
                if ~isKey(obj.fine_cells,key)
                    obj.fine_cells(key) = CellInfo();
                    obj.fine_cells_created = obj.fine_cells_created + 1;
                end
                info = obj.fine_cells(key);
                obj.fine_cell_visits = obj.fine_cell_visits + 1;
            else
                key = coarse_key;
                if ~isKey(obj.coarse_cells,key)
                    obj.coarse_cells(key) = CellInfo();
                end
                info = obj.coarse_cells(key);
                obj.coarse_cell_visits = obj.coarse_cell_visits + 1;
            end
        end

        function update_cells(obj,visited_keys,final_label)
            if isempty(visited_keys)
                return
            end
            visited_keys = unique(visited_keys,'stable');
            for i = 1:length(visited_keys)
                key = visited_keys{i};
                info = obj.get_info_by_key(key);
                if strcmp(final_label,'converging')
                    info.n_conv = info.n_conv + 1;
                    info.label = 'converging';
                elseif strcmp(final_label,'nonconverging')
                    info.n_nonconv = info.n_nonconv + 1;
                    info.label = 'nonconverging';
                end
            end
        end

        function [debug,new_fine_keys] = detect_and_refine_boundary_cells(obj,R_current,target_points,weight,eta_LIM,max_refine_cells_per_iter,use_LIM_oriented_refinement)
            debug = obj.coarse_debug_counts();
            new_fine_keys = {};
            if obj.max_refinement_level < 1
                return
            end
            if nargin < 2 || isempty(R_current)
                R_current = Inf;
            end
            if nargin < 3 || isempty(target_points)
                target_points = [0 0];
            end
            if nargin < 4 || isempty(weight)
                weight = ones(1,size(target_points,2));
            end
            if nargin < 5 || isempty(eta_LIM)
                eta_LIM = Inf;
            end
            if nargin < 6 || isempty(max_refine_cells_per_iter)
                max_refine_cells_per_iter = Inf;
            end
            if nargin < 7 || isempty(use_LIM_oriented_refinement)
                use_LIM_oriented_refinement = 0;
            end

            fine_before = obj.fine_cells_created;
            refined_before = obj.refined_coarse_cells.Count;
            keys = obj.coarse_cells.keys;
            candidates = struct('key',{},'shell_error',{},'distance_to_target',{});
            for k = 1:length(keys)
                key = keys{k};
                info_here = obj.coarse_cells(key);
                if ~obj.is_converging_label(info_here.label) && ~obj.is_nonconverging_label(info_here.label)
                    continue
                end
                [i,j] = obj.parse_coarse_key(key);
                labels = obj.neighbor_labels(i,j);
                has_conv = obj.has_label(labels,'converging');
                has_nonconv = obj.has_label(labels,'nonconverging');
                if has_conv && has_nonconv
                    obj.boundary_candidate_cells(key) = true;
                    obj.boundary_candidates_total = obj.boundary_candidates_total + 1;
                    debug.num_coarse_boundary_candidates_before_LIM_filter = debug.num_coarse_boundary_candidates_before_LIM_filter + 1;
                    if use_LIM_oriented_refinement > 0.5
                        center = obj.coarse_cell_center_from_key(key);
                        d_target = obj.distance_to_target(center,target_points,weight);
                        shell_error = abs(d_target - R_current);
                        if shell_error < eta_LIM
                            obj.boundary_candidates_near_LIM = obj.boundary_candidates_near_LIM + 1;
                            debug.num_coarse_boundary_candidates_after_LIM_filter = debug.num_coarse_boundary_candidates_after_LIM_filter + 1;
                            candidates(end+1).key = key; %#ok<AGROW>
                            candidates(end).shell_error = shell_error;
                            candidates(end).distance_to_target = d_target;
                        else
                            obj.skipped_boundary_candidates_far_from_LIM = obj.skipped_boundary_candidates_far_from_LIM + 1;
                        end
                    else
                        candidates(end+1).key = key; %#ok<AGROW>
                        candidates(end).shell_error = 0;
                        candidates(end).distance_to_target = 0;
                        debug.num_coarse_boundary_candidates_after_LIM_filter = debug.num_coarse_boundary_candidates_after_LIM_filter + 1;
                    end
                end
            end

            if debug.num_coarse_boundary_candidates_before_LIM_filter == 0
                warning('No coarse-grid boundary candidates detected. Check label update and label encoding.')
            elseif debug.num_coarse_boundary_candidates_after_LIM_filter == 0 && use_LIM_oriented_refinement > 0.5
                warning('Boundary candidates detected, but all were rejected by LIM-shell filter. Consider increasing eta_LIM.')
            end

            if isempty(candidates)
                debug.num_refined_cells_this_iteration = obj.refined_coarse_cells.Count - refined_before;
                debug.num_fine_cells_created_this_iteration = obj.fine_cells_created - fine_before;
                return
            end

            [~,order] = sort([candidates.shell_error],'ascend');
            candidates = candidates(order);
            if isfinite(max_refine_cells_per_iter) && length(candidates) > max_refine_cells_per_iter
                candidates = candidates(1:max_refine_cells_per_iter);
            end

            for k = 1:length(candidates)
                was_refined = isKey(obj.refined_coarse_cells,candidates(k).key);
                created_keys = obj.refine_coarse_cell(candidates(k).key);
                new_fine_keys = [new_fine_keys, created_keys]; %#ok<AGROW>
                if ~was_refined && use_LIM_oriented_refinement > 0.5
                    obj.refined_cells_near_LIM = obj.refined_cells_near_LIM + 1;
                end
            end
            debug.num_refined_cells_this_iteration = obj.refined_coarse_cells.Count - refined_before;
            debug.num_fine_cells_created_this_iteration = obj.fine_cells_created - fine_before;
        end

        function created_keys = refine_coarse_cell(obj,coarse_key)
            created_keys = {};
            if isKey(obj.refined_coarse_cells,coarse_key)
                return
            end
            obj.refined_coarse_cells(coarse_key) = true;
            parent = obj.get_info_by_key(coarse_key);
            parent.is_refined = true;

            [ci,cj] = obj.parse_coarse_key(coarse_key);
            for fi = 1:obj.refine_factor
                for fj = 1:obj.refine_factor
                    fkey = obj.fine_key_from_indices(ci,cj,fi,fj);
                    if ~isKey(obj.fine_cells,fkey)
                        child = CellInfo();
                        if obj.inherit_parent_label_to_children > 0.5
                            child.label = parent.label;
                            child.n_conv = parent.n_conv;
                            child.n_nonconv = parent.n_nonconv;
                        end
                        obj.fine_cells(fkey) = child;
                        obj.fine_cells_created = obj.fine_cells_created + 1;
                        created_keys{end+1} = fkey; %#ok<AGROW>
                    end
                end
            end
        end

        function record_early_stop(obj,key)
            if startsWith(key,'fine:')
                obj.early_stops_from_fine_grid = obj.early_stops_from_fine_grid + 1;
            else
                obj.early_stops_from_coarse_grid = obj.early_stops_from_coarse_grid + 1;
            end
        end

        function record_adaptive_unresolved(obj)
            obj.adaptive_unresolved_trajectories = obj.adaptive_unresolved_trajectories + 1;
        end

        function [pairs,pair_stats] = find_fine_boundary_pairs(obj,max_pairs,xe0,weight,R_current,eta_bisect,use_LIM_oriented_refinement)
            if nargin < 2 || isempty(max_pairs)
                max_pairs = Inf;
            end
            if nargin < 3 || isempty(xe0)
                xe0 = [0 0];
            end
            if nargin < 4 || isempty(weight)
                weight = ones(1,numel(xe0));
            end
            if nargin < 5 || isempty(R_current)
                R_current = Inf;
            end
            if nargin < 6 || isempty(eta_bisect)
                eta_bisect = Inf;
            end
            if nargin < 7 || isempty(use_LIM_oriented_refinement)
                use_LIM_oriented_refinement = 0;
            end

            fine_keys = obj.fine_cells.keys;
            pair_stats.number_of_bisection_pairs_total = 0;
            pair_stats.number_of_bisection_pairs_near_LIM = 0;
            pairs = struct('conv_point',{},'nonconv_point',{},'conv_key',{},'nonconv_key',{},'distance',{},'distance_to_target',{},'shell_error',{});
            pair_keys = containers.Map('KeyType','char','ValueType','logical');

            for k = 1:length(fine_keys)
                key_a = fine_keys{k};
                info_a = obj.fine_cells(key_a);
                if ~(strcmp(info_a.label,'converging') || strcmp(info_a.label,'nonconverging'))
                    continue
                end
                [ci,cj,fi,fj] = obj.parse_fine_key(key_a);
                neighbor_subs = [0 1; 1 0; 0 -1; -1 0];
                for n = 1:size(neighbor_subs,1)
                    [nci,ncj,nfi,nfj] = obj.offset_fine_indices(ci,cj,fi,fj,neighbor_subs(n,1),neighbor_subs(n,2));
                    key_b = obj.fine_key_from_indices(nci,ncj,nfi,nfj);
                    if ~isKey(obj.fine_cells,key_b)
                        continue
                    end
                    info_b = obj.fine_cells(key_b);
                    if strcmp(info_a.label,info_b.label)
                        continue
                    end
                    if ~(strcmp(info_b.label,'converging') || strcmp(info_b.label,'nonconverging'))
                        continue
                    end

                    sorted_pair_key = char(strjoin(sort(string({key_a,key_b})),'|'));
                    if isKey(pair_keys,sorted_pair_key)
                        continue
                    end
                    pair_keys(sorted_pair_key) = true;
                    pair_stats.number_of_bisection_pairs_total = pair_stats.number_of_bisection_pairs_total + 1;

                    center_a = obj.fine_cell_center_from_key(key_a);
                    center_b = obj.fine_cell_center_from_key(key_b);
                    if strcmp(info_a.label,'converging')
                        conv_point = center_a;
                        nonconv_point = center_b;
                        conv_key = key_a;
                        nonconv_key = key_b;
                    else
                        conv_point = center_b;
                        nonconv_point = center_a;
                        conv_key = key_b;
                        nonconv_key = key_a;
                    end

                    midpoint = 0.5*(conv_point + nonconv_point);
                    distance_to_target = obj.distance_to_target(midpoint,xe0,weight);
                    shell_error = abs(distance_to_target - R_current);
                    if use_LIM_oriented_refinement > 0.5 && shell_error >= eta_bisect
                        continue
                    end
                    pair_stats.number_of_bisection_pairs_near_LIM = pair_stats.number_of_bisection_pairs_near_LIM + 1;
                    pairs(end+1).conv_point = conv_point; %#ok<AGROW>
                    pairs(end).nonconv_point = nonconv_point;
                    pairs(end).conv_key = conv_key;
                    pairs(end).nonconv_key = nonconv_key;
                    pairs(end).distance = norm(conv_point - nonconv_point);
                    pairs(end).distance_to_target = distance_to_target;
                    pairs(end).shell_error = shell_error;
                end
            end

            if ~isempty(pairs)
                if use_LIM_oriented_refinement > 0.5
                    [~,order] = sort([pairs.shell_error],'ascend');
                else
                    [~,order] = sort([pairs.distance_to_target],'ascend');
                end
                pairs = pairs(order);
                if isfinite(max_pairs) && length(pairs) > max_pairs
                    pairs = pairs(1:max_pairs);
                end
            end
        end

        function record_bisection_stats(obj,stats)
            obj.bisection_calls = obj.bisection_calls + stats.number_of_bisection_calls;
            obj.fine_boundary_pairs_found = obj.fine_boundary_pairs_found + stats.number_of_fine_boundary_pairs_found;
            obj.bisection_pairs_tested = obj.bisection_pairs_tested + stats.number_of_bisection_pairs_tested;
            obj.valid_bisection_pairs = obj.valid_bisection_pairs + stats.number_of_valid_bisection_pairs;
            obj.bisection_midpoints_simulated = obj.bisection_midpoints_simulated + stats.number_of_bisection_midpoints_simulated;
            obj.bisection_nonconv_found = obj.bisection_nonconv_found + stats.number_of_bisection_nonconv_found;
            if isfield(stats,'number_of_bisection_undefined_midpoints')
                obj.bisection_undefined_midpoints = obj.bisection_undefined_midpoints + stats.number_of_bisection_undefined_midpoints;
            end
            obj.bisection_LIM_updates = obj.bisection_LIM_updates + stats.number_of_bisection_LIM_updates;
            obj.best_R_bis = min(obj.best_R_bis,stats.best_R_bis);
            if isfield(stats,'number_of_bisection_pairs_total')
                obj.bisection_pairs_total = obj.bisection_pairs_total + stats.number_of_bisection_pairs_total;
            end
            if isfield(stats,'number_of_bisection_pairs_near_LIM')
                obj.bisection_pairs_near_LIM = obj.bisection_pairs_near_LIM + stats.number_of_bisection_pairs_near_LIM;
            end
        end

        function record_fine_sampling_stats(obj,stats)
            obj.new_fine_cells_sampled = obj.new_fine_cells_sampled + stats.number_of_new_fine_cells_sampled;
            obj.new_fine_cells_labelled_converging = obj.new_fine_cells_labelled_converging + stats.number_of_new_fine_cells_labelled_converging;
            obj.new_fine_cells_labelled_nonconverging = obj.new_fine_cells_labelled_nonconverging + stats.number_of_new_fine_cells_labelled_nonconverging;
            obj.new_fine_cells_labelled_unknown = obj.new_fine_cells_labelled_unknown + stats.number_of_new_fine_cells_labelled_unknown;
            obj.fine_cell_LIM_updates_from_sampling = obj.fine_cell_LIM_updates_from_sampling + stats.number_of_fine_cell_LIM_updates_from_sampling;
        end

        function stats = get_stats(obj)
            stats.number_of_refined_coarse_cells = obj.refined_coarse_cells.Count;
            stats.number_of_fine_cells_created = obj.fine_cells_created;
            stats.number_of_boundary_candidate_cells = obj.boundary_candidate_cells.Count;
            stats.number_of_early_stops_from_coarse_grid = obj.early_stops_from_coarse_grid;
            stats.number_of_early_stops_from_fine_grid = obj.early_stops_from_fine_grid;
            stats.number_of_fine_cell_visits = obj.fine_cell_visits;
            stats.number_of_coarse_cell_visits = obj.coarse_cell_visits;
            stats.number_of_bisection_calls = obj.bisection_calls;
            stats.number_of_fine_boundary_pairs_found = obj.fine_boundary_pairs_found;
            stats.number_of_bisection_pairs_tested = obj.bisection_pairs_tested;
            stats.number_of_valid_bisection_pairs = obj.valid_bisection_pairs;
            stats.number_of_bisection_midpoints_simulated = obj.bisection_midpoints_simulated;
            stats.number_of_bisection_nonconv_found = obj.bisection_nonconv_found;
            stats.number_of_bisection_undefined_midpoints = obj.bisection_undefined_midpoints;
            stats.number_of_bisection_LIM_updates = obj.bisection_LIM_updates;
            stats.best_R_bis = obj.best_R_bis;
            stats.number_of_adaptive_unresolved_trajectories = obj.adaptive_unresolved_trajectories;
            stats.number_of_boundary_candidates_total = obj.boundary_candidates_total;
            stats.number_of_boundary_candidates_near_LIM = obj.boundary_candidates_near_LIM;
            stats.number_of_refined_cells_near_LIM = obj.refined_cells_near_LIM;
            stats.number_of_skipped_boundary_candidates_far_from_LIM = obj.skipped_boundary_candidates_far_from_LIM;
            stats.number_of_bisection_pairs_total = obj.bisection_pairs_total;
            stats.number_of_bisection_pairs_near_LIM = obj.bisection_pairs_near_LIM;
            stats.number_of_new_fine_cells_sampled = obj.new_fine_cells_sampled;
            stats.number_of_new_fine_cells_labelled_converging = obj.new_fine_cells_labelled_converging;
            stats.number_of_new_fine_cells_labelled_nonconverging = obj.new_fine_cells_labelled_nonconverging;
            stats.number_of_new_fine_cells_labelled_unknown = obj.new_fine_cells_labelled_unknown;
            stats.number_of_fine_cell_LIM_updates_from_sampling = obj.fine_cell_LIM_updates_from_sampling;
        end

        function info = get_info_by_key(obj,key)
            if startsWith(key,'fine:')
                if ~isKey(obj.fine_cells,key)
                    obj.fine_cells(key) = CellInfo();
                    obj.fine_cells_created = obj.fine_cells_created + 1;
                end
                info = obj.fine_cells(key);
            else
                if ~isKey(obj.coarse_cells,key)
                    obj.coarse_cells(key) = CellInfo();
                end
                info = obj.coarse_cells(key);
            end
        end

        function center = get_fine_cell_center(obj,key)
            center = obj.fine_cell_center_from_key(key);
        end

        function d = get_distance_to_target(obj,point,target_points,weight)
            d = obj.distance_to_target(point,target_points,weight);
        end
    end

    methods (Access = private)
        function key = coarse_key_from_point(obj,y)
            i = obj.cell_index(y(1),obj.x_min,obj.x_max,obj.dx_coarse);
            j = obj.cell_index(y(2),obj.v_min,obj.v_max,obj.dv_coarse);
            key = obj.coarse_key_from_indices(i,j);
        end

        function key = coarse_key_from_indices(~,i,j)
            key = sprintf('coarse:%d:%d',i,j);
        end

        function key = fine_key_from_point(obj,y,coarse_key)
            [ci,cj] = obj.parse_coarse_key(coarse_key);
            x0 = obj.x_min + (ci-1)*obj.dx_coarse;
            v0 = obj.v_min + (cj-1)*obj.dv_coarse;
            dxf = obj.dx_coarse / obj.refine_factor;
            dvf = obj.dv_coarse / obj.refine_factor;
            fi = obj.cell_index(y(1),x0,x0+obj.dx_coarse,dxf);
            fj = obj.cell_index(y(2),v0,v0+obj.dv_coarse,dvf);
            key = obj.fine_key_from_indices(ci,cj,fi,fj);
        end

        function key = fine_key_from_indices(~,ci,cj,fi,fj)
            key = sprintf('fine:%d:%d:%d:%d',ci,cj,fi,fj);
        end

        function [ci,cj,fi,fj] = parse_fine_key(~,key)
            parts = split(string(key),':');
            ci = str2double(parts(2));
            cj = str2double(parts(3));
            fi = str2double(parts(4));
            fj = str2double(parts(5));
        end

        function [ci,cj,fi,fj] = offset_fine_indices(obj,ci,cj,fi,fj,di,dj)
            fi = fi + di;
            fj = fj + dj;
            while fi < 1
                ci = ci - 1;
                fi = fi + obj.refine_factor;
            end
            while fi > obj.refine_factor
                ci = ci + 1;
                fi = fi - obj.refine_factor;
            end
            while fj < 1
                cj = cj - 1;
                fj = fj + obj.refine_factor;
            end
            while fj > obj.refine_factor
                cj = cj + 1;
                fj = fj - obj.refine_factor;
            end
        end

        function center = fine_cell_center_from_key(obj,key)
            [ci,cj,fi,fj] = obj.parse_fine_key(key);
            dxf = obj.dx_coarse / obj.refine_factor;
            dvf = obj.dv_coarse / obj.refine_factor;
            x0 = obj.x_min + (ci-1)*obj.dx_coarse;
            v0 = obj.v_min + (cj-1)*obj.dv_coarse;
            center = [x0 + (fi-0.5)*dxf, v0 + (fj-0.5)*dvf];
        end

        function center = coarse_cell_center_from_key(obj,key)
            [ci,cj] = obj.parse_coarse_key(key);
            center = [obj.x_min + (ci-0.5)*obj.dx_coarse, obj.v_min + (cj-0.5)*obj.dv_coarse];
        end

        function d = weighted_distance(~,point,xe0,weight)
            point = point(:).';
            xe0 = xe0(:).';
            weight = weight(:).';
            n = min([numel(point),numel(xe0),numel(weight)]);
            delta = point(1:n) - xe0(1:n);
            d = sqrt(sum(weight(1:n) .* delta.^2));
        end

        function d = distance_to_target(obj,point,target_points,weight)
            if isempty(target_points)
                target_points = zeros(1,numel(point));
            end
            if isvector(target_points)
                d = obj.weighted_distance(point,target_points(:).',weight);
                return
            end
            distances = zeros(size(target_points,1),1);
            for kk = 1:size(target_points,1)
                distances(kk) = obj.weighted_distance(point,target_points(kk,:),weight);
            end
            d = min(distances);
        end

        function debug = coarse_debug_counts(obj)
            keys = obj.coarse_cells.keys;
            n_conv = 0;
            n_nonconv = 0;
            n_known_unknown = 0;
            for kk = 1:numel(keys)
                info = obj.coarse_cells(keys{kk});
                if obj.is_converging_label(info.label)
                    n_conv = n_conv + 1;
                elseif obj.is_nonconverging_label(info.label)
                    n_nonconv = n_nonconv + 1;
                else
                    n_known_unknown = n_known_unknown + 1;
                end
            end
            nx = max(1,ceil((obj.x_max - obj.x_min)/obj.dx_coarse));
            nv = max(1,ceil((obj.v_max - obj.v_min)/obj.dv_coarse));
            n_total = nx * nv;
            debug.num_coarse_converging_cells = n_conv;
            debug.num_coarse_nonconverging_cells = n_nonconv;
            debug.num_coarse_unknown_cells = max(0,n_total - n_conv - n_nonconv);
            debug.num_coarse_known_unknown_cells = n_known_unknown;
            debug.num_coarse_boundary_candidates_before_LIM_filter = 0;
            debug.num_coarse_boundary_candidates_after_LIM_filter = 0;
            debug.num_refined_cells_this_iteration = 0;
            debug.num_fine_cells_created_this_iteration = 0;
            debug.number_of_new_fine_cells_sampled = 0;
            debug.number_of_new_fine_cells_labelled_converging = 0;
            debug.number_of_new_fine_cells_labelled_nonconverging = 0;
            debug.number_of_new_fine_cells_labelled_unknown = 0;
            debug.number_of_fine_cell_LIM_updates_from_sampling = 0;
        end

        function tf = has_label(obj,labels,label)
            tf = false;
            for kk = 1:numel(labels)
                if strcmp(label,'converging') && obj.is_converging_label(labels{kk})
                    tf = true;
                    return
                elseif strcmp(label,'nonconverging') && obj.is_nonconverging_label(labels{kk})
                    tf = true;
                    return
                end
            end
        end

        function tf = is_converging_label(~,label)
            tf = (ischar(label) && strcmp(label,'converging')) || ...
                (isstring(label) && strcmp(label,"converging")) || ...
                (isnumeric(label) && isequal(label,1));
        end

        function tf = is_nonconverging_label(~,label)
            tf = (ischar(label) && strcmp(label,'nonconverging')) || ...
                (isstring(label) && strcmp(label,"nonconverging")) || ...
                (isnumeric(label) && label > 1);
        end

        function labels = neighbor_labels(obj,i,j)
            labels = {};
            for ii = i-1:i+1
                for jj = j-1:j+1
                    key = obj.coarse_key_from_indices(ii,jj);
                    if isKey(obj.coarse_cells,key)
                        info = obj.coarse_cells(key);
                        labels{end+1} = info.label; %#ok<AGROW>
                    end
                end
            end
        end

        function [i,j] = parse_coarse_key(~,key)
            parts = split(string(key),':');
            i = str2double(parts(2));
            j = str2double(parts(3));
        end

        function ix = cell_index(~,value,min_value,max_value,spacing)
            ix = floor((value - min_value) / spacing) + 1;
            ix = max(1,ix);
            ix_max = max(1,ceil((max_value - min_value) / spacing));
            ix = min(ix,ix_max);
        end
    end
end
