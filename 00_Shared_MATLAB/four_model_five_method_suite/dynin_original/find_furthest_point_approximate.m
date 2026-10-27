function [x0,dist] = find_furthest_point_approximate(xe,R,v_inside,dim,weight,num_gen,num_crossover,selected_opt,newcomers,num_almost_clones)
% find_furthest_point_approximate(xe,R,v_inside,dim,weight,num_gen,gen_dim,selected_opt,newcomers,num_almost_clones)
% find the furthest point from a list of points v_inside, within the
% hypersphere of radius R and center xe. It uses a genetic algorithm.
% Each generation is made up of gen_dim = optimal individual +
% num_almost_clones of the best individual + individuals which are a
% combination of the best individuals (selescted_opt) + newcomers randomly
% generated.
% A larger population or a larger number of generations num_gen improve
% accuracy, but slow down the computation.

gen_dim=1+num_crossover+newcomers+num_almost_clones;

points = zeros(gen_dim,dim); % initialize vector of candidate points
for i = 1:gen_dim
    points(i,:) = randomIC_radius(dim,R,xe,weight); % generate uniformly distributed number in the convergence circle
end
for i1 = 1:num_gen % cycle on the preset number of generations
    % compute the minimal distance of each point of the population from 
    % points of v_inside. From the second generation the first point is
    % excluded, since it is already known
    if i1==1
        distances = minimal_distances(points,v_inside,weight);
    else
        distances(2:end) = minimal_distances(points(2:end,:),v_inside,weight);
    end
    [distances, ind] = sort(distances,'descend'); % organize the distances in decending order (we need the farthest, so the first of the reorganized sequence)
    if i1<num_gen % followign steps are not performed for the last generation
        temp_points = points(ind,:); % temporarily store the generation organized in descending order
        points(1,:) = temp_points(1,:); % save for the new generation the best one of the previous
        for i2 = 2:num_almost_clones+1 % generate new points (num_almost_clones) which are very similar to the best one
            points(i2,:) = points(1,:)+(rand(1,dim)-0.5)*R/10;
            if normweight(points(i2,:)-xe,weight)>R % if the point is outside the circle of convergence, then move it inside at distance R*0.95
                temp = (points(i2,:)-xe)/normweight(points(i2,:)-xe,weight)*R*0.99;
                points(i2,:) = xe+temp;
            end
        end
        for i2 = num_almost_clones+2:gen_dim-newcomers % generate individuals which are a combintation of the best individuals (selected_opt)
            for i3 = 1:dim
                rand_coef = rand(selected_opt,1); % weighting random coefficients for each best individual
                points(i2,i3) = temp_points(1:selected_opt,i3)'*rand_coef/sum(rand_coef); % compute the new individual as a combination of the best ones
            end
            if normweight(points(i2,:)-xe,weight)>R % if the point is outside the circle of convergence, then move it inside at distance R*0.95
                temp_ = (points(i2,:)-xe)/normweight(points(i2,:)-xe,weight)*R*0.99;
                points(i2,:) = xe+temp_;
            end
        end
        for i2 = gen_dim-newcomers:gen_dim % remaining individuals of the population are randomply generated
            points(i2,:) = randomIC_radius(dim,R,xe,weight);
        end
    end
end
x0 = points(1,:); % provide in ourput the global best individual
dist = distances(1); % provide in output the minimal distance of the furthest opint
