"""AI-assisted statistics; portable paths, unchanged calculation and frozen inputs."""
from pathlib import Path
import csv
import hashlib
import json
import math
import numpy as np
import argparse

PACKAGE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=PACKAGE / 'reproduced_results')
args = parser.parse_args()
ROOT = args.output.resolve()
SOURCE = PACKAGE.parent.parent / '05_Thesis_Result_Sources/source_data/experiment_B_multi_alpha'
THESIS = SOURCE
assert SOURCE.is_dir(), 'Download the complete repository, not this folder alone.'
assert not ROOT.is_relative_to(SOURCE), 'Output must not be inside the input directory.'
ROOT.mkdir(parents=True, exist_ok=False)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

before = {str(p.relative_to(THESIS)): digest(p) for p in THESIS.rglob('*') if p.is_file()}

def read(name):
    with (SOURCE / name).open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

def percentile95(values):
    # Same convention as the archived MATLAB summaries: (i - 0.5) / n.
    a = sorted(values)
    h = len(a) * .95 + .5
    if h >= len(a):
        return a[-1]
    k = int(math.floor(h))
    return a[k-1] + (h-k) * (a[k]-a[k-1])

def fmt(value):
    return f'{value:.3f}'

report = [
    '# 实验B：按 alpha 的现有数据重分析', '',
    '这里只重新统计已保存的运行记录，没有重新运行 MATLAB、优化或积分，也没有修改原始数据和论文。', '',
    '## 统计口径', '',
    '- 相对误差 e = 100 * abs(R_hat - R_ref) / R_ref；中位数、P95和最大值均以 % 表示。',
    '- 严重失败定义为 e > 50%，沿用论文原有定义。失败列为次数/总次数（百分比）。',
    '- 这是误差阈值失败，不是程序执行失败，也不是独立轨迹分类验证结果。',
    '- P95采用 MATLAB 已保存汇总对应的分位数约定，即排序位置 h = 0.95*n + 0.5，并在相邻点间插值。',
    '- 每组100次时P95为第95和96个有序误差的平均；每组10次时P95等于最大值。',
    '- 训练 alpha 为0.10, 0.20, ..., 2.00；0.05低于训练范围。训练范围内的非训练点是插值验证，不是训练点。',
    '- 所有原记录均纳入统计。未剔除低 alpha、离群值或严重失败。有限样本中零失败不证明普遍可靠。', '',
]
audit = {}
summary_records = {}
for key, raw_name, prior_name, expected_n, title in [
    ('quadratic_cubic', 'qc_validation_raw.csv', 'qc_validation_comparison_by_alpha.csv', 100,
     'Quadratic-cubic：冻结配置的同模型验证'),
    ('bistable_duffing', 'duffing_transfer_raw.csv', 'duffing_comparison_by_alpha.csv', 10,
     'Bistable Duffing：冻结配置的跨模型迁移'),
]:
    rows = read(raw_name)
    old = {round(float(r['alpha']), 8): r for r in read(prior_name)}
    alphas = sorted({round(float(r['alpha']), 8) for r in rows})
    assert len(alphas) == (20 if expected_n == 100 else 40)
    assert len(rows) == 2 * expected_n * len(alphas)
    assert {r['role'] for r in rows} == {'baseline', 'candidate'}
    keys = [(r['role'], round(float(r['alpha']), 8), int(r['seed'])) for r in rows]
    assert len(keys) == len(set(keys)), 'Duplicate role/alpha/seed'
    assert all(r['success'] == '1' and not r['error_message'].strip() for r in rows)
    discrepancies = []
    for r in rows:
        ref, estimate = float(r['reference_LIM']), float(r['R_hat'])
        assert ref > 0 and math.isfinite(estimate)
        error = abs(estimate-ref)
        relative = 100*error/ref
        assert math.isclose(error, float(r['absolute_error']), abs_tol=2e-13, rel_tol=1e-9)
        assert math.isclose(relative, float(r['relative_error_percent']), abs_tol=2e-10, rel_tol=1e-9)
        r['error_recomputed'] = relative
    out = []
    for alpha in alphas:
        record = {'alpha': alpha, 'relation_to_training': ('below_training_range' if alpha < .1 else
                  'training_alpha_new_model' if key == 'bistable_duffing' and abs(alpha*10-round(alpha*10)) < 1e-8
                  else 'within_training_range_untrained_alpha')}
        paired = {}
        for role in ('baseline', 'candidate'):
            group = [r for r in rows if round(float(r['alpha']), 8) == alpha and r['role'] == role]
            assert len(group) == expected_n
            paired[role] = {int(r['seed']) for r in group}
            errors = [r['error_recomputed'] for r in group]
            absolute = [float(r['absolute_error']) for r in group]
            median, p95 = float(np.median(errors)), percentile95(errors)
            assert math.isclose(p95, float(np.quantile(errors, .95, method='hazen')), abs_tol=1e-12)
            assert math.isclose(float(np.median(absolute)), float(old[alpha][role+'_median_absolute_error']), abs_tol=2e-13)
            assert math.isclose(percentile95(absolute), float(old[alpha][role+'_p95_absolute_error']), abs_tol=2e-13)
            failed = sum(e > 50 for e in errors)
            record.update({
                role+'_n': expected_n,
                role+'_median_relative_error_percent': median,
                role+'_p95_relative_error_percent': p95,
                role+'_maximum_relative_error_percent': max(errors),
                role+'_severe_failure_count_gt50': failed,
                role+'_severe_failure_percent_gt50': 100*failed/expected_n,
            })
        assert paired['baseline'] == paired['candidate']
        out.append(record)
    filename = key + '_per_alpha.csv'
    with (ROOT / filename).open('w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(out[0]))
        writer.writeheader()
        writer.writerows(out)
    report += ['## '+title, '', f'每个 alpha、每种配置均为 {expected_n} 次；共 {len(rows)} 条原始记录。', '',
               'B = baseline；O = 优化后的冻结配置。以下误差列单位均为 %。', '',
               '| alpha | B 中位数 | B P95 | B 最大值 | B 严重失败 | O 中位数 | O P95 | O 最大值 | O 严重失败 |',
               '|---|---:|---:|---:|---|---:|---:|---:|---|']
    for r in out:
        cells = [f"{r['alpha']:.2f}" + ('（外推）' if r['alpha'] < .1 else '')]
        for role in ('baseline', 'candidate'):
            cells += [fmt(r[role+s]) for s in ('_median_relative_error_percent', '_p95_relative_error_percent', '_maximum_relative_error_percent')]
            cells += [f"{r[role+'_severe_failure_count_gt50']}/{r[role+'_n']} ({r[role+'_severe_failure_percent_gt50']:.0f}%)"]
        report.append('| '+' | '.join(cells)+' |')
    report.append('')
    audit[key] = {'source': str(SOURCE/raw_name), 'source_sha256': digest(SOURCE/raw_name),
        'input_rows': len(rows), 'alpha_count': len(alphas), 'runs_per_alpha_role': expected_n,
        'duplicate_keys': 0, 'execution_failures': 0, 'nonfinite_estimates': 0,
        'saved_error_values_reconciled': True, 'saved_per_alpha_absolute_medians_and_p95_reconciled': True}
    details = {}
    for role in ('baseline', 'candidate'):
        details[role] = {
            'severe_failure_total': sum(r[role+'_severe_failure_count_gt50'] for r in out),
            'severe_failure_by_alpha': [(r['alpha'], r[role+'_severe_failure_count_gt50']) for r in out if r[role+'_severe_failure_count_gt50']],
            'max_of_medians': max(r[role+'_median_relative_error_percent'] for r in out),
            'within_training_range_median_range': [min(r[role+'_median_relative_error_percent'] for r in out if r['alpha'] >= .1), max(r[role+'_median_relative_error_percent'] for r in out if r['alpha'] >= .1)],
            'within_training_range_p95_range': [min(r[role+'_p95_relative_error_percent'] for r in out if r['alpha'] >= .1), max(r[role+'_p95_relative_error_percent'] for r in out if r['alpha'] >= .1)],
            'within_training_range_maximum': max(r[role+'_maximum_relative_error_percent'] for r in out if r['alpha'] >= .1),
        }
    details['both_median_and_p95_improved_alphas'] = [r['alpha'] for r in out if r['candidate_median_relative_error_percent'] < r['baseline_median_relative_error_percent'] and r['candidate_p95_relative_error_percent'] < r['baseline_p95_relative_error_percent']]
    summary_records[key] = details

after = {str(p.relative_to(THESIS)): digest(p) for p in THESIS.rglob('*') if p.is_file()}
assert before == after, 'Input files changed during analysis'
audit['source_files_byte_unchanged'] = True
audit['checked_file_count'] = len(before)
audit['failure_rule'] = 'absolute relative error > 50 percent; strict inequality'
audit['p95_rule'] = 'Hazen / h=n*p+0.5, matching saved MATLAB per-alpha summaries'
(ROOT/'audit.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')
(ROOT/'summary.json').write_text(json.dumps(summary_records, indent=2), encoding='utf-8')
(ROOT/'Full_PerAlpha_Results.txt').write_text('\n'.join(report)+'\n', encoding='utf-8-sig')
print(json.dumps(summary_records, indent=2))
print('Verified: all input files unchanged; results written to', ROOT)
