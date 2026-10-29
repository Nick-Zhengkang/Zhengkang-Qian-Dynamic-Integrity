function out=fpguard_launch(root,o)
% Resolve all orchestration from this package, even from an old snapshot cwd.
oldDir=pwd; oldPath=path;
restore=onCleanup(@() restore_state(oldDir,oldPath)); %#ok<NASGU>
cd(root); addpath(root,'-begin');
clear run_fixedpoint_all90 run_guard_preflight validate_guard_points
clear activate_guard_engine run_fixedpoint_case fpguard_validate_independent
rehash;
out=run_fixedpoint_all90(o);
end
function restore_state(folder,p)
cd(folder); path(p);
end
