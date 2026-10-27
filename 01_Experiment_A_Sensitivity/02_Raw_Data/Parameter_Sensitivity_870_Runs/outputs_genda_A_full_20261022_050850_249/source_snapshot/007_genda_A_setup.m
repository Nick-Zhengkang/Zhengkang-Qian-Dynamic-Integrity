function c = genda_A_setup(o)
c.root = fileparts(mfilename('fullpath'));
c.repo = fileparts(c.root);
c.adapter = fullfile(c.repo,'experiment_A_top6_exhaustive');
c.native = fullfile(c.repo,'work','DynIn','DynIn_v1.1.0','functions');
c.model = fullfile(c.root,'model_genda_duffing');
c.referenceFunctions = fullfile(c.repo,'four_model_five_method_suite','functions');
c.utility = fullfile(c.repo,'experiment_B_surrogate_accuracy');
c.options = o;
genda_A_activate(c);
c.base = original_A_adapter('base');
c.base.model = "Genda bistable Duffing with quadratic damping";
c.base.par = struct('alpha',o.alpha);
c.base.xe = [-1 0];
c.base.weight = [1 1];
c.base.spaceboundary = [-3 -2 3 4];
[c.reference,c.referenceAudit] = limbench.reference('bistable_duffing',o.alpha);
c.reference.kind = 'analytical_equations_evaluated_numerically';
c.reference.published_source = 'https://doi.org/10.1007/s11071-026-12948-0';
c.base.reference_LIM = c.reference.R;
assert(abs(c.reference.R-.72892785915611505908)<1e-10, ...
    'Analytical reference differs from the independent high-precision check.');
assert(c.reference.resolutionDifference<1e-8);
end
