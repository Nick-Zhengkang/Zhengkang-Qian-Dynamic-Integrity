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

