"""Check downloaded v16 evidence without running numerical experiments."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parent
RUN = '20261029_064110_739'
RELOCATED = {'START_FIXEDPOINT_GUARD_PARFOR.m', 'run_fixedpoint_all90.m', 'verify_guard_inputs.m'}

def load(path):
    return json.loads(path.read_text(encoding='utf-8'))

def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def checked(path, entry):
    assert path.is_file(), f'Missing: {path}'
    assert path.stat().st_size == entry['bytes'], f'Size differs: {path}'
    assert digest(path) == entry['sha256'], f'Checksum differs: {path}'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-prior', action='store_true')
    parser.add_argument('--require-records', action='store_true')
    args = parser.parse_args()
    original = load(ROOT/'RECORDED_SOURCE_MANIFEST.json')
    protected = 0
    for entry in original:
        name = entry['path']
        if name in RELOCATED:
            continue
        target = ROOT / ('RECORDED_RUN_README.txt' if name == 'README.txt' else name)
        checked(target, entry)
        protected += 1
    for entry in load(ROOT/'PUBLISHED_CODE_MANIFEST.json'):
        checked(ROOT/entry['path'], entry)
    entry_text = (ROOT/'START_FIXEDPOINT_GUARD_PARFOR.m').read_text()
    driver = (ROOT/'run_fixedpoint_all90.m').read_text()
    verifier = (ROOT/'verify_guard_inputs.m').read_text()
    assert "getenv('USERPROFILE')" not in entry_text + driver
    assert '03_Negative_Cache_90' in entry_text and '03_Negative_Cache_90' in driver
    assert 'parfor k=1:90' in driver
    assert 'portable_source_manifest.json' in verifier
    portable = load(ROOT/'input/portable_source_manifest.json')
    historical = load(ROOT/'input/source_manifest.json')
    assert len(portable) == len(historical) == 297
    for a, b in zip(portable, historical):
        assert a['bytes'] == b['bytes'] and a['sha256'] == b['sha256']
        assert not Path(a['path']).is_absolute()
    prior_count = 0
    if args.require_prior:
        for entry in portable:
            checked(ROOT/entry['path'], entry)
            prior_count += 1
        for entry in load(ROOT/'input/immutable_manifest.json'):
            checked(ROOT/entry['path'].replace('\\', '/'), entry)
            prior_count += 1
        assert prior_count == 312
    manifest = load(ROOT/'RECORDS_MANIFEST.json')
    assert len(manifest) == 1585 and len({x['path'] for x in manifest}) == 1585
    entries = {x['path']: x for x in manifest}
    browse = ROOT/'recorded_summaries'/RUN
    browsed = 0
    for path in browse.rglob('*'):
        if path.is_file():
            checked(path, entries[path.relative_to(browse).as_posix()])
            browsed += 1
    full_count = 0
    if args.require_records:
        for entry in manifest:
            checked(ROOT/'results'/RUN/entry['path'], entry)
            full_count += 1
    cases = rows(browse/'per_case_summary.csv')
    assert len(cases) == 90 and len({(x['model'], x['seed']) for x in cases}) == 90
    expected = {'quadratic_cubic': 0.4, 'bistable_duffing': 0.7, 'genda_cosine_quadratic_drag': 0.05}
    grouped = rows(browse/'summary_by_model.csv')
    solver_count = control_checks = 0
    for model, alpha in expected.items():
        subset = [x for x in cases if x['model'] == model]
        assert {int(x['seed']) for x in subset} == set(range(1, 31))
        assert all(abs(float(x['alpha'])-alpha)<1e-12 for x in subset)
        group = next(x for x in grouped if x['model'] == model)
        assert int(group['complete_cases']) == int(group['control_reproduced']) == int(group['winning_non_target_supported']) == 30
        assert int(group['under_reference']) == int(group['winning_label_contradicted']) == int(group['winning_unresolved_or_missing']) == 0
        med = statistics.median(float(x['absolute_error_percent']) for x in subset)
        assert abs(med-float(group['median_absolute_error_percent']))<1e-10
    for case in cases:
        assert case['status']=='complete' and case['control_reproduced']=='1'
        assert case['under_reference']=='0' and float(case['R_hat']) >= float(case['R_reference'])-1e-10
        assert case['winning_validation']=='both_solvers_support_non_target'
        assert all(case[k]=='0' for k in ('time_guard_hit','forced_non_target_count','periodic_terminations'))
        folder = browse/f"{case['model']}_seed_{case['seed']}"
        checks = rows(folder/'control_reproduction_checks.csv')
        assert len(checks)==4 and all(x['passed']=='1' for x in checks)
        control_checks += len(checks)
        validations = rows(folder/'independent_postcheck/independent_validation.csv')
        assert len(validations)==2 and {x['solver'] for x in validations}=={'ode45','ode113'}
        assert all(x['outcome']=='non_target' for x in validations)
        solver_count += len(validations)
    changed = [x for x in cases if abs(float(x['R_hat'])-float(x['previous_R']))>1e-10]
    assert len(changed)==1 and changed[0]['model']=='quadratic_cubic' and changed[0]['seed']=='30'
    regression = rows(browse/'preflight/query567_regression_summary.csv')[0]
    assert regression['query_now_correctly_target']=='1' and regression['old_trigger_rejected']=='1'
    assert regression['independent_outcome']=='both_solvers_support_target'
    for stage in ('before','after'):
        integrity = rows(browse/f'input_integrity_{stage}.csv')
        assert len(integrity)==312 and all(x['matched']=='1' for x in integrity)
    print(json.dumps(dict(source_files_identical_to_recorded_snapshot=protected,
        path_relocated_drivers=sorted(RELOCATED), prior_inputs_verified=prior_count,
        browsable_records_verified=browsed, complete_records_verified=full_count,
        completed_cases=90, under_reference=0, validated_final_points=90,
        independent_solver_outcomes=solver_count, control_checks=control_checks,
        query567_regression='target supported by both solvers',
        matlab_numerical_rerun_performed=False), indent=2))

if __name__=='__main__':
    main()
