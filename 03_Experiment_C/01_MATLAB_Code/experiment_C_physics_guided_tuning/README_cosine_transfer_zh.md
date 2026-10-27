# 实验 C：将规则迁移到原有 cosine benchmark

## 运行

在 MATLAB 中打开并运行 `test_experiment_C_cosine_transfer.m`。
默认 `alpha=0.05`，`seeds=91:120`，每次 `number_of_steps=100`。
诊断通过后执行两组设置 × 30 个配对 seed，共 60 次完整 GA。
入口中的 `mode='diagnostics'` 仅做诊断并冻结配置；`mode='prepare'` 仅生成初始设置和源码快照。

中断后：把输出文件夹完整路径填入入口的 `resumeDir`，保持 alpha、seeds、预算不变，再运行。
已完成的诊断点和 GA 运行会读取检查点。正在执行但尚未保存的一条轨迹会重算。
源码快照校验可防止修改算法后混用旧结果。不要为了续跑改动函数文件。

## 模型和参考值

选自原来的四个 benchmark，不是新增模型：

\[
\ddot x+0.05|\dot x|\dot x+\sin x=0,
\qquad z_e=(0,0),\quad W=I.
\]

之前 cosine 参加过五方法比较，但尚未接受现在的迁移规则验证。
Paper Duffing 曾是实验 A/B 的开发模型；不要把“以前没做过任何测试”与“没验证过本套规则”混淆。

复用此前四模型测试中的 `fourbench.reference`，不重新拟合参考值。
Genda《Manuscript version 2》原有代码引用为 Fig. 2、Eqs. 26, 29, 34, 37。
参考属于**解析边界表达式经数值求根得到的 LIM**，不是把论文图读数当成精确解：

\[
v_b^2(x)=\frac{2}{1+4\alpha^2}
\left[\cos x-2\alpha\sin x+e^{2\alpha(\pi-x)}\right],\quad 0\le x\le\pi,
\]
\[
(1+4\alpha^2)x_*-\sin x_*-2\alpha\cos x_*
-2\alpha e^{2\alpha(\pi-x_*)}=0,
\quad R_{\rm ref}=\sqrt{x_*^2+v_b^2(x_*)}\approx2.087159265254399.
\]

求根后另用一维最小化交叉核验。`reference_audit.csv` 保存类型、来源、残差和计算时间。
正式脚本仅在校准和独立诊断通过、参数冻结后调用参考函数。
`check_experiment_C_cosine_transfer.m` 是单独的公式单元检查，不参与调参流程。

原来四个模型的参考类型：quadratic-cubic、二次阻尼 bistable Duffing 和 cosine 使用解析边界/分支的数值评估；Habib Paper Duffing 的 0.7683 是论文报告的近似数值结果，而且使用其对应的加权距离。这里不使用 0.7683。

## 如何从方程生成设置

1. 目标平衡点为 0，两侧鞍点为 ±π，势垒高度为 2；局部曲率为 1，小振动周期为 2π。
2. 初始搜索球半径取到鞍点的距离 π，x 方向计算域取 [-π,π]。对球内任何点，E=v²/2+1−cos x≤(x²+v²)/2≤π²/2，且 E'=-α|v|³≤0，因此速度始终不超过 π。速度域加 1% 余量，取 ±3.17300858；x 面仍固定初始搜索半径，不因扩速度域而放大 GA 搜索球。
3. 周期势不能用能量给出全局有限 x 包络。轨迹向外跨过 ±π 后不再返回目标势阱：如果之后发生转向，转向时 E=V≤2，后续耗散使其无法再越过能量为 2 的鞍点。故这里合法的离开目标势阱可以判为非目标，不能将所有 tipo=3 当作域覆盖失败。此论证限于当前无外激励、一自由度、正耗散模型。
4. 保留之前规则的无量纲常数 eta=0.005、beta=0.005。用位置尺度 π 和速度尺度 2 换算网格，得到 discr=635；在目标邻域所有位置均低于 beta×势垒的前提下选奇数格数，得到 k=19，而不是照搬 Duffing 的格数。
5. Ts=局部周期/125≈0.0502655。沿用二次阻尼平均振幅衰减的初步估计和 1.5 安全系数，得到 tfinal=680。这只是候选值，不是充分积分时间的数学保证。

