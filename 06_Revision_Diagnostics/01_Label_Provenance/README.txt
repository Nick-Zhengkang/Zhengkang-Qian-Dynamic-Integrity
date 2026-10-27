LIM 二维偏小问题：独立 MATLAB 诊断包
准备日期：2026-10-28

一、如何运行

1. 在 MATLAB 中打开本文件夹内的 START_DIAGNOSTICS.m，点击 Run。
2. 如 MATLAB 询问工作文件夹，请选 Change Folder。
3. 原实验路径已填写好。如果你移动了原实验文件夹，只改 opts.dataDirectory。
4. 等命令窗口出现 Finished diagnostics，随后完成原文件完整性检查。
5. 输出保存在本文件夹 results 下的新时间戳目录中，不覆盖上次结果。

不需要下载额外 MATLAB 工具箱。建议使用原实验版本 MATLAB R2025b，
需要 MATLAB 的 JVM（用于原文件 SHA-256 校验）。不需要 Python。
脚本读取电脑上现有的原实验存档，不把原始 MAT 文件复制进诊断包。

二、默认检查哪些运行

先读取三个模型全部 90 次 proposed 运行，核对：
- 最终 LIM 是否等于所有 non-target 查询的最小初始半径；
- 查询初始状态、目标和权重是否能重建相同距离；
- 对应的解析参考值、随机种子、关键查询编号及原分类原因。

随后每个模型默认重放 3 个低估案例：偏小最多、中间、偏小最少。
根据当前原始记录，这 9 个种子为：
- quadratic_cubic：19、12、7（alpha = 0.4）
- bistable_duffing：30、1、17（alpha = 0.7）
- genda_cosine_quadratic_drag：12、26、27（alpha = 0.05）

如需检查全部低估运行，将入口中的 opts.selection 改为
"all_underestimated"。耗时会明显增加，建议先运行默认 9 个案例。

三、脚本具体做什么

A. 顺序重放历史查询
使用原实验保存的 source_snapshot、模型及参数，从空缓存/原始目标网格开始，
依次重放已保存的查询初始状态。它不是重新运行随机选点或重新比较算法速度。
必须保持原查询顺序，因为后面的分类可能依赖前面的网格标签。

对每次查询记录终止点、终止网格、分类原因、标签最早写入者、
写入者进入该网格的具体轨迹状态，以及网格物理边界。
复现原有 stable-unique 后再删最后一个唯一网格的传播规则，不在诊断中修复它。

如果标签、采样数量、缓存类型、关键最小距离/状态等与原记录不一致，
停止该案例的标签因果分析，保存差异，继续下一个案例。
RHS 调用次数也会比较并记录，但单独的次数差异不作为停止条件。

B. 追踪两条标签来源链
- 最终决定 LIM 的 non-target 查询。
- 首次使半径低于参考值的 non-target 查询。
沿最早写入标签的查询反向追踪，直到不再依赖已有缓存的直接分类。

C. 独立积分复核
沿两条来源链检查每个查询的初始状态；若涉及缓存，还检查：
- 当前轨迹命中网格时的状态（cache_hit_state）；
- 最早给该网格写入标签的轨迹状态（first_writer_state）。

使用独立写出的模型方程，并在测试状态上检查其与原 sistema 一致。
分别用 ode45 和 ode113，更严格的误差容限、更长的最大积分时域复核。
不读取学习到的网格标签，不使用原重复访问规则，也不在原计算域边界停止。

两次最大积分时域为原时域的 2 倍和 10 倍，即 2400、12000。
默认至少积分到 t=200；之后如果轨迹能量低于相应势垒并确定所在势阱，
可以提前停止。因此 actual_end_time 可能小于 requested_horizon。
opts.stopAtEnergyCertificate=false 可关闭能量提前停止。
MaxStep 分别为 0.2、0.1，RelTol 为 1e-10、1e-12，AbsTol 为 1e-12、1e-13。
与原分类重放不同，独立积分不依赖 Ts 采样。不能仅以 MaxStep 比较精度，
需要结合两求解器、误差容限、能量变化和最终物理判据一起检查。

这些模型满足 E'= -alpha*abs(v)^3，alpha>0。
仅在能量低于势垒且所在势阱明确时，才用能量条件支持吸引子判断。
quadratic-cubic 的 x>1 且 v>=0 还提供一个前向不变的逃逸区域判据。
无法满足充分条件就保留 unresolved，不把超时自动当作 non-target。
独立积分在 max(abs([x,v]))=50 处有数值安全停止，单独触发该停止并不能
证明非目标；仍需物理判据支持。能量判断基于数值解，不是区间算术严格证明。

四、主要输出

results/<时间戳>/
  all_90_runs_decisive_points.csv：全部 90 次结果、关键状态和参考值
  selected_cases.csv：实际重放的模型与种子
  case_status.csv：各案例成功/重放不一致/错误状态
  run.log：运行日志
  ORIGINAL_DATA_INTEGRITY.txt：运行前后原始文件字节是否完全一致
  original_files_before.csv / original_files_after.csv：SHA-256 清单

每个模型/种子子目录中：
  query_provenance.csv：全部重放查询及标签来源
  winning_label_chain.csv：最终 LIM 对应的标签传播链
  first_under_label_chain.csv：首次低于参考值时的传播链
  replay_details.mat：重放记录及保留的关键轨迹
  independent_test_points.csv：独立复核的具体状态
  independent_validation.csv：两种求解器的物理判据、终止时间和结果
  independent_assessment.csv：两种求解器是否一致支持目标/非目标
  independent_trajectories.mat：独立积分的采样轨迹
  winning_query_*.png：最终关键查询的轨迹、距离与能量图
  validation_scope.txt：复核范围及是否被人为限制
  ERROR.txt：仅发生错误时生成

轨迹 MAT/PNG 保存的是对求解器连续解的采样，不是全部内部积分步。
first_sampled_original_exit_time 是采样检测值，不能当作精确越界时间。

五、如何解释结果

先看 case_status.csv。只有 replay_matches 的案例才可分析标签来源。
再看独立判断是否支持原查询实际会回到目标。
若当前命中状态支持回到目标，而同格最早写入状态支持非目标，
说明该格内两点的真实结局不同，提示网格标签的空间泛化问题。
若最早写入状态也支持回到目标，应沿来源链继续查更早的错误判定。
直接离开计算域后能回到目标，则提示“离开计算域=非目标”的判据不适用。
这些是待验证的解释路线，不是脚本预先认定的原因。
若两种求解器不一致、证据不足或链条不完整，就不能下确定结论。

六、原文件保护与测试状态

本包仅新增诊断脚本与结果，原实验代码、原始数据和论文均不修改。
运行前后计算原实验存档所有文件的 SHA-256；核对结果写入独立输出目录。
诊断脚本由 AI 辅助编写，供作者核对和执行，不替换论文中的原实验结果。
已用 MATLAB 语法解析器检查，并只读核对了 90 份 MAT 的字段与半径关系。
由于本机 MATLAB 启动时遇到许可服务错误 5201，尚未完成 MATLAB 实际运行测试。

运行完成后，把本次 results 下的整个时间戳文件夹压缩发回即可。
不需要重复发送原实验数据。如果报错，请保留 ERROR.txt 和 run.log，
先不要修改原实验代码或数据。
