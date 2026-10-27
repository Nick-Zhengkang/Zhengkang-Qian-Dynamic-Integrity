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
function T=ma_batch(c,x,phase)
paired=strcmp(phase,'validation');
if paired
    alphas=c.options.validationAlpha; seeds=c.options.validationSeeds; refs=c.validationRef;
else
    alphas=c.options.trainAlpha; seeds=c.options.trainSeeds; refs=c.trainRef;
end
[ai,si]=ndgrid(1:numel(alphas),1:numel(seeds)); ai=ai(:); si=si(:);
stream=RandStream('mt19937ar','Seed',c.options.scheduleSeed);
ix=randperm(stream,numel(ai)); ai=ai(ix); si=si(ix);
first=ones(size(ai)); if paired, first=1+(rand(stream,size(ai))<.5); end
id=ma_design('key',x); cells=cell(numel(ai),1);
jobAlpha=reshape(alphas(ai),[],1); jobSeed=reshape(seeds(si),[],1);
jobRef=reshape(refs(ai),[],1); files=cell(numel(ai),1);
for j=1:numel(ai)
    files{j}=fullfile(c.outDir,'records',sprintf('%s_%s_a%02d_s%d.mat',phase,id,ai(j),jobSeed(j)));
end
if paired
    schedule=table(jobAlpha,jobSeed,first, ...
        'VariableNames',{'alpha','seed','first_role_index'});
    writetable(schedule,fullfile(c.outDir,'validation_schedule.csv'));
end
if c.options.useParallel
    parfor j=1:numel(ai)
        cells{j}=ma_job(c,x,jobAlpha(j),jobRef(j),jobSeed(j),phase,first(j),files{j});
    end
else
    for j=1:numel(ai)
        cells{j}=ma_job(c,x,jobAlpha(j),jobRef(j),jobSeed(j),phase,first(j),files{j});
    end
end
T=sortrows(struct2table(vertcat(cells{:})),{'alpha','seed','role'});
assert(height(T)==numel(alphas)*numel(seeds)*(1+paired));
end
