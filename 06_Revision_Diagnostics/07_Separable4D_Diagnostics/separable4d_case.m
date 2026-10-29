function result=separable4d_case(root,out,seed,selection,o)
% AI-assisted diagnostic instrumentation. Frozen numerical functions unchanged.
caseOut=fullfile(out,sprintf('seed_%02d',seed)); mkdir(caseOut);
result=struct('seed',seed,'replay_matches',false,'queries_replayed',0, ...
    'upper_query',selection.upper_query,'first_under_query',selection.first_non_target_below_query, ...
    'winning_root_query',NaN,'winning_root_reason',"",'winning_chain_length',0, ...
    'upper_independent_outcome',"not_run",'lower_independent_outcome',"not_run", ...
    'midpoint_independent_outcome',"not_run",'error_message',"");
oldpath=path; pathguard=onCleanup(@() path(oldpath)); %#ok<NASGU>
addpath(fullfile(root,'engine'),fullfile(root,'native'),fullfile(root,'model'),'-begin');
try
    assert(strcmp(which('sistema'),fullfile(root,'model','sistema.m')));
    assert(strcmp(which('sampled_forward_integrate'),fullfile(root,'engine','sampled_forward_integrate.m')));
    settings=load(fullfile(root,'input','separable_qc_bd_4d_settings.mat'),'dynin');
    d=settings.dynin; d.modelDir=fullfile(root,'model');
    filename=sprintf('separable_qc_bd_4d__proposed_sampled_forward__seed_%d.mat',seed);
    saved=load(fullfile(root,'input','runs',filename),'row','details');
    assert(saved.row.seed==seed && abs(saved.row.R_hat-selection.midpoint)<1e-12);
    trace=replay_separable4d(d,saved.details.query_records,selection,caseOut,o);
    result.replay_matches=trace.reproduced;
    result.queries_replayed=height(trace.queries);
    if trace.reproduced
        result.winning_root_query=trace.winning_chain(end);
        result.winning_root_reason=trace.queries.reason(result.winning_root_query);
        result.winning_chain_length=numel(trace.winning_chain);
        if o.validateEndpoints || o.validateLabelChain
            assessment=validate_separable4d(d,trace,selection,caseOut,o);
            for role=["winning_upper","winning_lower","reported_midpoint"]
                hit=find(assessment.role==role,1);
                if ~isempty(hit)
                    if role=="winning_upper", result.upper_independent_outcome=assessment.conclusion(hit); end
                    if role=="winning_lower", result.lower_independent_outcome=assessment.conclusion(hit); end
                    if role=="reported_midpoint", result.midpoint_independent_outcome=assessment.conclusion(hit); end
                end
            end
        end
    end
catch err
    result.error_message=string(getReport(err,'extended','hyperlinks','off'));
    fid=fopen(fullfile(caseOut,'ERROR.txt'),'w');
    if fid>=0, fprintf(fid,'%s\n',result.error_message); fclose(fid); end
end
writetable(struct2table(result),fullfile(caseOut,'case_summary.csv'));
fprintf('Seed %d finished: replay_matches=%d, upper=%s\n',seed,result.replay_matches,result.upper_independent_outcome);
end
