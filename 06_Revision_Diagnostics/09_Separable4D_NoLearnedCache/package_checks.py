"""Preparation-only static/source audit. Not needed to execute MATLAB tests."""
from pathlib import Path
import csv
import difflib
import hashlib
import json
import re
import subprocess

ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'LIM_Separable4D_NoNegativeCache_30_Parfor'
RUN=Path(r'C:\Users\-qian-\Desktop\LIM_Separable4D_NoNegativeCache_30_Parfor\results\20261030_032124_802')


def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for data in iter(lambda:f.read(1024*1024),b''): h.update(data)
    return h.hexdigest()


def read_csv(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))


def write_csv(p,rows):
    with p.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)


def main():
    original_manifest=read_csv(OLD/'package_manifest.csv')
    for row in original_manifest:
        assert sha(OLD/row['relative_path'])==row['sha256'],row['relative_path']
    assert read_csv(RUN/'input_hashes_before.csv')==read_csv(RUN/'input_hashes_after.csv')
    rows=read_csv(RUN/'case_summary.csv')
    assert len(rows)==30 and all(r['control_matches']=='1' and r['repair_completed']=='1' for r in rows)
    origins={}
    for name in ['engine','input','model','native','static_audit']:
        for src in (OLD/name).rglob('*'):
            if not src.is_file():continue
            dst=ROOT/src.relative_to(OLD)
            assert sha(dst)==sha(src),dst
            origins[dst.relative_to(ROOT).as_posix()]=str(src)
    for seed in range(1,31):
        src=RUN/f'seed_{seed:02d}/no_negative_cache/search.mat'
        dst=ROOT/f'input/no_negative_cache_baseline/seed_{seed:02d}.mat'
        assert sha(src)==sha(dst),(src,dst)
        assert dst.stat().st_size>10000
        origins[dst.relative_to(ROOT).as_posix()]=str(src)
    src=RUN/'case_summary.csv'; dst=ROOT/'input/no_negative_cache_baseline/case_summary.csv'
    assert sha(src)==sha(dst);origins[dst.relative_to(ROOT).as_posix()]=str(src)
    baseline=(RUN/'source_snapshot/retest4d_classifier.m').read_text(encoding='utf-8')
    control=(ROOT/'noneg4d_classifier.m').read_text(encoding='utf-8')
    assert control.replace('function api=noneg4d_classifier(d,canStart)',
                           'function api=retest4d_classifier(d,canStart)')==baseline
    repaired=(ROOT/'allcache4d_classifier.m').read_text(encoding='utf-8')
    expected=baseline.replace('function api=retest4d_classifier(d,canStart)',
                              'function api=allcache4d_classifier(d,canStart)')
    expected=expected.replace('% Only non-target/domain-exit grid READS are suppressed. Writes, target\n'
                              '% reuse, direct exits, recurrence, horizon and integration remain unchanged.',
                              '% All LEARNED grid reads are suppressed; the initial target cells remain.\n'
                              '% Writes, direct exits, recurrence, horizon and integration are unchanged.')
    expected=expected.replace('        queryGeometry=g;\n',
                              '        queryGeometry=g;\n        queryGeometry.cell_c=initialTarget;\n')
    assert repaired==expected,'Unexpected numerical classifier edit.'
    (ROOT/'ALGORITHM_CHANGE.diff').write_text(''.join(difflib.unified_diff(
        baseline.splitlines(True),repaired.splitlines(True),fromfile='previous/retest4d_classifier.m',
        tofile='allcache4d_classifier.m')),encoding='utf-8')

    # Independent validation remains numerically identical to the prior run.
    marker='function [r,s]=integrate_point'
    before=(OLD/'retest4d_validate.m').read_text(encoding='utf-8')
    after=(ROOT/'allcache4d_validate.m').read_text(encoding='utf-8')
    assert before[before.index(marker):]==after[after.index(marker):]
    for file in ROOT.glob('*.m'):
        contents=file.read_text(encoding='utf-8')
        if file.name.startswith('START_'):continue
        line=contents.splitlines()[0]
        assert re.search(r'\b'+re.escape(file.stem)+r'\s*\(',line),(file,line)
        assert 'retest4d_' not in contents and 'run_retest4d(' not in contents,file
    case=(ROOT/'allcache4d_case.m').read_text(encoding='utf-8')
    assert 'else, oracle=noneg4d_classifier' in case
    assert "'no_learned_cache'" in case
    assert 'parfor (' in (ROOT/'run_allcache4d.m').read_text(encoding='utf-8')
    assert 'queryGeometry.cell_c=initialTarget;' in (ROOT/'allcache4d_provenance.m').read_text(encoding='utf-8')
    analyzer=Path(r'C:\Program Files\MATLAB\R2025b\bin\win64\mlint.exe')
    proc=subprocess.run([str(analyzer),'-id']+[str(p) for p in sorted(ROOT.glob('*.m'))],
                        capture_output=True,check=True)
    data=proc.stdout+proc.stderr
    (ROOT/'MATLAB_CODE_ANALYZER.txt').write_bytes(data)
    codes=re.findall(rb'\): ([A-Z][A-Z0-9_]*):',data)
    assert set(codes)<={b'MSNU',b'PFBNS'},codes
    report=dict(baseline_complete_mat_files_verified=30,
                frozen_input_and_source_copies_verified=len(origins),
                prior_package_files_still_match_manifest=len(original_manifest),
                new_classifier_has_only_one_added_numerical_line=True,
                initial_target_neighbourhood_preserved=True,
                previous_no_negative_cache_classifier_unchanged_except_name=True,
                independent_validation_helpers_unchanged=True,
                matlab_R2025b_static_analyzer_no_syntax_errors=True,
                matlab_numerical_tests_run_during_preparation=False)
    (ROOT/'PREPARATION_CHECKS.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    manifest=[]
    for p in sorted(ROOT.rglob('*')):
        rel=p.relative_to(ROOT).as_posix()
        if not p.is_file() or rel.startswith('results/') or '__pycache__' in rel:continue
        if p.name in ['package_manifest.csv','START_SEPARABLE4D_ALLCACHE_PARFOR.m']:continue
        manifest.append(dict(relative_path=rel,source_path=origins.get(rel,'new independent diagnostic package'),
                             bytes=p.stat().st_size,sha256=sha(p)))
    write_csv(ROOT/'package_manifest.csv',manifest)
    print(json.dumps(report,indent=2))
    print(f'Package manifest: {len(manifest)} files, {sum(r["bytes"] for r in manifest)/1024**2:.2f} MiB')


if __name__=='__main__':main()
