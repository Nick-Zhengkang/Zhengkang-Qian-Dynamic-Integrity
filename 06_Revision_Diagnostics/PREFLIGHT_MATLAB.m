function PREFLIGHT_MATLAB
% AI-assisted local MATLAB path check; no ODE integrations or data rewrites.
here=fileparts(mfilename('fullpath')); root=fileparts(here);
data=fullfile(root,'04_Method_Comparison','02_Raw_Data','Six_Models_360_Runs', ...
    'outputs_sampled_forward_full_20261018_204956_915');
savedPath=path; restore=onCleanup(@() path(savedPath)); %#ok<NASGU>
fprintf('MATLAB: %s\n',version);
assert(isfolder(data),'Download the complete repository.');
assert(license('test','Distrib_Computing_Toolbox'), ...
    'The 90-case parfor retest requires Parallel Computing Toolbox.');
for model=["quadratic_cubic","bistable_duffing","genda_cosine_quadratic_drag"]
    folder=fullfile(data,'dynin_models',char(model));
    addpath(folder,'-begin'); clear sistema; rehash;
    assert(strcmpi(which('sistema'),fullfile(folder,'sistema.m')));
    for seed=1:30
        assert(isfile(fullfile(data,'runs',sprintf('%s__proposed_sampled_forward__seed_%d.mat',model,seed))));
    end
    rmpath(folder); clear sistema;
end
for package=["02_Negative_Cache_9","03_Negative_Cache_90"]
    folder=fullfile(here,char(package)); temp=tempname; mkdir(temp);
    addpath(folder,'-begin'); clear verify_ablation_sources;
    verify_ablation_sources(folder,data,temp);
    fprintf('Source audit report: %s\n',fullfile(temp,'source_verification.csv'));
    rmpath(folder);
end
fprintf('MATLAB path/source preflight PASS. No numerical experiment was run.\n');
end
