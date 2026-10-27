# Habib 四维模型：自适应方向–径向方法测试

## 运行方法

在 MATLAB 中打开并运行：

`test_habib_4d_adaptive_radial.m`

修正方向预算后的专用 pilot 入口为：

`pilot_habib_4d_budget_fixed.m`

30个 seed、随机化执行顺序的正式入口为：

`run_habib_4d_full_30_seed.m`

入口脚本默认使用 `pilot` 模式，只运行 3 个 seed。确认输出中没有系统性的
`unresolved_classification` 后，再把 `runMode` 改成 `full`，运行 30 个 seed。

## 比较的三种方法

1. `fixed_s3_radial_24`：只使用同一组 24 个四维初始方向。
2. `adaptive_s3_radial`：围绕当前最小半径方向进行切空间加密，并在四维单位球面
   上补充最大未覆盖方向。
3. `adaptive_s3_with_trajectory_reuse`：在第二种方法基础上，把非目标轨迹经过的
   最近点重新转化为一个有已知非目标上界的新方向。

三种方法使用完全相同的模型、加权距离、轨迹分类器、径向容差和 seed。

## 四维选点定义

方向 `u` 是四维加权坐标中的单位向量：

`z0 = ze + r * W^(-1/2) * u,  ||u|| = 1`。

初始方向由 8 个正负坐标轴方向和 16 个四维超立方体角点组成，并对每个 seed
施加同一个随机正交旋转。径向上仍使用“向外扫描 + safe/non-target 区间二分”。

## 停止条件

自适应方法只有同时满足以下条件，才输出
`converged_local_and_global`：

- 已建立的每个有效边界区间都达到径向容差；
- 局部扰动角已缩小到 1 度，且连续两轮没有显著改进；
- 两批彼此独立的全局补点检查均没有显著降低 LIM；
- 没有未决轨迹分类。

预算耗尽、未决分类、没有找到边界和达到方向上限会分别记录，不能冒充收敛。
正式算法最多建立 200 条射线。该限制会在每次真正新增射线前检查，包含轨迹复用
派生的方向；停止后审计使用单独预算，不计入这200条射线。

## 停止后审计

自动停止得到的 `R_hat` 不包含审计预算。随后脚本另外加入 16 个最大未覆盖方向：

- `post_audit_pass = 1`：追加方向没有使 LIM 降低超过停止阈值；
- `post_audit_pass = 0`：停止可能过早，或审计因预算/未决分类不完整。

## 输出

- `raw_data_all_runs.csv`：每个 seed 和方法的结果、成本与停止状态。
- `summary_by_method.csv`：按方法汇总的 LIM、成本、未决率和审计通过率。
- `configuration.csv`：所有模型、分类与搜索参数，并区分论文值和实现控制量。
- `randomized_execution_schedule.csv`：90次运行的实际随机执行顺序。
- `paired_contrasts_by_seed.csv`：相同seed下，自适应方法相对固定方向的查询、积分和时间比。
- `run_details/*.mat`：每次运行的方向、径向区间和逐次分类记录。

`query_count`、`integration_count` 和 `algorithm_runtime_s` 只统计正式算法；
停止后审计的成本保存在独立的 `post_audit_*` 列中，不参与方法效率比较。

本测试是新的四维方法分支，不会修改已经冻结的二维 proposed method。
