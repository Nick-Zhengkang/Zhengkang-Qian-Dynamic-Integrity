三个二维模型全量复测：90 个案例，parfor 并行
2026-10-28

运行
在 MATLAB 中打开 START_ALL90_PARFOR.m，点击 Run。
需要 MATLAB R2025b 和 Parallel Computing Toolbox。
并行使用本机进程池，不使用线程池；各个任务有独立的工作目录状态、RNG 和缓存。
默认复用已打开的本机进程池；没有进程池时自动启动 parpool('Processes')。
options.numWorkers=[] 使用当前池或配置默认值，也可在尚未建池时填写 4 等数量。
若当前打开的是线程池，脚本会停止并提示，不会擅自关闭你的池。
确认线程池没有其他任务后，可手动执行：
  delete(gcp('nocreate'));
  parpool('Processes');
再运行本入口。
官方进程池说明：https://www.mathworks.com/help/parallel-computing/parpool.html

范围与调度
三个模型各运行原始 seed 1:30，包括原来未低估的 6 次运行，不只选失败案例。
quadratic_cubic：alpha=0.4
bistable_duffing：alpha=0.7
genda_cosine_quadratic_drag：alpha=0.05
默认每个模型/种子任务先跑原逻辑对照，再跑关闭负缓存版本，共 180 次完整搜索。
原逻辑对照不能复现历史结果时，该任务会跳过消融并保存错误。
parfor 只用于这些独立的模型/种子任务。单次自适应搜索和单条轨迹内部仍为顺序执行，
否则会改变查询顺序及标签传播机制，不再是同一实验。

唯一算法差异
消融副本删除 sampled_forward_step.m 中两条语句：
  if any(cellId==g.cell_d), kind=2; end
  if any(cellId==g.cell_dout), kind=3; end
保留目标标签复用、直接离域、重复访问、到积分时域末端仍未判定时的原处理规则。
保留负标签的写入与统计，但不再读取它们作分类。因此存储的负标签可以非零，
non_target_cache_hits 必须为零。
读取原 _settings.mat，alpha、网格、目标邻域、Ts、tfinal、ODE 容差、MaxStep、
随机种子、查询/方向预算、径向/角度策略、停止规则全部不改。
运行前校验 17 份复制源文件，除上述两行外与历史冻结源逐字节一致。
原始结果、原始源代码、已有 9 例诊断和论文均不修改。

本包重点是因果诊断，不用于评价运行速度。
原有 3600 秒时间上限仍保留，避免改变设置。如果并行资源竞争导致超时，
必须把它单列为截断运行，不能当作已完成的边界搜索。
相同随机种子绑定模型/种子任务，不绑定 worker 编号，所以并行调度顺序不会
决定随机角度。每次完整搜索均从新的缓存开始。

独立验证
每个消融搜索完成后，用 ode45 和 ode113 独立验证最终决定 LIM 的初始状态；
如仍低于参考，还验证首次造成低估的初始状态。
这一后处理不读取网格缓存，不在原域边界停止，不改变搜索结果，也不裁剪参考值。
它不能证明所有目标缓存标签都正确，或证明返回半径就是全局最小边界距离。
模型特定的能量势阱/逃逸判据用于区分 target、non_target 和 unresolved。
复核的最大时域是 2400 和 12000；满足能量条件时默认可在 t>=200 后提前停止，
逃逸则可在状态数值安全阈值处终止。报告时务必写实际结束时刻和停止原因，
不要把允许的最大时域写成每条轨迹实际积分的长度。

输出
results/<新时间戳>/：
  causal_summary.csv：各模型低估次数、独立复核、缺失/失败案例等因果诊断汇总
  comparison.csv：每次原值、对照值、新值、误差及独立复核结论
  all_results.csv：历史、原逻辑对照、消融三组明细
  case_status.csv：全部 90 个案例的状态，包含未完成/错误，不会偷偷删掉失败案例
  source_verification.csv：独立副本源代码差异检查
  ORIGINAL_DATA_INTEGRITY.txt：原实验存档运行前后的字节一致性
  original_files_before.csv / original_files_after.csv：原实验的 SHA-256
  run.log、environment.mat、selected_cases.csv、source_snapshot/

每个模型/种子子目录单独保存 MAT、查询轨迹历史、原因统计、独立积分图与记录，
以及 run.log、case_result.mat、case_status.csv。各 worker 不共同写一个 CSV。
所有 worker 完成后，客户端统一汇总。

若运行被中断，已保存的案例仍保留；并行停止后可以运行 REBUILD_SUMMARY.m，
从最新结果目录重新汇总已完成案例。它不重跑计算；缺失案例会标为 not_finished。
不要在 workers 仍在计算时运行恢复汇总。恢复汇总不替代未完成案例的计算。
运行结束后，请把本次整个时间戳文件夹压缩发回。

论文报告
本包的 REPORTING_GUIDE.txt 提供基于已完成 9 例的报告结构和英文草稿。
全量 90 次结果尚未产生；草稿不声称 90 次已经通过。
本轮不需要强调速度，不要把并行计时写成算法性能优势。

实现与测试状态
新增并行驱动、汇总和诊断代码由 AI 辅助实现，供作者审阅运行。
原 Habib 工具文件与冻结算法依赖保留原字节；只在独立消融副本删除两条读取语句。
交付前检查静态 MATLAB 语法、全部 90 份 MAT 的输入兼容性及源差异。
尚未在 MATLAB 中实际执行本并行版本；并行池启动与运行由作者在本机完成。
