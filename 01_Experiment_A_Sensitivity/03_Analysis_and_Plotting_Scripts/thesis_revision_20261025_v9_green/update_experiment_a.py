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
from pathlib import Path
import csv
import hashlib
import json
import shutil
from collections import Counter
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'experiment_A_genda_sensitivity/outputs_genda_A_full_20261022_050850_249'
OLD = HERE.parent / 'thesis_revision_20261022_v3'
QA = HERE / 'qa'
QA.mkdir(exist_ok=True)


def read(folder, name):
    with (folder / name).open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


raw = read(SOURCE, 'raw_data_all_runs.csv')
summary = read(SOURCE, 'summary_by_configuration.csv')
rank = read(SOURCE, 'sensitivity_ranking.csv')
groups = {r['config_id']: sorted([x for x in raw if x['config_id'] == r['config_id']],
                               key=lambda x: int(x['seed'])) for r in summary}
lookup = {r['config_id']: r for r in summary}
assert len(raw) == len({r['run_key'] for r in raw}) == 870
assert len(groups) == 29
assert all(r['success'] == r['diagnostic_success'] == '1' for r in raw)
assert all(r['n_diagnostic_target'] == '63' and r['n_diagnostic_nontarget'] == '9'
           and float(r['diagnostic_truth_unresolved_rate']) == 0 for r in raw)
assert not any('cpu' in k.lower() for k in raw[0])
audit_rows = []
for key, rows in groups.items():
    assert [int(r['seed']) for r in rows] == list(range(99101, 99131))
    ref = np.array([float(r['reference_LIM']) for r in rows])
    radius = np.array([float(r['R_hat']) for r in rows])
    err = np.array([float(r['relative_error_percent']) for r in rows])
    wall = np.array([float(r['core_wall_time_s']) for r in rows])
    assert np.allclose(ref, .728927859156115, rtol=0, atol=1e-14)
    assert np.allclose(err, 100 * abs(radius-ref)/ref, rtol=1e-11, atol=1e-10)
    calculated = dict(zip(['q1_relative_error_percent', 'median_relative_error_percent',
                          'q3_relative_error_percent', 'p95_relative_error_percent'],
                         np.quantile(err, [.25, .5, .75, .95], method='hazen')))
    calculated.update(median_core_wall_time_s=np.median(wall),
                      median_R_hat=np.median(radius),
                      median_absolute_error=np.median(abs(radius-ref)),
                      within_1pct_count=int(sum(err <= 1)), within_2pct_count=int(sum(err <= 2)))
    for output, field in [('median_trajectory_evaluations','trajectory_evaluations'),
                          ('median_false_safe_rate','false_safe_rate'),
                          ('median_false_unsafe_rate','false_unsafe_rate'),
                          ('median_diagnostic_unresolved_rate','diagnostic_unresolved_rate'),
                          ('median_diagnostic_runtime_s','diagnostic_runtime_s')]:
        calculated[output] = np.median([float(r[field]) for r in rows])
    assert all(int(lookup[key][k]) == 30 for k in ['n_expected','n_saved','n_success','n_diagnostic_success'])
    assert lookup[key]['complete_valid'] == '1' and lookup[key]['pilot_only'] == '0'
    for field, value in calculated.items():
        assert np.isclose(value, float(lookup[key][field]), rtol=1e-11, atol=1e-10), (key, field)
    bad = err > 50
    assert np.all(radius[bad] < ref[bad])
    audit_rows.append(dict(config_id=key, n=30, **calculated,
                           severe_underestimate_count=int(sum(bad))))
for row in read(SOURCE, 'summary_by_parameter_and_level.csv'):
    for field, value in row.items():
        if field not in ['changed_parameter']:
            assert value == lookup[row['config_id']][field], (row['config_id'],field)
for r in rank:
    f = r['changed_parameter']
    rows = [lookup[k] for k in [f+'__low', 'baseline', f+'__high']]
    vals = [float(x['median_relative_error_percent']) for x in rows]
    times = [float(x['median_core_wall_time_s']) for x in rows]
    assert np.isclose(max(vals)-min(vals), float(r['error_range_percentage_points']), atol=1e-12)
    assert np.isclose(max(times)/min(times), float(r['runtime_max_min_ratio']))
assert all(float(a['error_range_percentage_points']) >= float(b['error_range_percentage_points'])
           for a, b in zip(rank, rank[1:]))
