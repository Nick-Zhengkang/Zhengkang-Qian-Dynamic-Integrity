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
"""Replace only the cosine timing panel with the archived process CPU times."""
from pathlib import Path
import ast
import csv
import hashlib
import json
import shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCE = ROOT / 'experiment_C_physics_guided_tuning/outputs_cosine_transfer_20260924_134631_360'
(HERE / 'qa').mkdir(exist_ok=True)
dest = HERE / 'source_data/C_cosine_raw.csv'
shutil.copy2(SOURCE / 'raw_data_all_runs.csv', dest)
with dest.open(encoding='utf-8-sig', newline='') as f:
    rows = list(csv.DictReader(f))
groups = [sorted([r for r in rows if r['profile'] == p], key=lambda r: int(r['seed']))
          for p in ['historical_cosine', 'physics_rule']]
assert len(rows) == 60 and all(len(g) == 30 for g in groups)
assert all(r['status'] == 'ok' for r in rows)
assert [r['seed'] for r in groups[0]] == [r['seed'] for r in groups[1]]

# Reuse the original box/point styling without executing its other experiments.
old_script = ROOT / 'thesis_ABC_revised_20261017/build_figures.py'
tree = ast.parse(old_script.read_text(encoding='utf-8'))
nodes = []
for node in tree.body:
    if isinstance(node, ast.FunctionDef) and node.name in ['quantile', 'boxes']:
        nodes.append(node)
    elif isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
        if ast.unparse(node.value.func) == 'plt.rcParams.update':
            nodes.append(node)
COLORS = ['#B5BFC7', '#78B7BA', '#C8A878']
stats_rows = []
exec(compile(ast.Module(body=nodes, type_ignores=[]), str(old_script), 'exec'))
errors = [np.array([float(r['relative_error'])*100 for r in g]) for g in groups]
cpu = [np.array([float(r['cpu_s']) for r in g]) for g in groups]
assert all(np.isfinite(a).all() and (a > 0).all() for a in cpu)
np.testing.assert_allclose([quantile(a, .95) for a in errors], [1.54229892, 1.18210752], atol=1e-7)

# Two-panel quantitative comparison: accuracy stays unchanged; only time measure changes.
fig, axs = plt.subplots(1, 2, figsize=(6.8, 3.2), layout='constrained')
labels = ['Historical', 'Physics guided']
boxes(axs[0], errors, labels, 'Relative error (%)', '(a) Accuracy, 30 seeds')
boxes(axs[1], cpu, labels, 'Main-run CPU time (s, log scale)', '(b) CPU time, 30 seeds', log=True)
fig.legend(handles=[Line2D([], [], marker='D', linestyle='None', color='#B8582E',
                           markersize=5, label='P95 (separate from whisker)')],
           loc='outside lower center', fontsize=8)
for ext in ['pdf', 'svg']:
    fig.savefig(HERE / f'figures/Fig_C_Cosine_Boxplots.{ext}', bbox_inches='tight')
fig.savefig(HERE / 'qa/cosine_cpu.png', dpi=180, bbox_inches='tight')
plt.close(fig)

summary = []
for label, a in zip(labels, cpu):
    summary.append({'profile': label, 'n': len(a), 'median_cpu_s': float(np.median(a)),
                    'p95_cpu_s': float(quantile(a, .95)), 'min_cpu_s': float(min(a)),
                    'max_cpu_s': float(max(a))})
flag = next(r for r in rows if r['run_key'] == 'physics_rule_seed115')
audit = {'source_sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
         'timing_scope': 'cputime delta around compute_LIM_FP, before diagnostics and saving',
         'execution': 'serial for loop in archived MATLAB source; process CPU includes its threads',
         'all_60_records_retained': True, 'accuracy_data_unchanged': True,
         'quantiles': 'Hazen', 'summary': summary,
         'seed115_wall_s': float(flag['wall_s']), 'seed115_cpu_s': float(flag['cpu_s'])}
(HERE / 'source_data/cosine_cpu_audit.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')
print(json.dumps(audit, indent=2))
