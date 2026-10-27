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
function outDir=selftest_top6_smoke_resume()
% Optional real integration test: two runs, then resume without recomputation.
root=fileparts(mfilename('fullpath'));
oldFolder=pwd; oldPath=path;
restore=onCleanup(@() restore_test_session(oldFolder,oldPath));
addpath(root,'-begin');
% Reproduce launch from the previous study's folder with colliding helpers.
collisionFolder=fullfile(fileparts(root),'experiment_A_parameter_optimization');
cd(collisionFolder);
selftest_top6_exhaustive;
assert(strcmpi(pwd,collisionFolder),'Self-test did not restore the working folder.');
o=top6_options('smoke');
outDir=run_experiment_A_top6_exhaustive(o,'');
assert(strcmpi(pwd,collisionFolder),'Runner did not restore the working folder.');
files=dir(fullfile(outDir,'records','run_*.mat'));
assert(numel(files)==2,'Expected exactly two completed smoke runs.');
before=cell(2,1);
for i=1:2
    x=load(fullfile(files(i).folder,files(i).name),'row'); before{i}=x.row;
    assert(x.row.success && x.row.diagnostic_success,'A smoke run failed. Inspect its record.');
end
resumed=run_experiment_A_top6_exhaustive(o,outDir);
assert(strcmp(resumed,outDir));
assert(strcmpi(pwd,collisionFolder),'Resume did not restore the working folder.');
for i=1:2
    x=load(fullfile(files(i).folder,files(i).name),'row');
    assert(isequaln(x.row,before{i}),'Resume changed a completed record.');
end
fprintf('PASS: two real runs saved; completed-study resume preserved both records.\n');
end

function restore_test_session(folder,p)
cd(folder); path(p);
end
