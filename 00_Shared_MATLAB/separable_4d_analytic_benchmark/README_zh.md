# 可分离四维解析 LIM benchmark

本测试把两个具有解析 LIM 的二次阻尼系统组成一个四维系统：

```text
quadratic-cubic: x'' + alpha_qc |x'| x' + x - x^2 = 0
bistable Duffing: y'' + alpha_bd |y'| y' - y + y^3 = 0
state: z = [x, x', y, y']
target: z_e = [0, 0, -1, 0]
```

两个子系统独立，因此完整吸引域是两个二维吸引域的笛卡尔积。在分块欧氏
距离下，四维目标到乘积吸引域边界的距离严格满足

```text
R_4D = min(R_quadratic_cubic, R_bistable_duffing).
```

默认参数为 `alpha_qc = 0.4` 和 `alpha_bd = 0.7`。解析参考只用于运行后的
评分，不参与三种搜索方法的选点或停止。

```text
R_QC = 0.647480159700422
R_BD = 0.728927859156115
R_4D = min(R_QC,R_BD) = 0.647480159700422
```

## 运行

先运行 `test_separable_4d_analytic_benchmark.m`。默认 pilot 使用 3 个 seed。
确认无系统性未决分类后，将 `runMode` 改为 `full`，使用 30 个 seed。

三种方法为：

1. `fixed_s3_radial_24`：固定 24 个四维方向；
2. `adaptive_s3_radial`：局部方向加密与全局最大未覆盖补点；
3. `adaptive_s3_with_trajectory_reuse`：在自适应方向方法上复用非目标轨迹的最近点。

三种方法共用同一模型、分类器、初始方向、径向精度、查询预算和 seed。

主要输出：

- `raw_data_all_runs.csv`：逐次结果及相对误差；
- `summary_by_method.csv`：准确性、成本、收敛和审计汇总；
- `paired_contrasts_by_seed.csv`：与固定方向法的配对成本及误差差异；
- `analytical_reference.csv`：两个二维解析 LIM 与严格四维 LIM；
- `reference_audit_*.csv`：解析公式的数值自检；
- `configuration.csv`：完整实验配置。
