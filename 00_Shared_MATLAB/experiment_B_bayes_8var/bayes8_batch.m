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
function [Q,B]=bayes8_batch(c,x,seeds,phase,tag)
paired=strcmp(phase,'confirmation');
seeds=reshape(seeds,1,[]);
stream=RandStream('mt19937ar','Seed',c.options.scheduleSeed);
ix=randperm(stream,numel(seeds)); seeds=seeds(ix);
order=ones(numel(seeds),1);
if paired
    order=zeros(numel(seeds),2);
    for j=1:numel(seeds), order(j,:)=randperm(stream,2); end
    schedule=table(seeds.',order(:,1),'VariableNames',{'seed','first_role_index'});
    surrogate_accuracy_util('table',schedule,fullfile(c.outDir,'confirmation_schedule.csv'));
end
cells=cell(numel(seeds),1);
directory=fullfile(c.outDir,'records');
if c.options.useParallel
    parfor j=1:numel(seeds)
        file=fullfile(directory,sprintf('%s_%s_seed%d.mat',phase,tag,seeds(j)));
        cells{j}=bayes8_job(c,x,seeds(j),phase,tag,order(j,:),file);
    end
else
    for j=1:numel(seeds)
        file=fullfile(directory,sprintf('%s_%s_seed%d.mat',phase,tag,seeds(j)));
        cells{j}=bayes8_job(c,x,seeds(j),phase,tag,order(j,:),file);
    end
end
R=vertcat(cells{:}); B=[];
if paired
    B=R([R.role]=="baseline"); Q=R([R.role]=="candidate");
    [~,j]=sort([B.seed]); B=B(j);
else
    Q=R;
end
[~,j]=sort([Q.seed]); Q=Q(j);
end
