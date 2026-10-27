# 实验 C：计算域规则的独立验证

运行 `test_experiment_C_domain_independent_validation.m`。

本实验不重新估计计算域。它直接读取
`outputs_domain_diagnostics_20260923_202423_727` 中已经冻结的
`original_domain` 和 `energy_envelope` 设置，然后在一组全新的初始状态上比较分类结果。

## 新验证点

- 18 个新方向，方向偏移与旧 calibration/holdout 不同；
- 7 个径向尺度；
- 原计算域四条边附近的压力点；
- 所有初始点都在原计算域内；
- 脚本计算新点与旧点的归一化距离，并拒绝任何重复坐标；
- 新点不会用于重建或扩大能量包络。

每个新点先由更严格容差、更长积分时长的 oracle 给出 target、non-target
或 unresolved 标签，再由原始 DynIn 分类器分别在原计算域和冻结能量包络域中分类。
不读取解析 LIM，也不运行 GA。

## 主要判断

`summary_independent_domain_validation.csv` 报告 false-safe、false-unsafe、
未解析比例和 domain-exit false-unsafe。冻结能量域只有在以下条件全部满足时才通过：

1. 有足够数量的 target 和 non-target 已解析点，并覆盖新方向、不同半径和域边缘；
2. false-safe、false-unsafe 和 unresolved 不超过预设阈值；
3. target 轨迹的 domain-exit 错误为零。

脚本还会单独统计初始能量高于旧校准能量上界的点。这部分是压力测试：旧能量包络
对这些点没有严格覆盖保证。如果它们失败，下一步应把能量上界改为“允许的完整初始搜索区域
中的最大可能能量”，而不是继续从更多已观察轨迹中拟合计算域。

## 输出与恢复

- `fresh_validation_truth.csv`：新点及独立 oracle 标签；
- `fresh_pointwise_comparison.csv`：原始域与能量域逐点分类；
- `summary_independent_domain_validation.csv`：各阻尼和域方案的汇总；
- `independent_domain_decisions.csv`：能否进入受控完整 GA 测试。

脚本逐点保存，意外中断后把入口脚本中的 `resumeDir` 设置为本次输出目录即可继续。

