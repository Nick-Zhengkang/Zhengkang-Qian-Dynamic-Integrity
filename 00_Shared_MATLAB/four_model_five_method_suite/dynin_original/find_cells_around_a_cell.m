function global_index = find_cells_around_a_cell(dim,cell_coord,discr,num)
% find_cells_around_a_cell(dim,cell_coord,discr,num)
% find the indeces of all the cells around the cell "cell_coord", such that
% a hypercube is built with cell_coord in the middle.
% "num" indicates the size, expressed in number of cells, of the built 
% hypercube around cell_coord

num=floor(abs(num));

% forcing num_of_cell_around_equilibrium to be odd
if rem(num,2)==0
    num=num-1;
%     error('num_of_cell_around_equilibrium should be an odd number');
end

new_cells = zeros(num^dim,dim);

% this cycle identifies the cells around the given one from the coordinate
% of the cell
for i1 = 1:num^dim % cycle which define num^dim points around the equilibrium
    for i2 = 1:dim % cycle on the dimension of the system
        new_cells(i1,i2) = (mod(ceil(i1/num^(dim-i2)),num)-floor(num/2))+cell_coord(i2);
    end
end

new_cells(1,:) = []; % the cycle above include also the cell itself, so it is eliminated here

% here the coordinate of the cells are transformed into global counting
global_index = zeros(num^dim-1,1);
for i = 1:num^dim-1
    global_index(i) = find_index(new_cells(i,:),dim,discr);
end

end