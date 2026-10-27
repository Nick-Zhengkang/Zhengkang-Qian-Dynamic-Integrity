function [cell,ind]=assaign_cells_LCO(cell,ind,cell_f,tipo)

if tipo==4
    cell(ind+1:ind+length(cell_f),1)=cell_f; % add cells to the list of cells
    ind=ind+length(cell_f); % update index of cells
else
    cell(ind+1:ind+length(cell_f)-1,1)=cell_f(1:end-1); % add cells to the list of cells
    ind=ind+length(cell_f)-1; % update index of cells
end