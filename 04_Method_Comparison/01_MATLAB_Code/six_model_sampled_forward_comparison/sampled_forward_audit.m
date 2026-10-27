% BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
% Scope: Proposed-method implementation, comparison, or supporting model code.
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
function sampled_forward_audit(T)
fields={'target','weight','domain','discr','target_cells','tfinal','Ts', ...
    'RelTol','AbsTol','rep_fix_point','rep_periodic','retry_unresolved', ...
    'energy_preclassification','grid_label_reuse','conflict_detection', ...
    'grid_label_priority','target_definition','backward_integration', ...
    'classifier','automatic','check_min_periodic','min_periodic_radius', ...
    'MaxStep','physical_cell_width','nominal_target_width','search_radius_cap'};
for id=reshape(unique(T.model_id),1,[])
    a=T(T.model_id==id & T.method=="dynin_original_ga",:);
    b=T(T.model_id==id & T.method=="proposed_sampled_forward",:);
    assert(height(a)==1 && height(b)==1);
    assert(a.integrator=="native segmented ode45");
    assert(b.integrator=="single ode45 with sampled callback");
    for j=1:numel(fields)
        f=fields{j};
        assert(isequaln(a.(f),b.(f)),'Fairness mismatch: %s / %s.',id,f);
    end
end
assert(~any(T.energy_preclassification | T.backward_integration | T.retry_unresolved));
fprintf('PASS: identical spatial/time controls and sampled classification rules for both methods.\n');
end

