function [kind,cellId]=sampled_forward_step(z,g,d,previousCells)
% Transcription of simulation_DI's checks AFTER each Ts interval.
% Keep native priority, strict domain tests, and recurrence inequalities.
dim=numel(d.target); coordinates=zeros(1,dim); cellId=0; kind=0;
for j=1:dim
    if z(j)>d.domain(j) && z(j)<d.domain(dim+j)
        index=find(g.cell_pos(:,j)>=z(j)-g.dh(j)/2 & ...
            g.cell_pos(:,j)<=z(j)+g.dh(j)/2,1);
        assert(~isempty(index),'Sample inside domain has no native grid cell.');
        coordinates(j)=index;
        cellId=find_index(coordinates,dim,d.discr);
    else
        % Preserve even the native partial exit-cell ID. Propagation later
        % applies the same stable-unique and final-entry exclusion as DynIn.
        kind=3; return
    end
end
if any(cellId==g.cell_c)
    kind=1; return
end
% AI-assisted ablation: do not read learned non-target or domain-exit labels.
% Target-cache reads, direct domain checks and recurrence rules are unchanged.
count=numel(previousCells)+1;
if kind~=0 || count<=3, return; end
prior=find(cellId==previousCells);
if isempty(prior), return; end
gaps=diff(prior);
if nnz(gaps==1)>d.repFixPoint
    kind=4;
elseif numel(prior)>d.repPeriodic+1 && prior(end)~=count-1
    if nnz(gaps~=1)>d.repPeriodic
        kind=4;
    end
end
end