## 诊断后才冻结

校准点覆盖整个允许的 GA 初始搜索球，并在观察到的分类转换附近补点。
独立标签来自更严容差的正向积分及能量困陷判定，不使用解析边界位置或参考 LIM。
未解析、异常、false-safe、false-unsafe 分开记录。

按顺序比较 T 与 2T、Ts 与 Ts/2、当前网格与更细网格；改变网格时按同一个目标能量比例重算 k。
采用已有 `experiment_C_rule_decision`：诊断改善或采样轨迹距离未稳定时才采用候选，再次检查。
采样检查同时查看非目标轨迹所给最近距离的变化，不只看标签一致。
后面的调整发生后，重新检查前面的参数块。rep_periodic=10 不随时间一起改变。
达到资源/加密上限仍未通过时停止并保留诊断结果，不悄悄放宽标准。

全套分类检查仍使用之前的预设条件：false-safe=0，false-unsafe≤2%，未解析≤2%，独立标签未解析≤5%，并要求两类和边界附近都有足够诊断点。
这些是有限诊断集上的经验门槛，不是总体误分类概率的统计保证。
随后使用另一批方向与半径做独立检查；失败时不再使用该批点调参，也不运行正式 GA。

## 对照的含义

|组别|分类与数值设置|GA|
|---|---|---|
|historical_cosine|此前 cosine 设置：域 [-π,π]×[-8,8]、discr=501、k=11、T=1200、Ts=0.05、容差 1e-8/1e-9|与另一组完全相同|
|physics_rule|从方程生成，并经过校准与独立诊断的设置|冻结参数，不再优化高估误差|

两组共同使用 type_x0=1、divR=40、num_gen=5、num_crossover=9、selected_opt=3、newcomers=8、num_almost_clones=2、rep_fix_point=40、rep_periodic=10。
搜索半径均为 π，配对 seed 相同，运行顺序随机化。核对每对首个初始点是否一致。
历史组是“历史 cosine 数值设置搭配共同的冻结 GA”，**不是原五方法实验的逐项复跑，也不是 Habib 论文 GA 的完整复现**。
这是完整迁移流程对照，不是仅改变计算域的消融；网格、目标邻域、时间及容差的变化会共同影响结果。

## 输出与解释

- `physics_initial_settings.csv`：未经诊断的物理候选值。
- `calibration_decisions.csv`：调整信号、前后参数及决策。
- `independent_validation_summary.csv` 和 `independent_pointwise_validation.csv`：冻结候选的独立诊断。
- `historical_validation_summary.csv`：同一独立点集上的历史设置结果，仅用于评价。
- `frozen_settings.csv`：两组真正运行的参数。
- `diagnostic_costs.csv`：独立标签、校准和验证的成本，读取缓存不重复计入。
- `session_cost_*.csv`：本次会话准备和预热时间；包含文件开销，不要与诊断成本直接相加。
- `raw_data_all_runs.csv`、`summary_by_profile.csv`、`paired_contrasts_by_seed.csv`：正式 GA 结果。
- `run_checkpoints`：逐次结果、搜索历史以及可恢复检查点。

主要报告 2% LIM 误差达标率，同时保留 1%/5%、中位误差、P95、偏差方向和运行时间。
GA 时间包含原算法的搜索与积分，不包含前期诊断；报告总使用成本时须另计诊断。
automatic=1 是保留的原执行方式，tipo=2 可能包含原实现自动处理的未解析轨迹；不能由它直接推断误分类率。
`horizon_exhausted_proxy` 只是输出采样数诊断信号，不是真实未解析数量。
完整 GA 会复用历史网格标签，而独立点诊断每点从目标网格启动，因此点诊断通过不保证完整 GA 分类绝无错误。

这次实验检验：不读参考 LIM、不针对 cosine 重新优化 GA，继承的无量纲规则配合周期势所需的域解释，能否得到可靠且成本合理的设置。
通过也只能支持在此 alpha 和模型上的迁移，不代表所有二维模型均已得到证明；这里新增的周期势域分支须如实说明，不能称为原有双势阱域公式的原封不动验证。
