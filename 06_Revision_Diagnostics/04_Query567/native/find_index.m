function index = find_index(cell,dim,discr)
% find_index(cell,dim,discr)
% from the coordinates of a cell, find its global index

index = 1;

for i = 1:dim
    index = index+(cell(i)-1)*discr^(dim-i);
end