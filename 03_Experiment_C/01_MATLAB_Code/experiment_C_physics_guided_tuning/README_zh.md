# 实验 C：基于物理尺度的 DynIn GA 参数迁移

## 研究问题

当 DynIn GA 从一个模型迁移到另一个模型时，哪些参数必须优先调整，
以及这些参数能否只根据新模型的方程估计，而不读取参考 LIM？

本实验不再把上一模型的参数数值直接搬到新模型。原始 DynIn v1.1.0
代码保持不变，并始终使用 GA 分支 `type_x0 = 1`。

## 参数估计逻辑

对每个模型先由势能和局部线性化计算：

- 目标平衡点与相邻鞍点；
- 势垒 `DeltaV`；
- 局部曲率和频率 `omega0`；
- 位置尺度 `Lx` 与速度尺度 `Lv = sqrt(2 DeltaV)`；
- 二次阻尼下的近似振幅衰减时间。

随后映射为 DynIn 参数：

1. **计算域**：覆盖目标阱、相邻鞍点和保守转向点，并加 20% 余量。
2. **`discr`**：让归一化网格宽度不超过 `eta_grid = 0.005`。
3. **目标邻域**：取局部能量不超过势垒的 `beta_target = 0.005`，再换算为奇数个网格单元。
4. **`Ts`**：局部振动周期的 `1/125`。
5. **`tfinal`**：二次阻尼平均衰减时间的 1.5 倍，且不少于 20 个局部周期。
6. **`rep_periodic`**：大于预计衰减周期数，防止衰减振荡被误判为周期吸引子。

参考 LIM 不参与上述计算，只在运行结束后计算误差和设置独立诊断点。

## 筛选阶段

默认 10 个 paired seeds，依次比较：

1. `essential_only`：只对齐目标、距离定义和计算域；
2. `geometry_scaled`：再加入物理网格与目标邻域；
3. `decay_time_scaled`：再加入衰减时间与采样间隔；
4. `physics_N100`：再加入衰减感知的周期判断阈值；
5. `physics_N50` 和 `physics_N200`：检查完整积分预算是否充分。

相邻阶段采用相同 seed 做 paired contrast。由哪一步开始误差和误分类明显改善，
就可以判断迁移时应优先调整哪一类参数。

## 冻结确认阶段

冻结物理公式及其常数后，使用 30 个新 seeds 比较 `N=50/100/200`。
选择满足误差、false-safe rate 和稳定性要求的最小预算，而不是利用参考 LIM
逐个模型反向调参。

## 运行

打开 `test_experiment_C_physics_guided.m`，修改：

```matlab
benchmark_name = 'quadratic_cubic';
phase = 'screening';
seed_list = 1:10;
```

先运行 `screening`。完成四个模型并确定预算后，再把阶段改为
`confirmation`，seed 改为 `1:30`。

最重要的审计文件是 `parameter_estimation_audit.csv`。它记录每个模型的
物理尺度、公式中间量和最终参数，并明确标记 `reference_LIM_used = false`。

## 高维验证：Habib 四维 Duffing-Van der Pol + NLTVA

入口脚本现在还支持：

```matlab
benchmark_name = 'habib_vdp_tmd';
phase = 'screening';
seed_list = 1:10;
```

该分支直接调用 DynIn 软件包内的原始 `sistema.m`、
`coefficients_VDPD_NLTVA.m` 和 `compute_LIM_FP.m`，并始终采用 GA 选点
`type_x0 = 1`。模型方程和 DynIn 算法不做修改。

高维模型不再使用二维势垒公式。参数由更一般的局部信息估计：

1. 在目标平衡点对方程数值线性化，得到 Jacobian 的快、慢特征时间尺度；
2. 解连续 Lyapunov 方程，构造目标附近的局部收敛椭球；
3. 用非线性方程在多个确定性方向上验证椭球内的收缩性；
4. 将验证后的椭球换算为 `discr` 和目标单元带，并强制目标邻域至少为
   非平凡奇数宽度 3；
5. 用最快振动周期设置 `Ts`，用预计衰减周期数设置 `rep_periodic`；
6. 把 Jacobian 衰减时间作为 `tfinal` 初值，再使用 36 个固定 pilot 初始状态
   进行 `T`/`2T` 检查；连续两轮没有新增轨迹返回目标后才冻结积分时间；
7. 论文明确报告的 GA 参数和 ODE 容差按 Habib 论文设置，不再采用
   Starter 的数值配置。

筛选阶段比较七个累计配置。基线为 Habib 论文可核对的四维模型 GA 配置：
`type_x0=1`、每维 `701` 个单元、计算域 `[-3,3]^4`、`Ts=0.05`、
`RelTol=AbsTol=1e-8`、5 代、每代 20 个个体，并依据 Fig. 7 运行 40 次外层迭代。
随后依次加入 Jacobian-Lyapunov 空间参数、`Ts`、`rep_periodic` 和 pilot 校准的
`tfinal`，最后在分类参数冻结后比较 `N=40/100/200`。相邻配置只改变一个参数块，
并使用相同 seed 做 paired contrast。Starter 不再作为实验基线。

论文没有数值报告 `tfinal`、目标邻域宽度、GA 的 20 个个体如何分配以及
`divR`。这些运行所需的实现控制量不会被称为“论文参数”，而是单独记录在
`paper_baseline_parameter_sources.csv` 中。基线的目标标签只包含平衡点所在的
单元；初始 `tfinal` 由 Jacobian 给出下限，后续 profile 再用固定 pilot 检查。
测试参数为 `mu1 = 0.065, 0.075, 0.095`，分别覆盖靠近折叠分岔、论文默认值
和靠近 Hopf 分岔的情况。

这个模型没有可直接用于每次运行评分的解析 LIM。因此结果不报告虚假的相对误差，
而使用以下证据：不同 seed 的估计分布、最后若干迭代的变化幅度、增加
`number_of_steps` 后的成对变化，以及运行时间。主要输出为：

- `jacobian_parameter_audit.csv`：局部特征值、Lyapunov 椭球及参数换算过程；
- `paper_baseline_parameter_sources.csv`：每个基线参数的论文出处与未报告项；
- `pilot_horizon_audit.csv`：每轮 `T`/`2T` 检查、新增返回轨迹和最终时长；
- `summary_by_case_and_profile.csv`：跨 seed 稳定性与运行成本；
- `paired_contrasts_parameter_blocks.csv`：空间、时间和预算参数块的增量作用；
- `budget_stability_matrix.csv`：`N=30/100/200` 的稳定性检查。
