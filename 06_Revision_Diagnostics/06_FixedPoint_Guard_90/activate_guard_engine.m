function guard=activate_guard_engine(root,mode,d)
% AI-assisted path isolation: each process owns its own classifier and RNG.
old=path; guard=onCleanup(@() path(old));
clear sampled_forward_proposed sampled_forward_classifier sampled_forward_geometry
clear sampled_forward_integrate sampled_forward_step fixed_point_non_target_certificate sistema
clear fpguard_validate_independent
clear('limbench.angular_with_oracle');
engine=fullfile(root,'engines',char(mode));
addpath(fullfile(root,'shared'),fullfile(root,'shared','native'),engine,d.modelDir,'-begin');
rehash;
validator=which('fpguard_validate_independent');
assert(samepath(validator,fullfile(root,'fpguard_validate_independent.m')), ...
    'Wrong independent validator resolved: %s',validator);
assert(nargout('fpguard_validate_independent')==1, ...
    'Independent validator must return exactly one assessment table.');
names=["sampled_forward_proposed","sampled_forward_classifier", ...
    "sampled_forward_geometry","sampled_forward_integrate","sampled_forward_step"];
if mode=="fixed_point_guard", names(end+1)="fixed_point_non_target_certificate"; end
for name=names
    assert(samepath(which(char(name)),fullfile(engine,char(name+".m"))), ...
        'Wrong implementation resolved: %s',name);
end
assert(samepath(which('sistema'),fullfile(d.modelDir,'sistema.m')));
assert(samepath(which('limbench.angular_with_oracle'), ...
    fullfile(root,'shared','+limbench','angular_with_oracle.m')));
for name=["find_index","find_cells_around_a_cell"]
    assert(samepath(which(char(name)),fullfile(root,'shared','native',char(name+".m"))));
end
end
function yes=samepath(a,b)
yes=strcmpi(strrep(a,'\','/'),strrep(b,'\','/'));
end
