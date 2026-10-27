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
function guard=sampled_forward_activate(d,repo)
oldPath=path; oldDir=pwd;
guard=onCleanup(@() restore(oldPath,oldDir));
native=fullfile(repo,'work','DynIn','DynIn_v1.1.0','functions');
addpath(d.modelDir,'-begin'); addpath(native,'-begin');
% MATLAB searches the current folder before the path. Some native model
% folders contain their own sys_solver.m, so use the shared solver folder
% as cwd and resolve only sistema.m from the selected model's path.
cd(native);
clear('sistema','simulation_DI','sys_solver','find_index','find_cells_around_a_cell');
rehash;
assert(samepath(which('sistema'),fullfile(d.modelDir,'sistema.m')), ...
    'Wrong model sistema.m for %s.',d.model_id);
for name=["simulation_DI","sys_solver","find_index","find_cells_around_a_cell"]
    resolved=which(char(name)); expected=fullfile(native,char(name+".m"));
    assert(samepath(resolved,expected), ...
        'Wrong native function: %s. Resolved: %s. Expected: %s.',name,resolved,expected);
end
end
function y=samepath(a,b)
y=strcmpi(strrep(a,'\','/'),strrep(b,'\','/'));
end
function restore(p,d)
path(p); cd(d);
end

