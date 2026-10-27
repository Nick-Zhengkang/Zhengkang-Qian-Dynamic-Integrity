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
function stop=surrogate_accuracy_trace(~,v,state,c,restart)
stop=false;
if ~strcmp(state,'iter') || isempty(v.currentX), return; end
row=table2struct(bayes_A_design('table',round(reshape(v.currentX,1,[]))));
row.restart=restart; row.funccount=v.funccount;
row.current_objective=v.currentFval; row.best_objective=v.fval;
row.point_origin=string(v.currentFlag); row.elapsed_seconds=v.elapsedtime;
assert(row.point_origin~="initial",'Unexpected user-supplied initialization.');
folder=fullfile(c.outDir,'trace');
file=fullfile(folder,sprintf('restart%02d_eval%05d.mat',restart,v.funccount));
surrogate_accuracy_util('save',file,struct('row',row));
files=dir(fullfile(folder,'*.mat')); files=files(~endsWith(string({files.name}),'.tmp.mat'));
cells=cell(numel(files),1);
for j=1:numel(files)
    a=load(fullfile(files(j).folder,files(j).name),'row'); cells{j}=a.row;
end
T=sortrows(struct2table(vertcat(cells{:})),{'restart','funccount'});
surrogate_accuracy_util('table',T,fullfile(c.outDir,'optimizer_trace.csv'));
end
