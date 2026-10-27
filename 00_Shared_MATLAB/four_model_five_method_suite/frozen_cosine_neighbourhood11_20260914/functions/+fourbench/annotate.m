function T=annotate(T,reference)
T.relative_signed_error=T.signed_error./T.R_ref;
T.relative_absolute_error=T.absolute_error./T.R_ref;
T.within_1pct=T.success & T.relative_absolute_error<=.01;
T.within_2pct=T.success & T.relative_absolute_error<=.02;
T.within_5pct=T.success & T.relative_absolute_error<=.05;
T.reference_kind=repmat(string(reference.kind),height(T),1);
T.reference_source=repmat(string(reference.source),height(T),1);
T.damping_parameter_name=repmat("alpha",height(T),1);
T.damping_parameter_name(T.benchmark=="paper_unforced_duffing")="zeta";
T.comparison_profile=repmat("complete_methods_original_baselines",height(T),1);
end
