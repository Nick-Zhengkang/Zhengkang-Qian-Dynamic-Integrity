# 固定初始搜索半径的完整 GA 对照

在 MATLAB 打开 test_experiment_C_anchored_GA.m，按 Run。

读取 outputs_search_domain_closure_20260924_042002_735 中已经验证的计算域。
不重新生成或调优计算域。原始 DynIn 函数按本次启动时的源码快照调用。

## 实验设置

- alpha=[0.2,0.7,1.0]；seed=61:90；每次100条轨迹，总共180次完整运行。
- original_domain 对比 anchored_search_energy。
- 两组 R0 均约0.897056，物理网格宽度、目标邻域、时间参数和全部 GA 参数一致。
- 新域 discr=1261，原始域 discr=677；格数不同是为了扩域时保持物理分辨率。
- 启动前严格检查除 domain/discr 外的模型和分类参数逐字段相同。
- 每个配对使用相同算法 seed。两组初始点应相同，后续自适应查询可因分类分歧而不同。
- 随机化运行顺序，两组均重新运行，运行时间不复用历史结果。
- 主阈值2%，同时报告1%与5%，参考 LIM 仅用于结果评分。

61:90 与上一轮重复，是有意的同 seed 改版对照。不能称作全新独立 seed 验证。
本轮继续固定100条轨迹，不是达到目标精度即停的耗时实验。

## 运行和恢复

每次运行显示 [run i/180] START/DONE，保存 MAT 检查点、逐步历史及 raw CSV。
中断后把新输出目录填入 resumeDir，再 Run。最后未完成的一次会重跑。
prepareOnly=true 可以只冻结输入、验证设置并生成调度；之后设为 false，并把
同一输出目录填入 resumeDir 即可开始计算。入口脚本不参与源码锁定，因此修改
resumeDir 不会阻止恢复。修改其他参数或计算函数后应使用新输出目录。

已完成但失败的运行也保留并计入失败数，恢复时不会自动悄悄重试。

## 输出

- matched_settings_audit.csv：域、网格、能量上界、半径和分类参数的配对审计。
- raw_data_all_runs.csv：每次运行的误差、运行时间、tipo3、查询能量和半径等。
- summary_by_alpha_and_domain.csv：三组阻尼分别汇总，alpha=NaN 行为总体汇总。
- paired_contrasts_by_seed.csv：同 seed 的差值与第一个初始点一致性检查。
- paired_contrast_summary.csv：成对变化汇总，同时列出含/不含计时异常的时间比。
- run_checkpoints/*_history.csv：每一步初始点、查询半径、能量、LIM、分类和耗时。

## 判断结果

先看所有配对第一个初始点是否相同，再检查新域有没有 tipo3。
新域出现 tipo3 会被标记为 domain_coverage_violation，保留结果供定位。
tipo3 可来自实际越界或命中已标记越界单元，不等同于已确认的 false-unsafe。
若查询半径/能量违反冻结的搜索范围，运行标为 search_contract_violation。

随后比较 LIM 误差、2%达标率、正负偏差和配对耗时。重点关注 alpha=0.7/1.0
的低估是否消失，以及 alpha=0.2 是否避免旧对称扩域后的精度下降。

保留原实现 automatic=1：未解析轨迹会在核心函数中转为 tipo2。
输出 n_tipo2_after_automatic 不能解释为全部已确认非目标。
horizon_exhausted_proxy 只用于提醒检查时长，不是准确的未解析计数。
覆盖审计通过不等于分类准确性已经验证，本轮也不输出未经测量的 FSR/FUR。