old_raw = read(OLD/'source_data/experiment_A', 'raw_data_all_runs.csv')
new_lookup = {r['run_key']: r for r in raw}
assert all(float(r['R_hat']) == float(new_lookup[r['run_key']]['R_hat']) for r in old_raw)
base = groups['baseline']
for key in ['tfinal__low', 'tfinal__high', 'rep_periodic__high']:
    assert [r['R_hat'] for r in groups[key]] == [r['R_hat'] for r in base]
bad_seeds = lambda rows: {r['seed'] for r in rows if float(r['relative_error_percent']) > 50}
assert bad_seeds(base) == bad_seeds(groups['number_of_steps__high'])

names = {'target_neighborhood_cells': 'Target cells $k$', 'Ts': '$T_s$',
         'discr': r'\code{discr}', 'rep_fix_point': r'\code{rep\_fix\_point}',
         'rep_periodic': r'\code{rep\_periodic}', 'num_almost_clones': 'Near-clones',
         'number_of_steps': 'Outer budget', 'newcomer_fraction': 'Newcomer fraction',
         'num_gen': 'GA generations', 'selected_opt': r'\code{selected\_opt}',
         'population_size': 'Population size', 'divR': r'\code{divR}',
         'ode_tolerance': 'ODE tolerances', 'tfinal': r'\code{tfinal}'}
levels = {'target_neighborhood_cells':'1 / 3 / 7','Ts':'0.025 / 0.05 / 0.1',
          'discr':'351 / 701 / 1051','rep_fix_point':'20 / 40 / 80',
          'rep_periodic':'5 / 10 / 20','num_almost_clones':'0 / 2 / 4',
          'number_of_steps':'50 / 100 / 200','newcomer_fraction':'0.2 / 0.4 / 0.6',
          'num_gen':'2 / 5 / 10','selected_opt':'2 / 3 / 5','population_size':'10 / 20 / 40',
          'divR':'20 / 40 / 80','ode_tolerance':'See note','tfinal':'1000 / 2000 / 4000'}
plain = {'target_neighborhood_cells':'Target cells k','Ts':'Sampling interval Ts',
         'discr':'Grid resolution','rep_fix_point':'Fixed-point recurrence',
         'rep_periodic':'Periodic recurrence','selected_opt':'selected_opt',
         'num_almost_clones':'Near-clones','number_of_steps':'Outer budget',
         'newcomer_fraction':'Newcomer fraction','num_gen':'GA generations',
         'population_size':'Population size','divR':'divR','ode_tolerance':'ODE tolerances',
         'tfinal':'tfinal'}

table = (HERE/'tables/a_genda_ranking.tex').read_text(encoding='utf-8')
rows = []
for r in rank:
    f = r['changed_parameter']
    med = [float(lookup[k]['median_relative_error_percent']) for k in [f+'__low','baseline',f+'__high']]
    spread = float(r['error_range_percentage_points'])
    rows.append(' & '.join([names[f], levels[f], ' / '.join(f'{e:.3f}' for e in med),
                            f'{spread:.3f}' if spread > 1e-6 else r'$\approx0$']) + r' \\')
table = table[:table.index('\\midrule')+len('\\midrule')] + '\n' + '\n'.join(rows) + '\n' + table[table.index('\\bottomrule'):]
table = table.replace('Each configuration uses ten seeds.', 'Each configuration uses 30 common seeds.')
(HERE/'tables/a_genda_ranking.tex').write_text(table, encoding='utf-8')

plt.rcParams.update({'font.family':'DejaVu Serif','font.size':10,'axes.titlesize':11,
                     'axes.spines.top':False,'axes.spines.right':False,
                     'pdf.fonttype':42,'svg.fonttype':'none'})
colors = ['#bcc4c7', '#93b8ba', '#c9b58f']
plot_audit = []


def offsets(values):
    # Seed-matched horizontal jitter is independent of error; y-values stay exact.
    rng = np.random.default_rng(451)
    out = rng.permutation(np.linspace(-.22, .22, len(values)))
    out += rng.uniform(-.004, .004, len(values))
    assert np.max(np.abs(out)) < .24
    return out


def export(fig, name):
    for ext in ['pdf', 'svg']:
        fig.savefig(HERE/'figures'/f'{name}.{ext}', bbox_inches='tight')
    fig.savefig(QA/f'{name}.png', dpi=180, bbox_inches='tight')
    plt.close(fig)


