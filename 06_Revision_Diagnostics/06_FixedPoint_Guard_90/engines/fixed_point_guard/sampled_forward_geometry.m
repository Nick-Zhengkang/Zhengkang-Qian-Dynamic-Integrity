function g=sampled_forward_geometry(d)
% Reproduce compute_LIM_FP initialization using its own grid utilities.
dim=numel(d.target); g.dh=zeros(dim,1); g.cell_pos=zeros(d.discr,dim);
g.cell_e=zeros(dim,1);
for j=1:dim
    g.dh(j)=(d.domain(dim+j)-d.domain(j))/d.discr;
    g.cell_pos(:,j)=d.domain(j)+g.dh(j)/2:g.dh(j):d.domain(dim+j);
    [~,g.cell_e(j)]=min(abs(g.cell_pos(:,j)-d.target(j)));
end
g.cell_c=[find_index(g.cell_e,dim,d.discr); ...
    find_cells_around_a_cell(dim,g.cell_e,d.discr,d.targetCells)];
g.cell_d=zeros(0,1); g.cell_dout=zeros(0,1);
end

