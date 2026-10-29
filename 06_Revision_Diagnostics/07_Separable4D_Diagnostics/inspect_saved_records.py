"""AI-assisted read-only audit of the 30 frozen separable-4D Proposed runs.

No trajectory integration, search, label correction or original file writing.
MATLAB strings are not decoded: classification reasons use numeric saved fields
and the archived classifier branch mapping.
"""
from pathlib import Path
import argparse
import csv
import hashlib
import json
from collections import Counter
import numpy as np
from scipy.io import loadmat


def records(value):
    if isinstance(value, dict):
        return [value]
    return list(value)


def reason(q):
    kind, cache = int(q['native_tipo']), int(q['grid_cache_kind'])
    if q['integration_count'] == 0:
        return 'not_integrated_reason_requires_MATLAB_string'
    if q['forced_non_target']:
        return 'horizon_forced_non_target'
    if cache:
        return {1:'known_target_grid_cell', 2:'known_non_target_grid_cell',
                3:'known_domain_exit_grid_cell'}[cache]
    return {1:'native_target_neighbourhood',3:'left_computational_domain',
            4:'native_non_target_recurrence'}.get(kind, 'check_native_tipo')


def write_csv(path, rows):
    with path.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--input',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args()
    if a.output.exists():
        raise FileExistsError('Use a new output directory; never overwrite a recorded audit.')
    a.output.mkdir(parents=True)
    settings=a.input/'separable_qc_bd_4d_settings.mat'
    d=loadmat(settings,simplify_cells=True)['dynin']
    target=np.asarray(d['target'],float)
    weights=np.asarray(d['weight'],float)
    summaries=[]; all_queries=[]; all_rays=[]; hashes=[]
    files=sorted((a.input/'runs').glob('separable_qc_bd_4d__proposed_sampled_forward__seed_*.mat'),
                 key=lambda p:int(p.stem.rsplit('_',1)[-1]))
    assert len(files)==30
    for path in [settings]+files:
        hashes.append(dict(file=str(path.resolve()),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    for path in files:
        data=loadmat(path,simplify_cells=True)
        row=data['row']; details=data['details']
        qs=records(details['query_records']); rays=records(details['rays'])
        seed=int(row['seed']); ref=float(row['R_reference']); estimate=float(row['R_hat'])
        assert len(qs)==row['query_count']
        radii=np.array([float(r['boundary_radius']) for r in rays])
        finite=np.isfinite(radii)
        assert np.any(finite) and abs(np.min(radii[finite])-estimate)<1e-12
        winners=np.flatnonzero(finite & (np.abs(radii-estimate)<1e-12))
        assert len(winners)==1, 'Tied winning rays require explicit handling.'
        index=int(winners[0]); r=rays[index]
        lower=float(r['bracket_lower']); upper=float(r['bracket_upper'])
        assert abs((lower+upper)/2-estimate)<1e-12
        assert abs(upper-lower-r['bracket_width'])<1e-12
        direction=np.asarray(r['direction'],float)
        assert abs(np.linalg.norm(direction)-1)<1e-12
        state_u=target+upper*direction/np.sqrt(weights)
        state_l=target+lower*direction/np.sqrt(weights)
        matches_u=[j for j,q in enumerate(qs) if np.max(np.abs(q['initial_state']-state_u))<1e-10]
        matches_l=[j for j,q in enumerate(qs) if np.max(np.abs(q['initial_state']-state_l))<1e-10]
        assert len(matches_u)==1 and len(matches_l)==1, (seed,matches_u,matches_l)
        u=matches_u[0]; l=matches_l[0]
        assert qs[u]['native_tipo']!=1 and qs[l]['native_tipo']==1
        unsafe=[]
        for j,q in enumerate(qs):
            state=np.asarray(q['initial_state'],float)
            rho=float(np.sqrt(np.sum(weights*(state-target)**2)))
            assert abs(rho-q['initial_radius'])<1e-10
            assert q['query_id']==j+1
            is_non_target=q['integration_count']>0 and q['native_tipo']!=1
            if is_non_target and rho<ref-1e-10:
                unsafe.append(j+1)
            qr=dict(seed=seed,query=j+1,radius=rho,below_reference=rho<ref-1e-10,
                    native_tipo=int(q['native_tipo']),cache_kind=int(q['grid_cache_kind']),
                    reason=reason(q),sample_count=int(q['sample_count']),end_time=float(q['end_time']),
                    integration_count=int(q['integration_count']),forced_non_target=bool(q['forced_non_target']))
            qr.update({f'z{k+1}':float(v) for k,v in enumerate(state)})
            all_queries.append(qr)
        for j,ray in enumerate(rays):
            all_rays.append(dict(seed=seed,ray=j+1,boundary_radius=float(ray['boundary_radius']),
                bracket_lower=float(ray['bracket_lower']),bracket_upper=float(ray['bracket_upper']),
                bracket_width=float(ray['bracket_width']),winning=(j==index)))
        s=dict(seed=seed,algorithm_seed=int(row['algorithm_seed']),reference=ref,
            midpoint=estimate,lower=lower,upper=upper,bracket_width=upper-lower,
            midpoint_below=estimate<ref-1e-10,upper_below=upper<ref-1e-10,
            midpoint_error_percent=100*(estimate-ref)/ref,upper_error_percent=100*(upper-ref)/ref,
            upper_minus_midpoint=upper-estimate,
            midpoint_shift_percent_of_deficit=100*(upper-estimate)/(ref-estimate) if estimate<ref else 0.,
            winning_ray=index+1,lower_query=l+1,upper_query=u+1,upper_reason=reason(qs[u]),
            upper_native_tipo=int(qs[u]['native_tipo']),upper_cache_kind=int(qs[u]['grid_cache_kind']),
            upper_sample_count=int(qs[u]['sample_count']),upper_end_time=float(qs[u]['end_time']),
            first_non_target_below_query=unsafe[0] if unsafe else 0,
            total_non_target_below_queries=len(unsafe),total_queries=len(qs))
        s.update({f'upper_z{k+1}':float(v) for k,v in enumerate(state_u)})
        summaries.append(s)
    write_csv(a.output/'all30_endpoint_audit.csv',summaries)
    write_csv(a.output/'all_query_numeric_labels.csv',all_queries)
    write_csv(a.output/'all_ray_brackets.csv',all_rays)
    write_csv(a.output/'source_sha256.csv',hashes)
    under=[s for s in summaries if s['midpoint_below']]
    reasons=Counter(s['upper_reason'] for s in summaries)
    under_reasons=Counter(s['upper_reason'] for s in under)
    count_rows=[]
    for seed in range(1,31):
        for key,count in sorted(Counter(q['reason'] for q in all_queries if q['seed']==seed).items()):
            count_rows.append(dict(seed=seed,reason=key,count=count))
    write_csv(a.output/'saved_reason_counts.csv',count_rows)
    result=dict(runs=30,midpoints_below_reference=len(under),
        winning_upper_endpoints_below_reference=sum(s['upper_below'] for s in summaries),
        below_midpoint_with_upper_not_below=sum(not s['upper_below'] for s in under),
        original_winning_upper_reasons=dict(reasons),underestimated_winning_upper_reasons=dict(under_reasons),
        upper_below_seeds=[s['seed'] for s in summaries if s['upper_below']],
        midpoint_shift_percent_of_deficit_range=[min(s['midpoint_shift_percent_of_deficit'] for s in under),
                                                max(s['midpoint_shift_percent_of_deficit'] for s in under)],
        winning_bracket_width_range=[min(s['bracket_width'] for s in summaries),max(s['bracket_width'] for s in summaries)],
        upper_error_percent_under_range=[min(s['upper_error_percent'] for s in under),max(s['upper_error_percent'] for s in under)],
        direct_provenance_available=False,independent_integrations_performed=False,
        limitation='Cached label writer and triggering cell are not saved. Ordered MATLAB replay is required; cache hits alone do not identify the first wrong label.')
    for h in hashes:
        assert hashlib.sha256(Path(h['file']).read_bytes()).hexdigest()==h['sha256']
    (a.output/'audit_summary.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()
