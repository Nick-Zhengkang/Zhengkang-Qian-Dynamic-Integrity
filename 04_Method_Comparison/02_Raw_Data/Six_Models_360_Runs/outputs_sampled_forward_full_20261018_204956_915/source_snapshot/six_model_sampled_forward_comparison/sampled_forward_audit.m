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

