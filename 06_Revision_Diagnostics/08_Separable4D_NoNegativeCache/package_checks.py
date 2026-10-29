"""Preparation-only audit. MATLAB execution does not require this script."""
from pathlib import Path
import csv
import difflib
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
WORK = ROOT.parent
SOURCE = WORK / 'LIM_Separable4D_Diagnostics_20261029'
SNAPSHOT = WORK / 'six_model_sampled_forward_comparison/outputs_sampled_forward_full_20261018_204956_915/source_snapshot'
DIAG = Path(r'C:\Users\-qian-\Desktop\LIM_Separable4D_Diagnostics\results\20261029_053219_578')
sys.path.insert(0, str(WORK / 'LIM_Underestimation_Diagnostics_20261028/python_dependencies'))
import numpy as np
from scipy.io import loadmat


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_csv(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def write_csv(path, rows):
    with path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    pairs = []
    for name in ['input', 'engine', 'native', 'model', 'static_audit']:
        for src in (SOURCE / name).rglob('*'):
            if src.is_file():
                dst = ROOT / src.relative_to(SOURCE)
                assert sha(src) == sha(dst), dst
                pairs.append((dst, src))
    src = SNAPSHOT / 'separable_4d_analytic_benchmark/run_separable_4d_analytic_benchmark.m'
    dst = ROOT / 'engine' / src.name
    assert sha(src) == sha(dst)
    pairs.append((dst, src))
    base = (ROOT / 'engine/sampled_forward_classifier.m').read_text(encoding='utf-8')
    changed = (ROOT / 'retest4d_classifier.m').read_text(encoding='utf-8')
    restored = changed.replace('function api=retest4d_classifier(d,canStart)',
                              'function api=sampled_forward_classifier(d,canStart)')
    comments = ('% AI-assisted targeted ablation requested by the author.\n'
                '% Only non-target/domain-exit grid READS are suppressed. Writes, target\n'
                '% reuse, direct exits, recurrence, horizon and integration remain unchanged.\n')
    restored = restored.replace(comments, '')
    replacement = ('        queryGeometry=g;\n'
                   '        queryGeometry.cell_d=zeros(0,1);\n'
                   '        queryGeometry.cell_dout=zeros(0,1);\n'
                   '        [xt,cells,tipo,count,rhsCalls]=sampled_forward_integrate(d,queryGeometry,z0);')
    restored = restored.replace(replacement,
        '        [xt,cells,tipo,count,rhsCalls]=sampled_forward_integrate(d,g,z0);')
    assert restored == base, 'Unexpected numerical edits in classifier.'
    (ROOT / 'ALGORITHM_CHANGE.diff').write_text(''.join(difflib.unified_diff(
        base.splitlines(True), changed.splitlines(True),
        fromfile='frozen/sampled_forward_classifier.m', tofile='retest4d_classifier.m')), encoding='utf-8')

    settings = loadmat(ROOT / 'input/separable_qc_bd_4d_settings.mat', simplify_cells=True)
    p = settings['problem']
    target = np.array(p['target'], dtype=float)
    weights = np.array(p['sqrtWeight'], dtype=float)
    audits = []
    for seed in range(1, 31):
        data = loadmat(ROOT / f'input/runs/separable_qc_bd_4d__proposed_sampled_forward__seed_{seed}.mat', simplify_cells=True)
        row, detail = data['row'], data['details']
        queries, rays = list(detail['query_records']), list(detail['rays'])
        candidates = [j for j, r in enumerate(rays) if abs(r['boundary_radius']-row['R_hat']) < 1e-12]
        assert candidates
        ray = rays[candidates[0]]
        assert abs((ray['bracket_lower']+ray['bracket_upper'])/2-row['R_hat']) < 1e-10
        zlo = target + ray['bracket_lower'] * ray['direction'] / weights
        zhi = target + ray['bracket_upper'] * ray['direction'] / weights
        lows = [j+1 for j, q in enumerate(queries) if np.max(np.abs(q['initial_state']-zlo)) < 1e-10 and q['native_tipo']==1]
        highs = [j+1 for j, q in enumerate(queries) if np.max(np.abs(q['initial_state']-zhi)) < 1e-10 and q['native_tipo']!=1]
        assert len(lows)==1 and len(highs)==1
        assert len(queries)==row['query_count'] and len(rays)==row['direction_count']
        audits.append(dict(seed=seed,algorithm_seed=int(row['algorithm_seed']),queries=len(queries),
                           rays=len(rays),lower_query=lows[0],upper_query=highs[0],endpoint_mapping_pass=True))
    write_csv(ROOT / 'PREPARATION_ENDPOINT_CHECKS.csv', audits)

    evidence = ROOT / 'input/previous_diagnostic'
    evidence.mkdir(exist_ok=True)
    diagnostic = read_csv(DIAG / 'case_summary.csv')
    first_writer_outcomes = []
    for row in diagnostic:
        seed = int(row['seed'])
        folder = DIAG / f'seed_{seed:02d}'
        entries = read_csv(folder / 'independent_assessment.csv')
        roots = [e for e in entries if e['role']=='chain_initial_state' and e['query']==row['winning_root_query']]
        assert len(roots)==1
        first_writer_outcomes.append(roots[0]['conclusion'])
        for name in ['independent_assessment.csv','winning_upper_label_chain.csv']:
            src=folder/name; dst=evidence/f'seed_{seed:02d}_{name}'
            if dst.exists(): assert sha(dst)==sha(src)
            else: shutil.copy2(src,dst)
            pairs.append((dst,src))
    src=DIAG/'case_summary.csv'; dst=evidence/src.name
    if dst.exists(): assert sha(dst)==sha(src)
    else: shutil.copy2(src,dst)
    pairs.append((dst,src))
    assert len(first_writer_outcomes)==30 and all(v=='both_solvers_support_non_target' for v in first_writer_outcomes)
    assert sum(r['upper_independent_outcome']=='both_solvers_support_target' for r in diagnostic)==29

    # The independent validation numerical helpers are byte-for-byte identical.
    old=(SOURCE/'validate_separable4d.m').read_text(encoding='utf-8')
    new=(ROOT/'retest4d_validate.m').read_text(encoding='utf-8')
    marker='function [r,s]=integrate_point'
    assert old[old.index(marker):]==new[new.index(marker):]
    dependencies=['sampled_forward_classifier','sampled_forward_geometry','sampled_forward_integrate',
                  'sampled_forward_step','run_separable_4d_analytic_benchmark','find_index',
                  'find_cells_around_a_cell','sistema']
    for name in dependencies:
        assert len(list(ROOT.rglob(name+'.m')))==1, name
    assert 'parfor (' in (ROOT/'run_retest4d.m').read_text()
    assert 'retest4d_validate(d,P,' in (ROOT/'retest4d_case.m').read_text()
    assert 'function assessment=retest4d_validate(d,P,out,o)' in new
    analyzer=Path(r'C:\Program Files\MATLAB\R2025b\bin\win64\mlint.exe')
    analysis=subprocess.run([str(analyzer),'-id']+[str(f) for f in sorted(ROOT.glob('*.m'))],
                            capture_output=True,check=True)
    (ROOT/'MATLAB_CODE_ANALYZER.txt').write_bytes(analysis.stdout+analysis.stderr)
    # Remaining diagnostics are unused suppressions and the intentionally small
    # options structure broadcast to parfor workers; reject any other finding.
    import re
    codes=re.findall(rb'\): ([A-Z][A-Z0-9_]*):',analysis.stdout+analysis.stderr)
    assert set(codes)<= {b'MSNU',b'PFBNS'},codes
    origins={dst.relative_to(ROOT).as_posix():str(src) for dst,src in pairs}
    report={'frozen_files_verified':len(pairs), 'saved_endpoint_mappings_verified':len(audits),
            'all_30_first_writer_initial_states_independently_non_target':True,
            'original_upper_endpoints_independently_target':29,
            'classifier_diff_exactly_negative_grid_read_suppression':True,
            'independent_validation_numerical_helpers_unchanged':True,
            'matlab_R2025b_code_analyzer_no_syntax_errors':True,
            'matlab_numerical_tests_run_during_preparation':False}
    (ROOT/'PREPARATION_CHECKS.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    rows=[]
    for f in sorted(ROOT.rglob('*')):
        rel=f.relative_to(ROOT).as_posix()
        if not f.is_file() or rel.startswith('results/') or '__pycache__' in rel:
            continue
        if f.name in ['package_manifest.csv','START_SEPARABLE4D_RETEST_PARFOR.m']:
            continue
        rows.append(dict(relative_path=rel,source_path=origins.get(rel,'new independent diagnostic package'),
                         bytes=f.stat().st_size,sha256=sha(f)))
    write_csv(ROOT/'package_manifest.csv',rows)
    for dst,src in pairs: assert sha(dst)==sha(src)
    print(json.dumps(report,indent=2))
    print(f'Manifest: {len(rows)} files; total {sum(r["bytes"] for r in rows)/1024**2:.2f} MiB')


if __name__=='__main__':
    main()
