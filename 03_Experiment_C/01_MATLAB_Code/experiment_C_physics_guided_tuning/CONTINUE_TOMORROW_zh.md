# 实验 C 续作检查点

更新时间：2026-09-23

## 当前研究目标

为二维模型建立可迁移的 DynIn GA 超参数调节规则：先由模型物理特征生成初始设置，再依据分类诊断信号决定调整哪个参数。目标不是寻找一组适用于所有模型的固定参数。

## 最近完成的实验

计算域诊断已经完成：

`outputs_domain_diagnostics_20260923_041604_919`

主要文件：

- `summary_domain_diagnostics.csv`
- `pointwise_comparison.csv`
- `domain_geometry.csv`
- `domain_decisions.csv`

## 已确认的主要结果

- 原始计算域在 alpha = 0.2、0.7、1.0 时都产生 false-unsafe，原因是目标轨迹暂时离开计算域后又返回目标。
- 保持物理网格宽度、目标邻域、积分时间和分类规则不变，仅按能量包络扩大计算域后，三种阻尼的 calibration 和 holdout 误分类均降为 0。
- 轨迹包络扩域在 alpha = 0.2 和 1.0 的 holdout 中各残留 1 个 domain-exit false-unsafe；alpha = 0.7 全部修复。
- 因为网格宽度和目标邻域物理尺寸保持不变，这组结果支持：误差来源是计算域不足，而不是网格变粗或目标邻域改变。
- 当前只是固定诊断点上的分类验证，尚未重跑完整 GA，也没有完成新的独立验证，因此不能直接声称 LIM 误差已经满足 2%。

## 明天继续的第一步

1. 在 `pointwise_comparison.csv` 中定位轨迹包络仍然失败的两个 holdout 点，检查其初始能量是否超过 calibration 的最大能量。
2. 审核 alpha = 0.2 的异常长计时，避免把暂停或系统状态误认为算法成本。
3. 将能量包络规则冻结为计算域候选规则，并生成全新的独立诊断点进行验证。
4. 独立分类验证通过后，再设计完整 DynIn GA 对照：原始域与物理扩域使用相同 seeds、相同搜索预算，并明确报告扩大计算域会同时改变 GA 初始搜索球这一影响。

## 继续方式

重新开机后打开当前 Codex 任务并输入：

`继续实验 C，从 OneDrive 备份里的 CONTINUE_TOMORROW_zh.md 开始。`

