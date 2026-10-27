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
function selftest_top6_exhaustive()
root=fileparts(mfilename('fullpath'));
oldFolder=pwd; oldPath=path;
restore=onCleanup(@() restore_test_session(oldFolder,oldPath));
cd(root); addpath(root,'-begin');
assert(strcmpi(which('original_A_adapter'),fullfile(root,'original_A_adapter.m')));
assert(strcmpi(which('optimization_statistics'),fullfile(root,'optimization_statistics.m')));
o=top6_options(); [C,bid,meta]=top6_design(o);
assert(numel(C)==3240 && meta.planned_runs==9720);
assert(numel(unique(string({C.config_id})))==3240);
assert(nnz(string({C.config_id})==bid)==1);
names={'num_of_cell_around_equilibrium','discr','num_gen', ...
    'requested_newcomer_ratio','population_size','selected_opt'};
values={o.kValues,o.gridValues,o.generationValues,o.newcomerRatioValues, ...
    o.populationValues,o.selectedValues};
for j=1:numel(names)
    assert(isequal(sort(unique([C.(names{j})])),sort(values{j})));
    for v=values{j}
        assert(nnz([C.(names{j})]==v)==numel(C)/numel(values{j}));
    end
end

base=original_A_adapter('base');
for name={'number_of_steps','divR','num_almost_clones','rep_fix_point', ...
        'Ts','tfinal','reltol','abstol','rep_periodic'}
    assert(all([C.(name{1})]==base.(name{1})));
end
assert(all([C.num_crossover]>=1));
assert(all([C.population_size]==1+[C.newcomers]+[C.num_crossover]+[C.num_almost_clones]));
assert(all([C.newcomers]==round([C.population_size].*[C.requested_newcomer_ratio])));
Q=C([find(string({C.config_id})==bid,1) 1]);
rows=cell(6,1); i=0;
for j=1:2
    for seed=o.seeds
        i=i+1;
        rows{i}=struct('config_id',Q(j).config_id,'seed',seed,'success',true, ...
            'diagnostic_success',true,'relative_error',0.01-0.002*(j-1), ...
            'wall_runtime_s',2-0.5*(j-1),'algorithm_runtime_s',1, ...
            'trajectory_evaluations',100,'processed_time_samples',500, ...
            'diagnostic_runtime_s',0.1,'false_safe_rate',0,'false_unsafe_rate',0, ...
            'diagnostic_unresolved_rate',0,'diagnostic_truth_unresolved_rate',0, ...
            'timing_review_required',false);
    end
end
raw=struct2table(vertcat(rows{:}));
[S,b,d]=top6_summarize(raw,Q,bid,o);
assert(b.config_id==Q(2).config_id && ~b.confirmed && ~d.recommended);
assert(all(S.p95_error==S.max_error));
tie=raw; tie.wall_runtime_s(:)=2;
[~,b]=top6_summarize(tie,Q,bid,o);
assert(b.config_id==bid,'Equal runtime must not be called a speedup.');
raw.timing_review_required(4)=true;
[~,b]=top6_summarize(raw,Q,bid,o); assert(b.config_id==bid);
raw.timing_review_required(:)=false; raw.relative_error(4:6)=0.05;
[~,b]=top6_summarize(raw,Q,bid,o); assert(b.config_id==bid);
raw.timing_review_required(1)=true;
[~,b,d]=top6_summarize(raw,Q,bid,o);
assert(isempty(b) && strcmp(d.status,'baseline_timing_requires_review'));
fprintf('PASS: 3240 Cartesian combinations, 9720 runs, fixed controls, composition, ranking, timing gates.\n');
end

function restore_test_session(folder,p)
cd(folder); path(p);
end
