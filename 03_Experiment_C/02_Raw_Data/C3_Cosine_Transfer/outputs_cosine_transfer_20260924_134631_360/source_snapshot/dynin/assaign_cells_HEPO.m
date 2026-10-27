function [cell,ind]=assaign_cells_HEPO(cell,ind,cell_f,phase_IC,phase_out,Nt,tipo)


for J = 1:phase_IC-1
    if size(cell_f,1)>1
        puffer_length=find(cell_f(2:end,J)==0,1)-1;
        if isempty(puffer_length)
            puffer_length=size(cell_f,1);
        end
        cell(ind(J)+1:ind(J)+size(cell_f(2:puffer_length,J),1),J)=cell_f(2:puffer_length,J); % add cells to the list of cells
        ind(J)=ind(J)+size(cell_f(2:puffer_length,J),1); % update index of cells
    end
end

for J = phase_IC:Nt
    puffer_length=find(cell_f(:,J)==0,1)-1;
    if puffer_length<1
        break
    elseif isempty(puffer_length)
        puffer_length=size(cell_f,1);
    end
    cell(ind(J)+1:ind(J)+size(cell_f(1:puffer_length,J),1),J)=cell_f(1:puffer_length,J); % add cells to the list of cells
    ind(J)=ind(J)+size(cell_f(1:puffer_length,J),1); % update index of cells
end
if tipo<4
    cell(ind(phase_out),phase_out) = 0; % elliminate the last already known cell
    ind(phase_out)=ind(phase_out)-1;  % substracting the index of last already known cells
end