function genda_A_activate(c)
% Current-folder functions override the MATLAB path: activate the native folder.
addpath(c.root,c.adapter,c.utility,c.referenceFunctions,'-begin');
addpath(c.model,'-begin');
addpath(c.native,'-begin');
cd(c.native);
clear compute_LIM_FP simulation_DI sys_solver sistema original_A_adapter genda_A_job
rehash;
expected = {'compute_LIM_FP',c.native; 'simulation_DI',c.native; ...
    'sys_solver',c.native; 'sistema',c.model; 'original_A_adapter',c.adapter; ...
    'limbench.reference',fullfile(c.referenceFunctions,'+limbench')};
for j=1:size(expected,1)
    name=expected{j,1}; short=name;
    if strcmp(name,'limbench.reference'), short='reference'; end
    wanted=fullfile(expected{j,2},[short '.m']); actual=which(name);
    assert(strcmpi(strrep(actual,'\','/'),strrep(wanted,'\','/')), ...
        'gendaA:Path','Wrong active function %s. Resolved %s; expected %s.',name,actual,wanted);
end
end
