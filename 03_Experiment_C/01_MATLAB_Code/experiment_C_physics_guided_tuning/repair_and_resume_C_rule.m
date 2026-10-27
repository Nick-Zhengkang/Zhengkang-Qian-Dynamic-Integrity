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
function outDir=repair_and_resume_C_rule(sourceDir)
% Narrow, audited migration for the missed quadratic-cubic escape event.
here=fileparts(mfilename('fullpath'));
sourceDir=char(sourceDir);
saved=load(fullfile(sourceDir,'run_configuration.mat'),'model','alpha','cfg');
assert(strcmp(saved.model,'quadratic_cubic'),'This recovery is for quadratic-cubic only.');
outDir=[sourceDir '_escape_fixed'];
marker=fullfile(outDir,'escape_fix_migration.mat');
if isfile(marker)
    prior=load(marker,'original_output','migration_complete');
    assert(prior.migration_complete && strcmp(prior.original_output,sourceDir), ...
        'Recovery folder belongs to a different experiment.');
    fprintf('Continuing the already repaired output: %s\n',outDir);
else
    assert(~isfolder(outDir), ...
        'Recovery folder exists without a completed migration marker. Keep it and inspect it before retrying.');
    archived=fullfile(sourceDir,'source_snapshot');
    names={'run_experiment_C_2d_hypotheses.m','experiment_C_rule_defaults.m', ...
        'experiment_C_rule_physics.m','experiment_C_rule_decision.m', ...
        'estimate_dynin_parameters_from_physics.m','experiment_C_2d_reference.m'};
    for i=1:numel(names)
        assert(strcmp(fileread(fullfile(here,names{i})),fileread(fullfile(archived,names{i}))), ...
            'A source file besides the approved escape-event fix has changed.');
    end
    funcDir=fullfile(fileparts(here),'work','DynIn','DynIn_v1.1.0','functions');
    originals={'compute_LIM_FP.m','simulation_DI.m'};
    for i=1:numel(originals)
        assert(strcmp(fileread(fullfile(funcDir,originals{i})), ...
            fileread(fullfile(archived,originals{i}))), 'Original DynIn source changed.');
    end
    assert(strcmp(fileread(fullfile(here,'transfer_2d_model','sistema.m')), ...
        fileread(fullfile(archived,'sistema.m'))),'Model RHS changed.');
    oldCode=fileread(fullfile(archived,'experiment_C_rule_diagnostics.m'));
    newCode=fileread(fullfile(here,'experiment_C_rule_diagnostics.m'));
    oldCode=strrep(oldCode,sprintf('\r\n'),newline);
    newCode=strrep(newCode,sprintf('\r\n'),newline);
    oldLine='    value=[value;1.01-z(1)]; isterminal=[1;1]; direction=[-1;-1];';
    newLines=['    % Detect entry into x>1,v>0, including turns beyond the old x=1.01 plane.' ...
        newline ...
        '    value=[value;max(1+1e-8-z(1),1e-8-z(2))]; isterminal=[1;1]; direction=[-1;-1];'];
    assert(isscalar(strfind(oldCode,oldLine)) && ...
        strcmp(strrep(oldCode,oldLine,newLines),newCode), ...
        'Diagnostic changes exceed the approved one-event correction.');

    test_experiment_C_rule_helpers;
    [~,f]=experiment_C_rule_physics('initial',saved.model,saved.alpha,saved.cfg);
    files={'calibration_truth.csv','holdout_truth.csv'};
    rows=cell(0,1); originalText=cell(size(files));
    for j=1:numel(files)
        file=fullfile(sourceDir,files{j});
        if ~isfile(file), continue; end
        originalText{j}=fileread(file);
        D=readtable(file,'TextType','string');
        fprintf('Rechecking %s: %d saved labels.\n',files{j},height(D));
        for i=1:height(D)
            timer=tic;
            [label,reason,simTime,errorText]=experiment_C_rule_diagnostics( ...
                'oracle',[D.x0(i) D.v0(i)],f,saved.cfg);
            assert(strlength(errorText)==0 && label==D.truth_label(i), ...
                'A saved truth label changed. Do not reuse the classifier cache; start a fresh experiment.');
            rows{end+1,1}=struct('source_file',string(files{j}), ...
                'point_id',D.point_id(i),'original_label',D.truth_label(i), ...
                'rechecked_label',label,'rechecked_reason',reason, ...
                'rechecked_sim_time',simTime,'recheck_wall_s',toc(timer)); %#ok<AGROW>
            if mod(i,20)==0 || i==height(D)
                fprintf('[recheck %s %d/%d] saved labels agree\n',files{j},i,height(D));
            end
        end
        assert(strcmp(originalText{j},fileread(file)), ...
            'The old experiment is still writing. Stop it with Ctrl+C before recovery.');
    end
    % Fork output data so old snapshots and all existing results remain intact.
    [ok,message]=copyfile(sourceDir,outDir);
    assert(ok,'Copying checkpoints failed: %s',message);
    for j=1:numel(files)
        if isempty(originalText{j}), continue; end
        assert(strcmp(originalText{j},fileread(fullfile(sourceDir,files{j}))) && ...
            strcmp(originalText{j},fileread(fullfile(outDir,files{j}))), ...
            'Truth checkpoint changed during recovery. Stop the old experiment first.');
    end
    copyfile(fullfile(outDir,'source_snapshot'),fullfile(outDir,'source_snapshot_before_escape_fix'));
    copyfile(fullfile(here,'experiment_C_rule_diagnostics.m'),fullfile(outDir,'source_snapshot'));
    writetable(struct2table(vertcat(rows{:})),fullfile(outDir,'escape_fix_label_recheck.csv'));
    original_output=sourceDir;
    migration_complete=true;
    correction="Detect entry into x>1,v>0 rather than crossing x=1.01 only.";
    timing_note="Completed timings retained; the interrupted runaway solve is not included. Recheck costs are separate.";
    save(marker,'original_output','migration_complete','correction','timing_note');
    fprintf('Completed labels match. Reusing diagnostic and GA checkpoints.\n');
end
outDir=run_experiment_C_2d_hypotheses(saved.model,saved.alpha,saved.cfg,outDir);
end
