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
"""Regenerate manuscript B assets from saved runs; never launch the solver."""
from pathlib import Path
import csv
import hashlib
import json
import shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
QC = REPO / 'experiment_B_multi_alpha/outputs_multi_alpha_full_20261023_055518_403'
BD = REPO / 'experiment_B_duffing_transfer/outputs_duffing_transfer_pilot_20261025_031904_626'
OUT = ROOT / 'source_data/experiment_B_multi_alpha'
OUT.mkdir(exist_ok=True)
plt.rcParams.update({'font.family':'DejaVu Serif', 'font.size':9,
    'axes.spines.top':False, 'axes.spines.right':False, 'axes.linewidth':.65,
    'pdf.fonttype':42, 'svg.fonttype':'none', 'mathtext.fontset':'dejavuserif'})
COLORS = {'baseline':'#ad633b', 'candidate':'#287987'}
LABELS = {'baseline':'Habib-based transfer', 'candidate':'Frozen BO candidate'}

def read(path):
    with path.open(newline='', encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

def vals(rows, key):
    return np.array([float(r[key]) for r in rows])

def metrics(rows):
    e = vals(rows,'absolute_error'); rel = vals(rows,'relative_error_percent')
    return dict(n=len(rows), median_absolute=float(np.median(e)),
        median_relative=float(np.median(rel)), p95_absolute=float(np.quantile(e,.95,method='hazen')),
        p95_relative=float(np.quantile(rel,.95,method='hazen')),
        within1=int(sum(rel<=1)), within2=int(sum(rel<=2)), within5=int(sum(rel<=5)),
        severe=int(sum(rel>50)), underestimate=int(sum(vals(rows,'signed_relative_error_percent')<0)),
        cpu=float(np.median(vals(rows,'core_cpu_time_s'))),
        wall=float(np.median(vals(rows,'core_wall_time_s'))))

def analyze(directory, filename, nalpha, seeds):
    rows=read(directory/filename)
    assert len(rows)==2*nalpha*seeds
    assert all(r['success']=='1' for r in rows)
    assert len({(r['role'],r['alpha'],r['seed']) for r in rows})==len(rows)
    assert np.max(np.abs(np.abs(vals(rows,'R_hat')-vals(rows,'reference_LIM'))-vals(rows,'absolute_error')))<1e-12
    for a in sorted(set(vals(rows,'alpha'))):
        groups=[[r for r in rows if float(r['alpha'])==a and r['role']==role] for role in LABELS]
        assert all(len(g)==seeds for g in groups)
        assert {r['seed'] for r in groups[0]}=={r['seed'] for r in groups[1]}
    summary={role:metrics([r for r in rows if r['role']==role]) for role in LABELS}
    summary['per_alpha']={str(a):{role:metrics([r for r in rows if float(r['alpha'])==a and r['role']==role]) for role in LABELS} for a in sorted(set(vals(rows,'alpha')))}
    summary['alphas_improved']=sum(v['candidate']['median_absolute']<v['baseline']['median_absolute'] for v in summary['per_alpha'].values())
    return rows, summary

def plot_results(rows, model, seeds, name, curve=None):
    alphas=np.unique(vals(rows,'alpha'))
    fig, axes=plt.subplots(2,1,figsize=(6.8,5.8),sharex=True,
        gridspec_kw={'height_ratios':[1.15,1], 'hspace':.25})
    # Reference polylines connect evaluated alpha values unless a dense curve is available.
    if curve is None:
        ca=alphas; cr=[float(next(r for r in rows if float(r['alpha'])==a)['reference_LIM']) for a in alphas]
    else:
        unique={}
        for r in read(curve):
            a=float(r['alpha']); v=float(r['reference_LIM'])
            if a in unique: assert abs(unique[a]-v)<1e-10
            unique[a]=v
        ca=sorted(unique); cr=[unique[a] for a in ca]
    axes[0].plot(ca,cr,'--',color='#202020',lw=1.4,label='Analytically based reference',zorder=5)
    for role in LABELS:
        med=[]; emed=[]; p95=[]
        for a in alphas:
            g=[r for r in rows if r['role']==role and float(r['alpha'])==a]
            rh=vals(g,'R_hat'); er=vals(g,'relative_error_percent')
            med.append(np.median(rh)); emed.append(np.median(er)); p95.append(np.quantile(er,.95,method='hazen'))
        axes[0].plot(alphas,med,color=COLORS[role],lw=1.25,marker='o' if role=='candidate' else 's',ms=3,label=LABELS[role])
        axes[1].plot(alphas,emed,color=COLORS[role],lw=1.25,marker='o' if role=='candidate' else 's',ms=3)
        axes[1].plot(alphas,p95,color=COLORS[role],lw=.9,ls=':')
    relative=vals(rows,'relative_error_percent')
    assert np.all(relative>0)
    axes[0].set_ylim(0,max(.88,float(max(vals(rows,'R_hat')))*1.03))
    axes[1].set_yscale('log'); axes[1].set_ylim(min(.003,float(relative.min())*.7),150)
    axes[0].set_ylabel('Estimated LIM'); axes[1].set_ylabel('Relative error (%)')
    axes[1].set_xlabel(r'Damping coefficient $\alpha$')
    for ax in axes:
        ax.grid(axis='y',color='#e1e4e6',linewidth=.5); ax.set_xlim(.025,2.025)
        ax.tick_params(labelsize=8)
    axes[0].set_title('(a) LIM estimates',loc='left',fontweight='bold',fontsize=10,pad=7)
    axes[1].set_title('(b) Error summaries',loc='left',fontweight='bold',fontsize=10,pad=7)
    axes[0].legend(loc='lower right',fontsize=8,frameon=False)
    axes[1].text(.99,.06,'Solid: median   Dotted: P95',ha='right',transform=axes[1].transAxes,fontsize=8)
    axes[0].annotate(r'$\alpha=0.05$',xy=(.05,.05),xytext=(.34,.18),fontsize=8,
        arrowprops=dict(arrowstyle='->',color='#555555',lw=.7))
    fig.subplots_adjust(left=.12,right=.985,bottom=.09,top=.95)
    for ext in ('pdf','svg','png'):
        fig.savefig(ROOT/'figures'/f'{name}.{ext}',dpi=240)
    plt.close(fig)

qc, qs=analyze(QC,'validation_raw.csv',20,100)
bd, bs=analyze(BD,'transfer_raw.csv',40,10)
plot_results(qc,'Quadratic-cubic',100,'Fig_B_QC_Validation')
plot_results(bd,'Bistable Duffing',10,'Fig_B_Duffing_Transfer',BD/'analytical_curve.csv')

def table(name, caption, label, header, body, columns):
    txt='\\begin{table}[htbp]\n\\centering\\small\n'
    txt+=f'\\caption[{caption.split(".")[0]}]{{\\bluecaption{{{caption}}}}}\\label{{{label}}}\n'
    txt+='\\begingroup\\rowcolors{1}{revisionblue}{revisionblue}\n'
    txt+='\\setlength{\\tabcolsep}{4pt}\n'
    txt+=f'\\begin{{tabularx}}{{\\linewidth}}{{{columns}}}\n\\toprule\n'
    txt+=header+' \\\\\n\\midrule\n'+' \\\\\n'.join(body)+' \\\\\n\\bottomrule\n'
    txt+='\\end{tabularx}\\endgroup\n\\end{table}\n'
    (ROOT/'tables'/name).write_text(txt,encoding='utf-8')

fields=[('Target cells $k$','num_of_cell_around_equilibrium'),('Grid resolution','discr'),
    ('GA generations','num_gen'),('Population size',None),('Newcomers','newcomers'),
    ('\\code{selected\\_opt}','selected_opt'),('Outer trajectory budget','number_of_steps'),
    ('Sampling interval $T_s$','Ts'),('Crossover individuals (derived)','num_crossover')]
b=read(QC/'transferred_baseline.csv')[0]; c=read(QC/'frozen_candidate_parameters.csv')[0]
body=[]
for label,key in fields:
    bv=b[key] if key else '20'; cv=c[key] if key else '20'
    if key=='Ts': cv=f'{float(cv):.10f}'
    body.append(f'{label} & {bv} & {cv}')
table('b_multi_candidate.tex','Frozen configuration used for all validation and transfer runs. The crossover count is derived; the full saved sampling interval is 0.0920905251923764.','tab:b-candidate','Setting & Habib-based transfer & BO candidate',body,'@{}Y r r@{}')

body=[]
for label,s in [('Quadratic-cubic validation',qs),('Duffing transfer pilot',bs)]:
    body.append('\\multicolumn{3}{l}{\\textbf{'+label+'}}')
    for desc,key,fmt in [('Runs per profile','n','d'),('Median absolute error','median_absolute','.6f'),
        ('Median relative error (\\%)','median_relative','.3f'),('P95 relative error (\\%)','p95_relative','.3f'),
        ('Runs within 1\\%','within1','d'),('Runs within 2\\%','within2','d'),('Runs above 50\\% error','severe','d'),
        ('Median CPU time (s)','cpu','.3f'),('Median wall-clock time (s)','wall','.3f')]:
        body.append(f'{desc} & {s["baseline"][key]:{fmt}} & {s["candidate"][key]:{fmt}}')
table('b_multi_results.tex','Held-out-alpha validation and frozen cross-model transfer. Statistics pool equally many runs at each alpha; all low-alpha runs are retained. CPU and wall-clock times cover the same solver call.','tab:b-multi-results','Measure & Habib-based transfer & BO candidate',body,'@{}Y r r@{}')

manifest={}
for folder, names, prefix in [(QC,['validation_raw.csv','validation_overall.csv','validation_comparison_by_alpha.csv','reference_by_alpha.csv','reference_audit.csv','search_configurations.csv','frozen_candidate_parameters.csv','transferred_baseline.csv','restart_1_trace.csv','restart_2_trace.csv'],'qc'),(BD,['transfer_raw.csv','analytical_curve.csv','reference_audit.csv','comparison_by_alpha.csv','comparison_overall.csv','candidate_parameters.csv','baseline_parameters.csv'],'duffing')]:
    for name in names:
        dest=OUT/f'{prefix}_{name}'; shutil.copy2(folder/name,dest)
        manifest[dest.name]=hashlib.sha256(dest.read_bytes()).hexdigest()
audit={'quadratic_cubic':qs,'bistable_duffing':bs,'sha256':manifest,'quantile_method':'Hazen: (i-0.5)/n','figure_points':'All runs at exact alpha coordinates; no vertical jitter'}
(OUT/'audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print(json.dumps({k:{a:v for a,v in s.items() if a!='per_alpha'} for k,s in [('qc',qs),('duffing',bs)]},indent=2))
