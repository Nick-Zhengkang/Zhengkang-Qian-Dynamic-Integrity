# 实验 C：受控完整 GA 测试

## 目的

独立诊断已经证明，冻结的 `energy_envelope` 计算域能够消除原始计算域造成的
越界型 false-unsafe。这个实验继续回答：这种分类改进能否传递到完整的 DynIn GA
LIM 估计。

## 唯一主动改变

同一个阻尼参数和同一个 seed 下，只比较：

- `original_domain`：原始计算域；
- `energy_envelope`：独立验证通过的冻结能量包络计算域。

两者使用相同的 GA 参数、目标邻域物理尺寸、网格步长、积分参数、轨迹预算、
ODE 容差和随机 seed。原始 `compute_LIM_FP.m` 不做任何修改。

## 一个必须报告的耦合

原始 DynIn 将目标到最近计算域边界的距离设为初始搜索半径。因此扩展计算域会同时：

1. 减少轨迹离开计算域造成的错误分类；
2. 扩大初始 GA 搜索球。

原接口不能在不修改算法的情况下独立固定这个半径。本实验将
`initial_search_radius`、首个初始点及半径比写入结果，因此评价的是“完整计算域迁移
规则的净效果”，不能把差异全部归因于分类器。

## 默认确认实验

- 模型：bistable Duffing；
- 阻尼：`alpha = [0.2, 0.7, 1.0]`；
- seed：`61:90`，共 30 个新 seed；
- 每次运行：100 条完整轨迹；
- 总运行数：`3 x 2 x 30 = 180`；
- 主精度阈值：2%；同时报告 1% 和 5%。

## 运行与恢复

打开 `test_experiment_C_controlled_GA.m` 并按 Run。

如果中断，把已生成的 `outputs_controlled_GA_domain_*` 完整路径填入入口脚本的
`resumeDir`。程序会读取逐次 MAT 检查点，不会重新计算已经完成的运行。

## 主要输出

- `raw_data_all_runs.csv`：每次完整 GA 运行；
- `summary_by_alpha_and_domain.csv`：每个阻尼和计算域的结果；
- `summary_overall_by_domain.csv`：跨三个阻尼的总体结果；
- `paired_contrasts_by_seed.csv`：同一 alpha、同一 seed 的成对差值；
- `paired_contrast_summary.csv`：成对差值汇总；
- `frozen_settings_audit.csv`：所有冻结设置和初始搜索半径；
- `run_checkpoints`：可恢复检查点与每次 LIM 历史。

## 判读顺序

先检查失败数和 `n_domain_exit_iterations`，再比较 2% 达标率与误差分布，最后比较
成对运行时间。若能量域减少越界并提高达标率，但初始搜索半径明显改变，应把结果表述
为完整域迁移规则有效，而不是宣称单独证明了分类域扩展的因果效应。
