% AI-assisted recovery helper. Does not run algorithms or edit original data.
% Use only after the parfor run has finished or has been stopped.
packageDirectory=fileparts(mfilename('fullpath'));
addpath(packageDirectory);
% Set an explicit results folder here, or leave empty for the newest timestamp.
resultsDirectory='';
if isempty(resultsDirectory)
    folders=dir(fullfile(packageDirectory,'results','20*')); folders=folders([folders.isdir]);
    assert(~isempty(folders),'No results folders found.');
    [~,order]=sort({folders.name}); newest=folders(order(end));
    resultsDirectory=fullfile(newest.folder,newest.name);
end
collect_ablation_results(resultsDirectory);
