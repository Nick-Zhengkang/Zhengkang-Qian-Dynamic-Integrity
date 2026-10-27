% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Experimental implementation and supporting functions.
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
