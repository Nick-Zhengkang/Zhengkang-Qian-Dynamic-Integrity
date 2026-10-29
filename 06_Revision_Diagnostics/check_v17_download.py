"""Check v17 downloaded bytes and saved results; never run or change MATLAB data."""
from pathlib import Path
import argparse
import csv
import hashlib
import json
import statistics

ROOT = Path(__file__).resolve().parent

def digest(p):
    with p.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def rows(p):
    with p.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

def check(require_records=False):
    report = {'matlab_numerical_rerun_performed': False, 'packages': []}
    for spec in json.loads((ROOT/'V17_PACKAGES.json').read_text()):
        package = ROOT/spec['folder']
        manifest = json.loads((package/'PUBLICATION_MANIFEST.json').read_text())
        checked = 0
        for r in manifest:
            if r['path'].startswith('results/') and not require_records:
                continue
            file = package/r['path']
            assert file.is_relative_to(package)
            assert file.is_file(), f'Missing {file}; extract its Runtime_Inputs/Records ZIP into repository root.'
            assert file.stat().st_size == r['bytes'] and digest(file)==r['sha256'], file
            checked += 1
        for r in rows(package/spec['integrity_manifest']):
            assert digest(package/r['relative_path'])==r['sha256'], r['relative_path']
        assert "mfilename('fullpath')" in (package/spec['entry']).read_text()
        run = package/('results' if require_records else 'recorded_summaries')/spec['run_id']
        cases = rows(run/'case_summary.csv')
        assert len(cases)==30 and {int(r['seed']) for r in cases}==set(range(1,31))
        assert all(not r['error_message'] for r in cases)
        result = {'folder':spec['folder'], 'files_verified':checked, 'cases':30}
        if spec['folder'].startswith('07'):
            assert sum(int(r['replay_matches']) for r in cases)==30
            assert {r['winning_root_reason'] for r in cases}=={'left_computational_domain'}
            assert sum(r['upper_independent_outcome']=='both_solvers_support_target' for r in cases)==29
            result['independently_target_upper_points']=29
        else:
            assert all(r['control_matches']=='1' and r['repair_completed']=='1' and r['provenance_matches']=='1' for r in cases)
            assert all(r['midpoint_below_reference']=='0' and r['upper_below_reference']=='0' for r in cases)
            assert all(r['upper_validation']=='both_solvers_support_non_target' for r in cases)
            expected = 2 if spec['folder'].startswith('08') else 30
            assert sum(r['lower_validation']=='both_solvers_support_target' for r in cases)==expected
            assert sum(int(r['endpoint_checks_pass']) for r in cases)==expected
            result.update(endpoint_pairs_passed=expected, below_reference=0,
                          median_error_percent=statistics.median(float(r['midpoint_error_percent']) for r in cases))
            if expected==30:
                assert all(r['negative_cache_hits']=='0' and r['learned_target_cache_hits']=='0' for r in cases)
                assert sum(int(r['previous_lower_agrees']) for r in cases)==30
                result['previous_lower_regressions_agree']=30
        if require_records:
            assert (run/'input_hashes_before.csv').read_bytes()==(run/'input_hashes_after.csv').read_bytes()
            snapshot = run/('diagnostic_source_snapshot' if spec['folder'].startswith('07') else 'source_snapshot')
            for file in snapshot.rglob('*.m'):
                assert digest(file)==digest(package/file.relative_to(snapshot)), file
            if spec['folder'].startswith('09'):
                for seed in range(1,31):
                    a = rows(run/f'seed_{seed:02d}/no_learned_cache/validation/independent_assessment.csv')
                    assert len(a)==3 and all(r['conclusion']!='unresolved_or_solver_disagreement' for r in a)
        report['packages'].append(result)
    return report

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-records',action='store_true')
    args = parser.parse_args()
    print(json.dumps(check(args.require_records),indent=2))
