关闭非目标网格标签复用：9 个案例的配对复测
2026-10-28

运行方法
在 MATLAB 中打开本文件夹的 START_RETEST.m，点击 Run。
如提示切换工作文件夹，选 Change Folder。
原实验目录已经填写。如果原实验文件移动了，只修改 options.dataDirectory。
不需要 Python，不需要额外 MATLAB 工具箱。建议使用 MATLAB R2025b。
需要 JVM 来进行文件 SHA-256 校验。

本次修改的唯一算法因素
在独立副本 sampled_forward_step.m 中，删除以下两条缓存读取语句：
  if any(cellId==g.cell_d), kind=2; end
  if any(cellId==g.cell_dout), kind=3; end

也就是不再仅因命中“已知非目标网格”或“已知离域网格”就终止并判为非目标。
目标网格标签仍可复用。直接越过计算域、重复访问判据、到时限后强制非目标的
原规则也都保留。本次不同时修复其他分类规则。

为保证只改变一个因素，非目标标签的写入和统计仍然保留，但不会再读取用于
分类。因此 cached_exit_cells 等存储数量可以非零，而 non_target_cache_hits
必须为零。这不代表开关失效。

其他设置
读取原 _settings.mat 的 problem、proposedClassifier、proposedSearch、dynin。
alpha、目标、权重、计算域、网格、目标邻域、Ts、积分时域、ODE 容差、MaxStep、
重复访问阈值、初始角度数量、局部加密/全局补查、径向容差、查询预算、方向预算、
时间上限和停止规则全部保持原值。只把模型文件路径定位到本包的只读副本。
使用每个原运行保存的 algorithm_seed，不重新编造随机种子。

检查的 9 个案例
quadratic_cubic：seed 19、12、7
bistable_duffing：seed 30、1、17
genda_cosine_quadratic_drag：seed 12、26、27

默认流程：9 个案例，每例原逻辑对照 + 关闭复用，共 18 次完整搜索。
1. 校验副本源代码。除上述两行外，全部算法依赖必须与原存档逐字节一致。
2. 执行轻量逻辑测试，检查目标标签、直接离域和重复访问判据保持不变。
3. 用原逻辑和原随机种子重新搜索，与历史记录比较最终半径、查询数量、
   查询位置、分类、采样数、关键轨迹状态及停止原因（不要求运行时间相等）。
   对照不一致时，保存记录并跳过该案例的消融，不混用不匹配的对照。
4. 从全新缓存开始，用相同种子运行关闭非目标标签复用的完整自适应搜索。
5. 保存新结果，与历史值和本机对照比较。
6. 默认在搜索结束后，独立复核新结果的关键初始状态。

这是完整搜索，不是重放旧查询。关闭缓存后分类可能改变，后续查询位置、
方向数量和停止时刻也可能随之变化；这是同一策略对新分类结果的响应，
不表示修改了选点策略或搜索预算。

如只想跑 9 次消融，可以把 options.runBaselineControl 改为 false。
建议首次保持 true，先确认本机完整对照能复现历史结果。

独立复核说明
独立复核在计时搜索完成之后进行，不向搜索提供结果、不更新返回的 LIM，
不使用解析参考值裁剪估计。它只验证最终决定 LIM 的 non-target 查询；
若仍低于参考值，还验证首次低于参考值的 non-target 查询。
该步骤不重新追踪新运行的目标缓存来源链。

使用 ode45 和 ode113，不读取网格缓存、不在原计算域边界停止，采用更严格的
误差容限与能量势阱判据。默认至少积分到 t=200 后可在能量条件成立时提前停止。
无法得到足够证据时保留 unresolved。具体设置在入口脚本中。
这些复核参数只属于后处理，绝不会替换计时搜索使用的原积分参数。

输出位置
本包 results/<新时间戳>/，每次运行建立新目录，不覆盖之前结果。

主要文件：
  comparison.csv：每个案例的原 LIM、新 LIM、误差、成本、停止状态和独立复核
  all_results.csv：历史记录、原逻辑对照、消融三组明细
  case_status.csv：每个案例完成/错误及发生阶段
  source_verification.csv：副本与原存档的逐文件一致性检查
  ORIGINAL_DATA_INTEGRITY.txt：原始文件前后字节是否完全一致
  original_files_before.csv / original_files_after.csv：原存档 SHA-256 清单
  run.log：运行日志
  source_snapshot/：本次实际使用的独立代码副本和诊断脚本

每个模型/种子子目录：
  effective_settings.mat：实际使用的参数
  baseline_control.mat、baseline_control_queries.csv：本机原逻辑对照
  baseline_reproduction_checks.csv：与历史记录一致性的检查
  no_negative_reuse.mat：新搜索的完整输出和逐查询记录
  no_negative_reuse_queries.csv、no_negative_reuse_history.csv：查询与收敛历史
  no_negative_reuse_reason_counts.csv：新分类原因统计
  independent_postcheck/：新关键状态的独立积分结果和图
  ERROR.txt：仅发生错误时生成

解释结果时注意
- 关闭负标签复用后，积分工作量可能上升。时间上限仍保持原值，可能触发 time_budget。
  时间截断、未收敛或 unresolved 必须单独说明，不能当作收敛结果。
- 本机原逻辑对照的时间比历史耗时更可比，但固定先对照后消融的顺序不构成
  完整性能评测。优先结合 RHS 次数、查询数和停止条件分析。
- 新结果接近解析值，不自动证明分类可靠；还要看独立复核。
- 保留目标缓存、重复访问和超时判据，因此本次只检查负缓存复用这一因素。
- 本包不会覆盖原实验结果，也不会修改论文或上传 GitHub。

测试状态与来源
新增诊断驱动、测试及独立复核代码由 AI 辅助编写，供作者审阅和运行。
基线和共享文件来自原实验冻结快照，Habib 原始工具文件保持原字节，不改署名。
消融副本只有两条负缓存读取语句被移除，并添加了说明注释。
交付前已做静态语法检查、依赖/源差异核对和 9 个历史 MAT 的输入兼容性检查。
本包尚未实际完成 MATLAB 运行测试，由作者在本机执行。

运行结束后，把这次 results 下整个时间戳文件夹压缩发回即可。
有错误也请保留输出，先不要修改原实验代码或原始数据。