top = [r['changed_parameter'] for r in rank[:6]]
fig, axes = plt.subplots(2, 3, figsize=(8.5, 6.6), layout='constrained')
for j, (ax, f) in enumerate(zip(axes.flat, top)):
    keys = [f+'__low','baseline',f+'__high']
    values = [np.array([float(r['relative_error_percent']) for r in groups[key]]) for key in keys]
    stats = []
    for v in values:
        q1, med, q3 = np.quantile(v, [.25,.5,.75], method='hazen')
        stats.append(dict(med=med,q1=q1,q3=q3,whislo=v[v>=q1-1.5*(q3-q1)].min(),
                          whishi=v[v<=q3+1.5*(q3-q1)].max(),fliers=[]))
    artists = ax.bxp(stats, showfliers=False, patch_artist=True, widths=.52,
                     medianprops=dict(color='#d18248',linewidth=1.2))
    for patch, col in zip(artists['boxes'], colors):
        patch.set_facecolor(col)
        patch.set_alpha(.75)
    for i, (key, v) in enumerate(zip(keys, values), 1):
        assert len(v) == 30 and min(v) > .02 and max(v) < 200
        ax.scatter(i+offsets(v),v,c='#656d71',s=10,alpha=.6,zorder=3,linewidths=0)
        ax.scatter(i+.34,np.quantile(v,.95,method='hazen'),c='#ad5b31',marker='D',s=24,zorder=4)
        plot_audit.append(dict(panel=j+1,config_id=key,n_points=len(v),min=float(min(v)),max=float(max(v))))
    labels = levels[f].split(' / ')
    labels[1] += ' (B)'
    ax.set_xticks([1,2,3],labels)
    ax.set_xlim(.5,3.55)
    ax.set_yscale('log')
    ax.set_ylim(.02,200)
    ax.set_ylabel('Relative error (%)')
    ax.grid(axis='y',color='#e5e5e5',zorder=0)
    ax.set_title(f'({chr(97+j)}) {plain[f]}')
fig.supxlabel('30 runs per setting; diamonds: P95, separate from whiskers',fontsize=9)
export(fig,'Fig_A_Distributions')

fig, (a,b) = plt.subplots(1,2,figsize=(8.1,6.0),sharey=True,layout='constrained',
                         gridspec_kw={'width_ratios':[1.5,1]})
y = np.arange(14)
err = np.array([float(r['error_range_percentage_points']) for r in rank])
err[err<1e-6] = 0
time = np.array([float(r['runtime_max_min_ratio']) for r in rank])
a.scatter(err,y,c='#367c82')
b.scatter(time,y,c='#5b6268')
a.set_yticks(y,[plain[r['changed_parameter']] for r in rank])
a.invert_yaxis()
a.set_xscale('symlog',linthresh=.1)
a.set_xlim(-.015,450)
a.set_xticks([0,.1,1,10,100],['0','0.1','1','10','100'])
a.set_xlabel('Median-error range (percentage points)')
b.set_xlabel('Median wall-time ratio (max / min)')
b.set_xlim(.9,5.45)
b.axvline(1,c='grey',ls=':',lw=1)
for ax, vals in [(a,err),(b,time)]:
    ax.grid(axis='x',color='#ededed')
    for yy, val in zip(y, vals):
        ax.annotate('~0' if val==0 else f'{val:.2f}',(val,yy),xytext=(5,0),
                    textcoords='offset points',fontsize=8,va='center')
export(fig,'Fig_01_A_Sensitivity')

dest = HERE/'source_data/experiment_A'
for path in SOURCE.glob('*.csv'):
    shutil.copy2(path, dest/path.name)
with (dest/'verified_configuration_metrics.csv').open('w',newline='',encoding='utf-8') as f:
    writer = csv.DictWriter(f,fieldnames=audit_rows[0].keys())
    writer.writeheader()
    writer.writerows(audit_rows)
manifest = json.loads((HERE/'source_data/manifest.json').read_text())
manifest = [r for r in manifest if not r['file'].startswith('experiment_A/')]
for path in sorted(dest.glob('*.csv')):
    manifest.append(dict(file='experiment_A/'+path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
(HERE/'source_data/manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
audit = dict(source_dataset=SOURCE.name,runs=870,configurations=29,seeds_per_configuration=30,
             seed_range=[99101,99130],successful_solver_and_diagnostic_runs=870,
             all_saved_summary_statistics_recomputed=True,quantile_method='Hazen (MATLAB prctile)',
             old_ten_seed_LIM_values_unchanged=True,baseline_severe_seeds=sorted(map(int,bad_seeds(base))),
             top_six=top,figures=plot_audit,cpu_time_recorded=False)
(HERE/'source_data/experiment_A_update_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in audit.items() if k!='figures'},indent=2))
