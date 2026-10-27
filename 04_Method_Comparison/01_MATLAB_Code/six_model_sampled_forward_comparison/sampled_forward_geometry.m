% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Proposed-method implementation, comparison, or supporting model code.
% This implementation was written/revised with OpenAI generative AI assistance.
% Author-declared contributions: Zhengkang Qian supplied the experimental
% concept, intended methodological direction, and specific revision requests.
% For MATLAB algorithms, the author reports line-by-line review and trial
% runs followed by iterative requests to address implementation/design mismatches.
% AI translated these instructions and method ideas into executable code.
% Existing third-party algorithms, source portions and licenses retain their
% original attribution; AI assistance does not imply authorship of DynIn.
% Review and testing do not certify mathematical or numerical correctness.
% See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
% END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
%
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

