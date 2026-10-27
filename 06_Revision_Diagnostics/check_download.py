"""AI-assisted, read-only relocation check; does not execute MATLAB solvers."""
from pathlib import Path
import argparse
import csv
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = ROOT / '04_Method_Comparison/02_Raw_Data/Six_Models_360_Runs/outputs_sampled_forward_full_20261018_204956_915'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--require-records', action='store_true')
args = parser.parse_args()
checks = []

def require(condition, description):
    if not condition:
        raise AssertionError(description)
    checks.append(description)

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''):
            h.update(b)
    return h.hexdigest()

drivers = {'01_Label_Provenance': 'START_DIAGNOSTICS.m',
           '02_Negative_Cache_9': 'START_RETEST.m',
           '03_Negative_Cache_90': 'START_ALL90_PARFOR.m',
           '04_Query567': 'START_QUERY567_DIAGNOSTIC.m'}
for package, driver in drivers.items():
    text = (HERE / package / driver).read_text(encoding='utf-8-sig')
    require('C:/' not in text and 'C:\\' not in text, package + ': portable entry point')
    require('fileparts(mfilename' in text, package + ': entry point anchored to its own file')
for model in ['quadratic_cubic', 'bistable_duffing', 'genda_cosine_quadratic_drag']:
    require((DATA / (model + '_settings.mat')).is_file(), model + ': settings found')
    require((DATA / 'dynin_models' / model / 'sistema.m').is_file(), model + ': model found')
    for seed in range(1, 31):
        require((DATA / 'runs' / f'{model}__proposed_sampled_forward__seed_{seed}.mat').is_file(), f'{model}: saved seed {seed}')

snapshot = DATA / 'source_snapshot'
names = ['sampled_forward_proposed', 'sampled_forward_classifier', 'sampled_forward_geometry', 'sampled_forward_integrate', 'sampled_forward_step']
for package in ['02_Negative_Cache_9', '03_Negative_Cache_90']:
    for mode in ['baseline', 'no_negative_reuse']:
        for name in names:
            old = snapshot / 'six_model_sampled_forward_comparison' / (name + '.m')
            new = HERE / package / 'engines' / mode / (name + '.m')
            if mode == 'no_negative_reuse' and name == 'sampled_forward_step':
                a = old.read_text(encoding='utf-8-sig')
                original = 'if any(cellId==g.cell_d), kind=2; end\nif any(cellId==g.cell_dout), kind=3; end'
                replacement = '% AI-assisted ablation: do not read learned non-target or domain-exit labels.\n% Target-cache reads, direct domain checks and recurrence rules are unchanged.'
                require(a.count(original) == 1 and a.replace(original, replacement) == new.read_text(encoding='utf-8-sig'), package + ': exactly two negative-cache reads removed')
            else:
                require(old.read_bytes() == new.read_bytes(), f'{package}/{mode}/{name}: historical bytes match')
    shared = [
        ('four_model_five_method_suite/functions/+limbench/angular_with_oracle.m', 'shared/+limbench/angular_with_oracle.m'),
        ('four_model_five_method_suite/functions/+limbench/private/angular_engine.m', 'shared/+limbench/private/angular_engine.m'),
        ('work/DynIn/DynIn_v1.1.0/functions/find_index.m', 'shared/native/find_index.m'),
        ('work/DynIn/DynIn_v1.1.0/functions/find_cells_around_a_cell.m', 'shared/native/find_cells_around_a_cell.m')]
    for source, target in shared:
        require((snapshot / source).read_bytes() == (HERE / package / target).read_bytes(), package + ': ' + target)
    for model in ['quadratic_cubic', 'bistable_duffing', 'genda_cosine_quadratic_drag']:
        require((DATA / 'dynin_models' / model / 'sistema.m').read_bytes() == (HERE / package / 'models' / model / 'sistema.m').read_bytes(), package + ': ' + model + ' bytes match')

source = ROOT / '05_Thesis_Result_Sources/source_data/experiment_B_multi_alpha'
audit = json.loads((HERE / '05_B_PerAlpha/recorded/audit.json').read_text())
for model, name in [('quadratic_cubic', 'qc_validation_raw.csv'), ('bistable_duffing', 'duffing_transfer_raw.csv')]:
    require(sha(source / name) == audit[model]['source_sha256'], model + ': original analysis input hash matches')

with (HERE / 'PRESERVED_FILES_SHA256.csv').open(encoding='utf-8', newline='') as f:
    entries = list(csv.DictReader(f))
modified = {f'06_Revision_Diagnostics/{p}/{d}' for p, d in drivers.items()}
missing_records = 0
for entry in entries:
    p = ROOT / entry['path']
    if entry['path'] in modified:
        continue
    if entry['kind'] == 'release_record' and not p.is_file() and not args.require_records:
        missing_records += 1
        continue
    require(p.is_file() and sha(p) == entry['sha256'], entry['path'] + ': preserved bytes match')

if args.require_records:
    saved = HERE / '03_Negative_Cache_90/results/20261028_040701_540'
    for name in names[1:]:
        require((saved / 'source_snapshot/engines/no_negative_reuse' / (name+'.m')).read_bytes() == (HERE / '04_Query567/engine' / (name+'.m')).read_bytes(), 'query567 engine matches completed 90-case source: '+name)
    for name in ['no_negative_reuse.mat', 'effective_settings.mat', 'all_results.csv', 'independent_postcheck/independent_validation.csv']:
        require((saved / 'quadratic_cubic_seed_30' / name).is_file(), 'query567 replay input: '+name)
print(json.dumps({'status': 'pass', 'root': str(ROOT), 'checks_passed': len(checks),
                  'release_records_not_extracted': missing_records,
                  'matlab_solver_execution': 'not performed by this read-only checker'}, indent=2))
