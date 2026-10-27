Quadratic-cubic / seed 30 / query 567：重复访问判据只读诊断
2026-10-28

如何运行
在 MATLAB 中打开 START_QUERY567_DIAGNOSTIC.m，点击 Run。
原始全量复测结果路径已填入 options.sourceResults；原实验存档路径也已填好。
只在移动这些输入文件夹时修改路径，不要更改原参数。
输出保存在本包 results/<新时间戳>/，每次单独建目录。
建议使用 MATLAB R2025b，需要 JVM 用于 SHA-256；不需要额外工具箱。

本次没有更改算法
engine、native、model 中的 7 份文件直接复制自已完成的 90 次复测快照。
运行时逐字节检查它们与该快照完全相同，包括原本关闭负标签读取的状态。
repFixPoint、repPeriodic、网格、Ts、ODE 设置及目标缓存逻辑全部不改。
所有新增代码都在诊断驱动或离线记录器中，不插入原积分回调或修改原判据。

为什么这一次顺序重放，而不是 parfor
90 次复测的模型/种子之间独立，所以可以 parfor。
这一次需要重建同一次运行的正标签缓存，查询 2 依赖查询 1 的缓存，后续依此类推。
因此必须按历史顺序重放查询 1 到 567，不能将这些查询当成独立并行任务。
本包不重新运行自适应选点，只重放已保存的初始状态。

诊断流程
1. 校验复测快照副本与输入文件完整性。
2. 用原分类器顺序重放查询 1:567，逐条核对标签、原因、原始 kind、采样数、
   RHS 调用次数、最小距离和对应状态等。重放不一致就停止，不猜测原因。
3. 取得查询 567 开始之前的完整缓存，用未改动的原积分器提取其精确采样轨迹。
4. 在已保存的这些采样点上，离线计算两个判据的计数。
   每一步再调用未改动的原 step 函数核对，确保离线解释与实际判定一致。
5. 给出真正执行的分支，以及触发时刻、状态、网格、访问历史与阈值比较。

计数必须这样理解
prior = find(cellId == previousCells)，只包含当前采样点之前的历史。
当前采样点本身不计入 prior。

固定点分支：
  nnz(diff(prior)==1) > repFixPoint
它统计所有历史访问中的相邻样本间隔数，并不天然等同于“当前连续停留次数”。
本包单独输出 current_streak_including_current，避免把两者混淆。

周期分支：
  numel(prior)>repPeriodic+1 && prior(end)~=count-1
满足此门槛后，再检查：
  nnz(diff(prior)~=1) > repPeriodic

固定点分支位于 if，周期分支位于 elseif。
即使两套数学条件同时成立，实际也优先执行固定点分支。
因此输出同时区分“条件在数值上成立”和“代码是否真正执行了该条件”。
严格大于号 > 也保持原样，不改成 >=。

重点返回哪些文件
diagnostic_status.csv：只有 reproduced=1 且 diagnosis_available=1 才可解读结论。
TRIGGER_EXPLANATION.txt：实际执行 rep_fix_point 还是 rep_periodic，以及数值依据。
trigger_summary.csv：触发时刻、网格边界、状态、两种计数及实际分支。
sample_audit.csv：查询 567 的所有分类采样点及计数。
trigger_cell_visits.csv：触发网格的全部访问，包括是否进入触发条件的历史集合。
trigger_history_gaps.csv：每个相邻历史访问间隔贡献给哪种计数。
trigger_cell_episodes.csv：对该网格的连续停留段。
trigger_cell_counter_history.csv：触发网格在各次访问时的计数变化。
query567_native_trajectory.csv / .mat：原采样轨迹、网格及查询前缓存。
replay_checks.csv：查询 1:567 与原记录的逐次一致性检查。
observer_tests.csv：阈值等号、严格越界、累计计数及分支优先级的 6 个小测试。
source_verification.csv：7 个算法文件逐字节一致性检查。
INPUT_INTEGRITY.txt：90 次结果目录和原实验存档前后是否完全不变。
ERROR.txt：仅发生错误时生成。

previous_independent_validation.csv 是之前已完成的独立积分记录副本，只用于上下文。
本包不重新跑长时域验证，也不根据验证结果修正原标签。
本次任务只确认误判由哪个重复访问分支、什么样的访问计数触发。
如何修改判据，是得到这些证据之后的下一步，不在本包里执行。

运行完成后，将本次 results 下整个时间戳文件夹发回即可。
原 90 次结果、原论文实验代码和数据均只读，不覆盖；也不会上传 GitHub。

新增诊断代码由 AI 辅助编写，供作者核对执行。
交付前完成静态 MATLAB 语法、复制文件一致性和输入结构检查。
本包尚未实际在 MATLAB 中执行，不能提前声称已确认触发的是哪个分支。
