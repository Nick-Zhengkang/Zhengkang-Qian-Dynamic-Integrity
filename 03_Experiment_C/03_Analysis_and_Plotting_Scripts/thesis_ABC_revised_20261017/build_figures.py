# BEGIN AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
# Scope: Analysis and plotting implementation.
# This implementation was written/revised with OpenAI generative AI assistance.
# Author-declared contributions: Zhengkang Qian supplied the experimental
# concept, intended methodological direction, and specific revision requests.
# For MATLAB algorithms, the author reports line-by-line review and trial
# runs followed by iterative requests to address implementation/design mismatches.
# AI translated these instructions and method ideas into executable code.
# Existing third-party algorithms, source portions and licenses retain their
# original attribution; AI assistance does not imply authorship of DynIn.
# Review and testing do not certify mathematical or numerical correctness.
# See AI_USE_DECLARATION.md and AI_CODE_REGISTER.csv at the archive root.
# END AI ASSISTANCE AND AUTHOR CONTRIBUTIONS
#
"""Reproduce the thesis box plots from archived per-run CSV data."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.append(str(ROOT / '.thesis_abc_plot_dependencies'))
os.environ['MPLCONFIGDIR'] = str(HERE / 'qa' / 'matplotlib')
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

FIG = HERE / 'figures'
DATA = HERE / 'source_data'
QA = HERE / 'qa'
for folder in [FIG, DATA, QA]:
    folder.mkdir(parents=True, exist_ok=True)

# Preserve complete per-run records; figures use explicit subsets below.
SOURCES = {
    'A': 'experiment_A_dynin_GA_sensitivity/outputs_experiment_A_20260917_194039_202',
    'B': 'experiment_A_constrained_bayes/outputs_constrained_A_full_20261016_222759_333',
    'C_time': 'experiment_C_physics_guided_tuning/outputs_followup_time_order_quadratic_cubic_20260922_180048_508',
    'C_domain': 'experiment_C_physics_guided_tuning/outputs_anchored_GA_20260924_052507_013',
    'C_cosine': 'experiment_C_physics_guided_tuning/outputs_cosine_transfer_20260924_134631_360',
}
manifest = []
frames = {}
for key, folder in SOURCES.items():
    dest = DATA / (key + '_raw.csv')
    source = ROOT / folder / 'raw_data_all_runs.csv'
    if source.exists():
        shutil.copy2(source, dest)
    assert dest.exists(), f'Missing archived source data: {dest.name}'
    frames[key] = pd.read_csv(dest)
    manifest.append({'dataset': key, 'source_run': Path(folder).name,
                     'file': dest.name, 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
                     'rows': len(frames[key])})
for name in ['confirmation_summary.csv', 'search_observations.csv', 'decision.csv']:
    src = ROOT / SOURCES['B'] / name
    if src.exists():
        shutil.copy2(src, DATA / ('B_' + name))

plt.rcParams.update({
    'font.family': 'DejaVu Serif', 'font.size': 9,
    'axes.titlesize': 10, 'axes.labelsize': 9,
    'axes.spines.top': False, 'axes.spines.right': False,
    'axes.linewidth': 0.7, 'pdf.fonttype': 42, 'ps.fonttype': 42,
    'svg.fonttype': 'none', 'legend.frameon': False,
})
COLORS = ['#B5BFC7', '#78B7BA', '#C8A878']
stats_rows = []


def quantile(values, p):
    return np.quantile(np.asarray(values, dtype=float), p, method='hazen')


def boxes(ax, arrays, labels, ylabel, title, show_p95=True, log=False):
    stats = []
    arrays = [np.asarray(a, dtype=float) for a in arrays]
    for values in arrays:
        assert np.isfinite(values).all() and len(values) > 0
        q1, med, q3 = quantile(values, [.25, .5, .75])
        width = q3 - q1
        inside = values[(values >= q1 - 1.5 * width) & (values <= q3 + 1.5 * width)]
        # The degenerate-box case retains the observations equal to its median.
        assert len(inside)
        stats.append({'q1': q1, 'med': med, 'q3': q3,
                      'whislo': inside.min(), 'whishi': inside.max(), 'fliers': []})
    artists = ax.bxp(stats, positions=np.arange(1, len(arrays) + 1),
                     widths=.48, patch_artist=True, showfliers=False,
                     medianprops={'color': '#152830', 'linewidth': 1.5},
                     boxprops={'linewidth': .8}, whiskerprops={'linewidth': .8},
                     capprops={'linewidth': .8})
    rng = np.random.default_rng(7123)
    for i, (patch, values, label) in enumerate(zip(artists['boxes'], arrays, labels)):
        patch.set_facecolor(COLORS[i % len(COLORS)])
        patch.set_alpha(.8)
        ax.scatter(i + 1 + rng.uniform(-.16, .16, len(values)), values,
                   s=8 if len(values) >= 100 else 13, color='#39434A',
                   alpha=.38, linewidths=0, zorder=3)
        if show_p95:
            ax.scatter([i + 1 + .30], [quantile(values, .95)], marker='D',
                       s=25, facecolor='#B8582E', edgecolor='white', linewidth=.4, zorder=5)
        stats_rows.append({'panel': title, 'measure': ylabel, 'group': label.replace('\n', ' '),
                           'n': len(values), 'median': np.median(values),
                           'q1': quantile(values, .25), 'q3': quantile(values, .75),
                           'p95': quantile(values, .95), 'minimum': values.min(), 'maximum': values.max()})
    ax.set_xticks(np.arange(1, len(arrays) + 1), labels)
    ax.set_ylabel(ylabel)
    ax.set_title(title, loc='left', pad=8)
    ax.grid(axis='y', color='#DDE1E4', linewidth=.5)
    ax.set_axisbelow(True)
    if log:
        assert all((a > 0).all() for a in arrays), 'Log axes cannot hide zero errors.'
        ax.set_yscale('log')
    else:
        lo, hi = min(a.min() for a in arrays), max(a.max() for a in arrays)
        span = max(hi - lo, hi * .1, .01)
        ax.set_ylim(min(0, lo - .08 * span), hi + .15 * span)


def export(fig, name, p95=True):
    if p95:
        fig.legend(handles=[Line2D([], [], marker='D', linestyle='None', color='#B8582E',
                                   markersize=5, label='P95 (separate from whisker)')],
                   loc='outside lower center', fontsize=8)
    fig.savefig(FIG / (name + '.pdf'), bbox_inches='tight')
    fig.savefig(FIG / (name + '.svg'), bbox_inches='tight')
    fig.savefig(QA / (name + '.png'), dpi=170, bbox_inches='tight')
    plt.close(fig)


A = frames['A']
assert len(A) == 290 and (A.success == 1).all()
baseline = A[A.config_id == 'baseline']
factors = [
    ('target_neighborhood_cells', 'Target cells k', ['1', '3 (B)', '7']),
    ('discr', 'Grid resolution', ['351', '701 (B)', '1051']),
    ('num_gen', 'GA generations', ['2', '5 (B)', '10']),
    ('newcomer_fraction', 'Newcomer fraction', ['0.2', '0.4 (B)', '0.6']),
    ('population_size', 'Population size', ['10', '20 (B)', '40']),
    ('selected_opt', 'selected_opt', ['2', '3 (B)', '5']),
]
fig, axes = plt.subplots(2, 3, figsize=(7.0, 5.0), layout='constrained')
for i, (ax, (factor, title, labels)) in enumerate(zip(axes.flat, factors)):
    groups = [A[(A.changed_parameter == factor) & (A.level == 'low')],
              baseline, A[(A.changed_parameter == factor) & (A.level == 'high')]]
    assert all(len(d) == 10 for d in groups)
    boxes(ax, [d.relative_error * 100 for d in groups], labels,
          'Relative error (%)', f'({chr(97+i)}) {title}', log=True)
lims = (min(ax.get_ylim()[0] for ax in axes.flat), max(ax.get_ylim()[1] for ax in axes.flat))
for ax in axes.flat:
    ax.set_ylim(*lims)
export(fig, 'Fig_A_Distributions')

B = frames['B']
assert len(B) == 4100 and (B.success == 1).all() and (B.valid_for_score == 1).all()
assert not B.duplicated(['phase', 'evaluation_id', 'seed']).any()
confirmation = B[B.phase == 'confirm']
ids = ['k3_n701_g5_p20_new8_sel3', 'k7_n1035_g7_p10_new3_sel4']
groups = [confirmation[confirmation.config_id == key].sort_values('seed') for key in ids]
assert all(len(d) == 100 for d in groups)
assert groups[0].seed.tolist() == groups[1].seed.tolist()
summary = pd.read_csv(DATA / 'B_confirmation_summary.csv').set_index('config_id')
for key, d in zip(ids, groups):
    np.testing.assert_allclose(quantile(d.absolute_error, .95), summary.loc[key, 'p95_absolute_error'], atol=1e-12)
    np.testing.assert_allclose(d.core_wall_time_s.median(), summary.loc[key, 'median_core_wall_time_s'], atol=1e-10)
fig, axes = plt.subplots(1, 2, figsize=(6.8, 3.3), layout='constrained')
boxes(axes[0], [d.relative_error * 100 for d in groups], ['Baseline', 'Candidate'],
      'Relative error (%)', '(a) Accuracy, 100 seeds')
boxes(axes[1], [d.core_wall_time_s for d in groups], ['Baseline', 'Candidate'],
      'Core time (s)', '(b) Calculation time, 100 seeds')
export(fig, 'Fig_B_Confirmation_Boxplots')

C = frames['C_time']
groups = [C[C.rule_id == key] for key in ['period_only', 'double_period', 'decay_estimate']]
assert all(len(d) == 10 and (d.status == 'ok').all() for d in groups)
fig, axes = plt.subplots(1, 2, figsize=(6.8, 3.1), layout='constrained')
boxes(axes[0], [d.relative_error * 100 for d in groups], ['130', '260', '300'],
      'Relative error (%)', '(a) Accuracy, 10 seeds', show_p95=False, log=True)
boxes(axes[1], [d.wall_s for d in groups], ['130', '260', '300'],
      'Main-run time (s)', '(b) Calculation time, 10 seeds', show_p95=False)
for ax in axes:
    ax.set_xlabel('Integration horizon')
export(fig, 'Fig_C_Time_Boxplots', p95=False)

C = frames['C_domain']
assert len(C) == 180 and (C.status == 'ok').all()
fig, axes = plt.subplots(1, 3, figsize=(7.0, 3.2), layout='constrained', sharey=True)
for i, (ax, alpha) in enumerate(zip(axes, [.2, .7, 1.0])):
    groups = [C[(C.alpha == alpha) & (C.profile == key)].sort_values('seed')
              for key in ['original_domain', 'anchored_search_energy']]
    assert all(len(d) == 30 for d in groups)
    assert groups[0].seed.tolist() == groups[1].seed.tolist()
    boxes(ax, [d.signed_error * 100 for d in groups], ['Original', 'Corrected'],
          'Signed relative error (%)' if i == 0 else '',
          f'({chr(97+i)}) alpha = {alpha:.1f}', show_p95=False)
    ax.axhline(0, color='#696969', linestyle='--', linewidth=.7)
lo, hi = C.signed_error.min() * 100, C.signed_error.max() * 100
axes[0].set_ylim(lo - .08*(hi-lo), hi + .12*(hi-lo))
export(fig, 'Fig_C_Domain_Boxplots', p95=False)

C = frames['C_cosine']
groups = [C[C.profile == key].sort_values('seed') for key in ['historical_cosine', 'physics_rule']]
assert all(len(d) == 30 and (d.status == 'ok').all() for d in groups)
np.testing.assert_allclose([quantile(d.relative_error * 100, .95) for d in groups],
                           [1.54229892, 1.18210752], atol=1e-7)
fig, axes = plt.subplots(1, 2, figsize=(6.8, 3.2), layout='constrained')
labels = ['Historical', 'Physics guided']
boxes(axes[0], [d.relative_error * 100 for d in groups], labels,
      'Relative error (%)', '(a) Accuracy, 30 seeds')
boxes(axes[1], [d.wall_s for d in groups], labels,
      'Main-run time (s, log scale)', '(b) Calculation time, 30 seeds', log=True)
slow = C[C.wall_s > 100]
assert len(slow) == 1 and (slow.timing_review_flag == 1).all()
axes[1].annotate('Flagged timing record', xy=(2, float(slow.wall_s.iloc[0])),
                 xytext=(1.08, 2500), fontsize=8,
                 arrowprops={'arrowstyle': '->', 'color': '#565656', 'linewidth': .7})
export(fig, 'Fig_C_Cosine_Boxplots')

pd.DataFrame(stats_rows).to_csv(DATA / 'boxplot_statistics.csv', index=False)
(DATA / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
(QA / 'data_checks.json').write_text(json.dumps({
    'all_assertions_passed': True, 'quantile_method': 'Hazen (MATLAB-compatible)',
    'boxplot_source': 'individual saved runs; no reconstructed distributions',
    'B_confirmation_runs': 200, 'B_integer_neighbourhood_completed': False,
    'C_time_profiles_used': ['period_only', 'double_period', 'decay_estimate'],
    'old_interaction_results_used': False,
}, indent=2), encoding='utf-8')
print('PASS: five box-plot figures generated from verified per-run data.')
