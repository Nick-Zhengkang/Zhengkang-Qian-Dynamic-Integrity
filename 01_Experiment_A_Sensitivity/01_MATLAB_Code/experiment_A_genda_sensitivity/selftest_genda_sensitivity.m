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
function selftest_genda_sensitivity(runNative)
% Fast design/reference contracts; optional short actual DynIn integration.
if nargin<1, runNative=false; end
oldPath=path; oldFolder=pwd; oldRng=rng;
cleanup=onCleanup(@() restore_session(oldPath,oldFolder,oldRng));
o=genda_A_options('pilot'); c=genda_A_setup(o);
test_storage();
D=genda_A_design(c.base,'full'); b=D(D.config_id=="baseline",:);
assert(height(D)==29 && numel(unique(D.changed_parameter))==15);
fullOptions=genda_A_options('full');
assert(isequal(fullOptions.seedList,99101:99130));
assert(height(D)*numel(fullOptions.seedList)==870);
assert(isequal(o.seedList,99101:99102));
smokeOptions=genda_A_options('smoke');
assert(isequal(smokeOptions.seedList,99101));
oldOptions=fullOptions; oldOptions.seedList=99101:99110;
try
    run_genda_sensitivity(oldOptions);
    error('gendaA:TestExpectedRejection','Old ten-seed full options were accepted.');
catch ME
    assert(strcmp(ME.identifier,'gendaA:FullSeedCount'), ...
        'Expected the full-mode seed-count validation to reject ten seeds.');
end
assert(height(genda_A_design(c.base,'smoke'))==3);
assert(b.discr==701 && b.num_of_cell_around_equilibrium==3 && b.population_size==20);
assert(b.newcomers==8 && b.num_crossover==9 && b.num_almost_clones==2);
assert(b.number_of_steps==100 && b.Ts==.05 && b.tfinal==2000);
assert(isequal(c.base.weight,[1 1]) && isequal(c.base.spaceboundary,[-3 -2 3 4]));
assert(norm(sistema(0,[0;2],c.base.par)-[2;-2.8])<1e-12);
assert(norm(sistema(0,[0;-2],c.base.par)-[-2;2.8])<1e-12);
assert(abs(c.base.reference_LIM-.7289278591561151)<1e-10);
addpath(fullfile(c.repo,'experiment_B_bayes_8var'));
bo=struct('modelId','genda_bistable_duffing','alpha',.7);
boBase=bayes8_problem(bo);
assert(isequaln(c.base,boBase),'A and B must use exactly the same physical model and baseline.');
numericFields=D.Properties.VariableNames(varfun(@isnumeric,D,'OutputFormat','uniform'));
for j=2:height(D)
    factor=D.changed_parameter(j);
    allowed=string(factor);
    switch factor
        case "target_neighborhood_cells", allowed="num_of_cell_around_equilibrium";
        case "ode_tolerance", allowed=["reltol","abstol"];
        case "population_size"
            allowed=["population_size","num_crossover","newcomers","num_almost_clones","newcomer_fraction"];
        case "newcomer_fraction", allowed=["newcomer_fraction","newcomers","num_crossover"];
        case "num_almost_clones", allowed=["num_almost_clones","num_crossover"];
    end
    for k=1:numel(numericFields)
        field=numericFields{k};
        if ~ismember(string(field),allowed)
            assert(isequaln(D.(field)(j),b.(field)),'Unexpected change in %s for %s.',field,factor);
        end
    end
end
assert(isequal(D.Ts(D.changed_parameter=="Ts"),[.025;.1]));
assert(isequal(D.number_of_steps(D.changed_parameter=="number_of_steps"),[50;200]));
assert(isequal(D.population_size(D.changed_parameter=="population_size"),[10;40]));
assert(prctile(1:10,95)==10,'Check percentile convention for small seed sets.');
fprintf('PASS: 14 factors, 29 configurations x 30 seeds = 870 full runs; pilot/smoke unchanged; analytical reference and identical BO baseline.\n');
if runNative
    cfg=table2struct(b); cfg.number_of_steps=2;
    rng(771,'twister'); r1=original_A_adapter('execute',cfg,c.base);
    alternate=c.base; alternate.reference_LIM=2*c.base.reference_LIM;
    rng(771,'twister'); r2=original_A_adapter('execute',cfg,alternate);
    assert(r1.success && r2.success && isequal(r1.R_hat,r2.R_hat), ...
        'Changing the scoring reference changed the native search.');
    assert(r1.relative_error~=r2.relative_error);
    fprintf('PASS: actual native DynIn runs; analytical reference changes scoring only.\n');
end
end

function test_storage()
% Reproduce a string-generated record path before any expensive trajectories.
file=char(string(tempname)+"_genda_A_record.mat");
csv=char(string(tempname)+"_genda_A_table.csv");
cleanup=onCleanup(@() remove_test_files({file,[file '.tmp.mat'],csv,[csv '.tmp.csv']}));
assert(ischar(file) && isrow([file '.tmp.mat']));
row=struct('config_id',"baseline",'seed',99101,'R_hat',.73);
surrogate_accuracy_util('save',file,struct('row',row));
saved=load(file,'row');
assert(isequaln(saved.row,row) && ~isfile([file '.tmp.mat']));
surrogate_accuracy_util('table',struct2table(row),csv);
savedTable=readtable(csv,'TextType','string');
assert(height(savedTable)==1 && savedTable.config_id==row.config_id && ...
    savedTable.seed==row.seed && abs(savedTable.R_hat-row.R_hat)<1e-12);
fprintf('PASS: string-generated filenames, atomic MAT/CSV writes and readback.\n');
end

function remove_test_files(files)
for j=1:numel(files)
    if isfile(files{j}), delete(files{j}); end
end
end

function restore_session(p,f,r)
cd(f); path(p); rng(r);
end
