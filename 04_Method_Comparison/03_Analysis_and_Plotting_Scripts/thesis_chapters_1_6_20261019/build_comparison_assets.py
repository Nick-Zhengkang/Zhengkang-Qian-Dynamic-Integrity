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
"""Recompute Chapter 6 tables and box plots from the frozen 360-run archive."""
from pathlib import Path
from collections import Counter
import csv
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
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

ARCHIVE = ROOT / 'experiment_archives/Six_Model_Sampled_Forward_30Seeds_20261018_204956/Results'
DATA = HERE / 'source_data/comparison'
TABLES = HERE / 'tables'
FIG = HERE / 'figures'
QA = HERE / 'qa'
for directory in [DATA, TABLES, FIG, QA]:
    directory.mkdir(parents=True, exist_ok=True)

def read_csv(path):
    with path.open(encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle))

provenance = []
for filename in ['raw_data_all_runs.csv', 'summary_by_model_and_method.csv',
                 'configuration_manifest.csv', 'paired_contrasts_by_seed.csv',
                 'randomized_execution_schedule.csv', 'benchmark_references.csv']:
    source = ARCHIVE / filename
    if not source.exists():
        source = DATA / filename
    if source.exists():
        destination = DATA / filename
        if source.resolve() != destination.resolve():
            shutil.copy2(source, destination)
        provenance.append({'file': filename, 'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()})
raw = read_csv(DATA / 'raw_data_all_runs.csv')
saved = read_csv(DATA / 'summary_by_model_and_method.csv')
D, P = 'dynin_original_ga', 'proposed_sampled_forward'
MODELS = ['quadratic_cubic', 'bistable_duffing', 'habib_unforced_duffing',
          'genda_cosine_quadratic_drag', 'separable_qc_bd_4d', 'habib_vdp_tmd_4d']
NAMES = ['Quadratic-cubic', 'Bistable Duffing', 'Unforced Duffing',
         'Cosine potential', 'Separable 4D', 'Coupled 4D']
assert len(raw) == 360 and len({r['run_key'] for r in raw}) == 360
assert all(r['execution_ok'] == '1' for r in raw)
assert all(r['energy_preclassification'] == '0' and r['backward_integration'] == '0' for r in raw)

def quantile(a, p):
    return np.quantile(np.asarray(a, float), p, method='hazen')

def values(rows, key):
    return np.asarray([float(r[key]) for r in rows])

groups, stats = {}, {}
for model in MODELS:
    stats[model] = {}
    for method in [D, P]:
        rows = sorted([r for r in raw if r['model_id'] == model and r['method'] == method], key=lambda r: int(r['seed']))
        assert [int(r['seed']) for r in rows] == list(range(1, 31))
        groups[model, method] = rows
        r = values(rows, 'R_hat'); t = values(rows, 'algorithm_runtime_s')
        assert np.isfinite(r).all() and np.isfinite(t).all() and (t > 0).all()
        reference = float(rows[0]['R_reference'])
        s = {'n': 30, 'median_R': float(np.median(r)), 'q25_R': float(quantile(r, .25)),
             'q75_R': float(quantile(r, .75)), 'min_R': float(r.min()), 'max_R': float(r.max()),
             'median_time': float(np.median(t)), 'p95_time': float(quantile(t, .95)),
             'queries': float(np.median(values(rows, 'query_count'))),
             'ode_calls': float(np.median(values(rows, 'ode_solver_calls'))),
             'stops': dict(Counter(x['stop_status'] for x in rows)),
             'review_flags': sum(x['review_required'] == '1' for x in rows)}
        summary = next(x for x in saved if x['model_id'] == model and x['method'] == method)
        assert np.isclose(s['median_R'], float(summary['median_R_hat_valid']), atol=1e-12, rtol=1e-12)
        assert np.isclose(s['median_time'], float(summary['median_algorithm_runtime_s']), rtol=1e-12)
        if np.isfinite(reference):
            errors = abs(r - reference) / reference * 100
            signed = (r - reference) / reference * 100
            assert np.allclose(errors, values(rows, 'relative_error') * 100, atol=1e-11)
            s.update(median_error=float(np.median(errors)), p95_error=float(quantile(errors, .95)),
                     max_error=float(errors.max()), median_signed=float(np.median(signed)),
                     within_1=int(sum(errors <= 1)), within_2=int(sum(errors <= 2)),
                     below_reference=int(sum(r < reference)))
            assert np.isclose(s['p95_error'], float(summary['p95_relative_error_valid'])*100, atol=1e-10)
            assert s['within_1'] == int(summary['within_1pct_count'])
        else:
            assert model == MODELS[-1] and all(np.isnan(values(rows, 'relative_error')))
        stats[model][method] = s
    a, b = groups[model, D], groups[model, P]
    assert [x['algorithm_seed'] for x in a] == [x['algorithm_seed'] for x in b]
    stats[model]['comparison'] = {
        'ratio_of_median_times': stats[model][D]['median_time']/stats[model][P]['median_time'],
        'proposed_faster_pairs': int(sum(values(b, 'algorithm_runtime_s') < values(a, 'algorithm_runtime_s')))}
    if model != MODELS[-1]:
        stats[model]['comparison']['proposed_lower_error_pairs'] = int(sum(values(b, 'relative_error') < values(a, 'relative_error')))

# Each table is generated from the raw records, not copied from rounded prose.
def write_table(name, caption, label, spec, header, lines):
    body = '\n'.join(line + r' \\' for line in lines)
    text = (r'\begin{table}[htbp]'+'\n'+r'\centering\small'+'\n'
            +r'\caption{'+caption+'}\n'+r'\label{'+label+'}\n'
            +r'\begin{tabularx}{\linewidth}{'+spec+'}\n'+r'\toprule'+'\n'
            +header+r' \\'+'\n'+r'\midrule'+'\n'+body+'\n'
            +r'\bottomrule'+'\n'+r'\end{tabularx}'+'\n'+r'\end{table}'+'\n')
    (TABLES / name).write_text(text, encoding='utf-8')

for selected, name, caption, label in [
    (MODELS[:4], 'ch6_accuracy_2d.tex', 'Two-dimensional results over 30 seeds per method. Error values are percentages. The unforced Duffing errors are differences from a published numerical reference.', 'tab:comparison-2d'),
    ([MODELS[4]], 'ch6_accuracy_separable.tex', 'Separable four-dimensional results over 30 seeds per method. The reference LIM is 0.6474801597. Error values are percentages.', 'tab:comparison-separable')]:
    lines = []
    for model in selected:
        for method, display in [(D, 'DynIn GA'), (P, 'Proposed')]:
            s = stats[model][method]
            lines.append(f"{NAMES[MODELS.index(model)]} & {display} & {s['median_R']:.6f} & {s['median_error']:.3f} & {s['p95_error']:.3f} & {s['within_1']}/30")
    write_table(name, caption, label, '@{}Y l r r r r@{}',
                r'Model & Method & Median $\hat R$ & Median error & P95 & Within 1\%', lines)

lines = []
for method, display in [(D, 'DynIn GA'), (P, 'Proposed')]:
    s = stats[MODELS[-1]][method]
    lines.append(f"{display} & {s['median_R']:.6f} & {s['q25_R']:.6f} & {s['q75_R']:.6f} & {s['min_R']:.6f} & {s['max_R']:.6f}")
write_table('ch6_coupled.tex', 'Coupled four-dimensional LIM estimates over 30 seeds. No reference error is assigned to this model.',
            'tab:comparison-coupled', '@{}Y r r r r r@{}',
            r'Method & Median $\hat R$ & Q1 & Q3 & Minimum & Maximum', lines)

lines, calls = [], []
for model, name in zip(MODELS, NAMES):
    d, p, c = stats[model][D], stats[model][P], stats[model]['comparison']
    lines.append(f"{name} & {d['median_time']:.3f} & {p['median_time']:.3f} & {c['ratio_of_median_times']:.2f} & {c['proposed_faster_pairs']}/30")
    calls.append(f"{name} & {d['queries']:g} & {p['queries']:g} & {d['ode_calls']:g} & {p['ode_calls']:g}")
write_table('ch6_cost.tex', 'Median core algorithm time in seconds. The time ratio is the DynIn median divided by the Proposed median, not the median of paired ratios. The last column counts seeds for which Proposed was faster.',
            'tab:comparison-cost', '@{}Y r r r r@{}', r'Model & DynIn GA & Proposed & Time ratio & Faster pairs', lines)
write_table('ch6_calls.tex', 'Median query and ODE solver-call counts over 30 seeds. A DynIn trajectory can require many segmented ODE calls. Half-integer medians arise from the even sample size.',
            'tab:comparison-calls', '@{}Y r r r r@{}', r'& \multicolumn{2}{c}{Queries} & \multicolumn{2}{c}{ODE calls} \\ Model & DynIn GA & Proposed & DynIn GA & Proposed', calls)

plt.rcParams.update({'font.family':'DejaVu Serif','font.size':9, 'axes.titlesize':10,
                     'axes.spines.top':False,'axes.spines.right':False,'axes.linewidth':.7,
                     'pdf.fonttype':42,'svg.fonttype':'none','legend.frameon':False})
COLORS=['#B5BFC7','#78B7BA']
box_stats=[]
def boxplot(ax, arrays, title, ylabel, log=False):
    descriptors=[]
    for a in arrays:
        q1, med, q3=quantile(a,[.25,.5,.75]); iqr=q3-q1
        inside=a[(a>=q1-1.5*iqr)&(a<=q3+1.5*iqr)]
        descriptors.append(dict(q1=q1, med=med,q3=q3,whislo=min(inside),whishi=max(inside),fliers=[]))
    artists=ax.bxp(descriptors,positions=[1,2],widths=.45,showfliers=False,patch_artist=True,
                   medianprops={'color':'#152830','linewidth':1.4})
    for j,(a,patch) in enumerate(zip(arrays,artists['boxes'])):
        patch.set_facecolor(COLORS[j]); patch.set_alpha(.8)
        jitter=np.random.default_rng(7654+j).uniform(-.13,.13,len(a))
        ax.scatter(j+1+jitter,a,s=10,c='#39434A',alpha=.45,linewidths=0,zorder=3)
        ax.scatter(j+1+.28,quantile(a,.95),s=25,marker='D',c='#B8582E',edgecolors='white',linewidths=.4,zorder=4)
        box_stats.append(dict(panel=title,measure=ylabel,method=['DynIn GA','Proposed'][j],
                              n=len(a),median=float(np.median(a)),q1=float(quantile(a,.25)),
                              q3=float(quantile(a,.75)),p95=float(quantile(a,.95))))
    ax.set_xticks([1,2],['DynIn GA','Proposed']); ax.set_xlim(.55,2.6)
    ax.set_title(title,loc='left',pad=8); ax.set_ylabel(ylabel)
    ax.grid(axis='y',color='#DDE1E4',linewidth=.5); ax.set_axisbelow(True)
    if log:
        assert all((a>0).all() for a in arrays)
        ax.set_yscale('log')
    ax.margins(y=.18)

def save(fig,name):
    fig.legend(handles=[Line2D([],[],marker='D',color='none',markerfacecolor='#B8582E',
                               markeredgecolor='white',label='P95 (separate from whisker)')],
               loc='lower center',bbox_to_anchor=(.5,.005),fontsize=9)
    fig.savefig(FIG/(name+'.pdf'),bbox_inches='tight')
    fig.savefig(FIG/(name+'.svg'),bbox_inches='tight')
    fig.savefig(QA/(name+'.png'),dpi=170,bbox_inches='tight')
    plt.close(fig)

fig,axs=plt.subplots(2,2,figsize=(6.6,5.4))
for i,model in enumerate(MODELS[:4]):
    boxplot(axs.flat[i],[values(groups[model,m],'relative_error')*100 for m in [D,P]],
            f'({chr(97+i)}) {NAMES[i]}','Relative error (%)',log=True)
fig.subplots_adjust(left=.11,right=.99,top=.94,bottom=.13,hspace=.48,wspace=.40)
save(fig,'Fig_6_2D_Error')
fig,axs=plt.subplots(1,2,figsize=(6.6,3.2))
boxplot(axs[0],[values(groups[MODELS[4],m],'relative_error')*100 for m in [D,P]],
        '(a) Separable 4D','Relative error (%)',log=True)
boxplot(axs[1],[values(groups[MODELS[5],m],'R_hat') for m in [D,P]],
        '(b) Coupled 4D',r'Estimated LIM $\hat R$')
fig.subplots_adjust(left=.11,right=.99,top=.86,bottom=.22,wspace=.45)
save(fig,'Fig_6_4D_Results')
fig,axs=plt.subplots(2,3,figsize=(6.6,5.3))
for i,model in enumerate(MODELS):
    boxplot(axs.flat[i],[values(groups[model,m],'algorithm_runtime_s') for m in [D,P]],
            f'({chr(97+i)}) {NAMES[i]}','Core time (s)')
fig.subplots_adjust(left=.09,right=.99,top=.94,bottom=.13,hspace=.48,wspace=.65)
save(fig,'Fig_6_Core_Time')

(DATA/'verified_statistics.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
(DATA/'provenance.json').write_text(json.dumps({'archive':ARCHIVE.parent.name,'files':provenance},indent=2),encoding='utf-8')
with (DATA/'boxplot_statistics.csv').open('w',newline='',encoding='utf-8') as handle:
    writer=csv.DictWriter(handle,fieldnames=list(box_stats[0])); writer.writeheader();writer.writerows(box_stats)
print(json.dumps(stats,indent=2))
print('PASS: 360 unique paired runs; summaries reproduced; no energy/backward tests; tables and figures generated.')
