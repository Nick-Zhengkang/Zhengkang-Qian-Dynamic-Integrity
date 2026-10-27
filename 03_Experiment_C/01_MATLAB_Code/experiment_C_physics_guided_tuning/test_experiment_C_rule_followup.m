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
% Three staged tests of adjustment rules, without changing original DynIn GA.
% Run this file from the MATLAB Editor. Edit only the settings below.
here=fileparts(mfilename('fullpath'));
addpath(here);

stage='time_order'; % 'time_order', 'budget', or 'transfer'
mode='develop';     % 'smoke', 'develop' (10 seeds), 'confirm' (30 new seeds)

% Used only by stage='budget': paste a completed time_order/transfer folder.
sourceDir='';
% Resume this stage by pasting its output folder. Leave empty for a new run.
resumeDir='';

model='quadratic_cubic';
alpha=0.4;
transferModel='bistable_duffing';
transferAlpha=0.7; % Later repeat at 0.2 / 1.0 without tuning rule constants.
[model,alpha]=select_case(stage,model,alpha,transferModel,transferAlpha,sourceDir);

cfg=experiment_C_rule_defaults(mode);
outDir=run_experiment_C_rule_followup(stage,model,alpha,cfg,sourceDir,resumeDir);
fprintf('\nExperiment output:\n%s\n',outDir);

function [model,alpha]=select_case(stage,model,alpha,transferModel,transferAlpha,sourceDir)
if strcmp(stage,'transfer')
    model=transferModel; alpha=transferAlpha;
elseif strcmp(stage,'budget')
    file=fullfile(sourceDir,'frozen_time_first.mat');
    assert(~isempty(sourceDir) && isfile(file),'Set sourceDir to a completed follow-up folder.');
    data=load(file,'frozen');
    model=data.frozen.model; alpha=data.frozen.alpha;
end
end
