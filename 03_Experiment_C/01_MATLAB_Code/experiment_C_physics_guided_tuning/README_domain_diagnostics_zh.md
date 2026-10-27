# 实验 C：计算域诊断

打开 `test_experiment_C_domain_diagnostics.m` 并运行。默认读取已完成的 `outputs_duffing_transfer_20260923_003027_851`，检查 alpha=0.2、0.7、1.0。先只检查一个阻尼时，设置 `alphaValues=0.7`。

本阶段只有固定初始点的分类诊断，**没有 GA seed 循环，也不计算或读取参考 LIM**。先确定计算域是否修复分类问题，再决定下一轮 GA 设计。原始 `simulation_DI` 的越界处理保持不变，旧实验代码与数据不修改。

## 隔离的变量

每个阻尼复用上一轮 time_first 的 tfinal、Ts、目标格数 k、ODE 容差和重复访问判据；它只是对照配置，不被称为已通过的冻结分类器。校准点和原 holdout 点的坐标、参考标签全部保持不变。

主要比较固定的“原计算域内点集”。即使扩域使之前域外的点进入，也不把它们新加入主要统计分母，否则无法直接比较误分类变化。逐点文件中的 `inside_domain` 沿用原域内资格标记；`actual_inside_candidate_domain` 另行报告实际是否位于新域内。

扩域采用整数圈填充。原步长为 h_x、h_v，原每轴网格数为 N，则添加 m 圈后：

\[
N'=N+2m,\quad
D'=[x_{min}-mh_x,v_{min}-mh_v,x_{max}+mh_x,v_{max}+mh_v].
\]

这样同时保持两轴步长、原网格对齐和目标邻域的物理位置及尺寸，只增加外围单元。脚本检查步长差和目标矩形差，不使用“扩域但 N 不变”的混杂对照。由于原函数要求各轴同一个 N，可能在某一轴多填充一些单元。

## 三个计算域

1. `original_domain`：原域，重新运行分类作为配对基线。
2. `energy_envelope`：仅从校准点初始能量的最大值 E_max 生成理论包络，再加 5% 尺度余量。
3. `trajectory_envelope`：仅积分校准轨迹，结合观测包络和末端能量对应的后续运动包络，再加 5% 尺度余量。

双势阱模型满足

\[
E=\tfrac12v^2-\tfrac12x^2+\tfrac14x^4,\qquad
\dot E=-\alpha|v|^3\le0.
\]

因此，对初始能量不超过 E_max 的轨迹：

\[
|v|\le\sqrt{2(E_{max}+1/4)},\qquad
|x|\le\sqrt{1+\sqrt{1+4E_{max}}}.
\]

这是该双势阱模型的能量约束，不是通用于任意模型的公式。holdout 点中初始能量高于校准上界的数量会单列；不能把对校准能量集合的保证冒充为对所有初始状态的保证。

轨迹包络 pilot 使用较严格容差，不设数值域退出事件。到达势垒以下的能量封闭区，或达到原时长上限后停止；将末端能量的解析包络并入，以覆盖尚未积分的后续轨迹。前段包络仍由数值积分采样得到，因此该方案不是全域严格证明。记录能量单调性检查、是否达到能量封闭区以及计算成本。

候选域都在查看本次 holdout 分类结果前由校准信息生成。超过原 maximumGrid 上限时，记录 `grid_limit` 并跳过该候选，不降低分辨率，也不自动扩大资源限制。

## 判断是否修复

`summary_domain_diagnostics.csv` 对每个阻尼、域方案、诊断点集分别报告：

- false-safe、false-unsafe、未解析比例；
- 原来因越界而错判的点，有多少改成正确 target；
- 有多少仍错判为 non-target，或只是变成了未解析；
- domain_exit_false_unsafe 是否降到零；
- 相同点集上的分类耗时和资源状态。

若越界错误消失，但未解析增加，只说明域提前截断被移除，**不代表分类器已通过**。保留这个结果，后续单独检验时间，不在本轮同时延长时长。

`domain_decisions.csv` 的 `ready_for_separate_GA_design` 只表示两个复用点集上的分类要求和零越界误分类检查通过；它不是新 seed 的 GA 精度保证，更不自动启动 GA。

扩大原始 DynIn 的域可能改变其默认初始搜索半径，因此后续 GA 需要明确报告搜索范围变化。本轮固定初始点诊断没有这个混杂。

## 输出与恢复

- 根目录 `summary_domain_diagnostics.csv`：主要结果。
- 根目录 `pointwise_comparison.csv`：每个点的原标签和新标签，可直接追踪错误修正。
- 根目录 `domain_geometry.csv`：各域边界、N、固定步长、目标邻域偏差。
- 根目录 `domain_decisions.csv`：是否允许进入后续 GA 设计。
- case 子目录 `pilot_trajectories.csv`、`pilot_cost.csv`：校准包络和成本。

会显示 case、pilot 点和分类点进度。恢复时将 `resumeDir` 设为本次 `outputs_domain_diagnostics_...` 根目录，sourceDir 和 alphaValues 不变。已完成点从 CSV 检查点恢复。原始输入文件和源代码都有快照检查，避免混用版本。

不要把不同域的缓存目录合并：原分类辅助函数的缓存键不包含域边界，所以本脚本为每种域使用独立子目录。

## 证据边界

这次是针对已经发现的问题做的配对回归诊断。原 holdout 已经被我们分析过，因此虽未用于生成本轮候选域，**不能称为完全未见过的独立验证集**。修复规则确定后，应再安排新方向/半径点集和新 seed 的确认。

所有 old-domain 之外的原点仍保留在逐点输出，但不计入主要比较。固定点诊断也不等同于 GA 积累历史网格标签后的整体误分类率。

可先运行 `test_experiment_C_domain_geometry` 检查能量公式和整数网格填充。完整诊断必须在 MATLAB 中运行。
