"""AI-assisted reproduction of v17 Table 6.5 from unchanged recorded CSVs."""
from pathlib import Path
import argparse
import csv
import json
import statistics

ROOT = Path(__file__).resolve().parent

def read(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

def summarize():
    specs=json.loads((ROOT/'V17_PACKAGES.json').read_text())
    stages=[]
    for spec in specs:
        folder=ROOT/spec['folder']
        cases=read(folder/'recorded_summaries'/spec['run_id']/'case_summary.csv')
        assert len(cases)==30
        if spec['folder'].startswith('07'):
            audit=read(folder/'static_audit/all30_endpoint_audit.csv')
            errors=[abs(float(r['midpoint_error_percent'])) for r in audit]
            below_mid=sum(r['midpoint_below'].lower()=='true' for r in audit)
            below_upper=sum(r['upper_below'].lower()=='true' for r in audit)
            lowkey,upkey='lower_independent_outcome','upper_independent_outcome'
        else:
            errors=[abs(float(r['midpoint_error_percent'])) for r in cases]
            below_mid=sum(int(r['midpoint_below_reference']) for r in cases)
            below_upper=sum(int(r['upper_below_reference']) for r in cases)
            lowkey,upkey='lower_validation','upper_validation'
        stages.append(dict(stage=spec['folder'], run_id=spec['run_id'], seeds=30,
            midpoint_below_reference=below_mid, upper_below_reference=below_upper,
            median_absolute_relative_error_percent=statistics.median(errors),
            maximum_absolute_relative_error_percent=max(errors),
            within_one_percent=sum(x<=1 for x in errors),
            lower_target=sum(r[lowkey]=='both_solvers_support_target' for r in cases),
            upper_non_target=sum(r[upkey]=='both_solvers_support_non_target' for r in cases)))
    assert [(r['midpoint_below_reference'],r['lower_target'],r['upper_non_target']) for r in stages]==[(24,29,1),(0,2,30),(0,30,30)]
    return stages

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,help='New output directory; refuses to overwrite.')
    args=parser.parse_args()
    result=summarize()
    if args.output:
        args.output.mkdir(parents=True,exist_ok=False)
        (args.output/'table_6_5.json').write_text(json.dumps(result,indent=2)+'\n')
        with (args.output/'table_6_5.csv').open('w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=list(result[0]))
            w.writeheader(); w.writerows(result)
    print(json.dumps(result,indent=2))
