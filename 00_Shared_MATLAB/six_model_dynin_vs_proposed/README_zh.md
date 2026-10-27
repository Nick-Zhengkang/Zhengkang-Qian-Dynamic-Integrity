# 六模型：DynIn GA 与自适应角度 proposed method

入口：`test_six_model_dynin_vs_proposed.m`。

## 比较方法

1. `dynin_original_ga`：直接调用未改动的 DynIn v1.1.0
   `compute_LIM_FP`，使用 `type_x0=1` 纯 GA 选点分支。该原始文件不包含
   后来试验过的自适应网格或边界二分扩展。
2. `proposed_adaptive_angle`：二维使用冻结的 adaptive-angle v1；四维使用
   S3 局部加密加全局最大未覆盖补点，不启用路径复用。

两种方法保留各自完整分类和停止机制。结果同时报告误差、轨迹积分次数和算法
运行时间，不把“运行更快但未达到精度”解释为更高效。

## 六个模型

- quadratic-cubic，`alpha=0.4`，解析 LIM；
- bistable Duffing，`alpha=0.7`，解析 LIM；
- Habib unforced Duffing，`zeta=0.05`，论文数值 LIM；
- Genda cosine potential，`alpha=0.05`，解析 LIM；
- Habib Duffing-van der Pol + NLTVA/TMD，`mu1=0.075`，论文数值 LIM；
- separable QC x BD 4D benchmark，严格解析 LIM。

## 输出

- `raw_data_all_runs.csv`：逐模型、逐方法、逐 seed 数据；
- `summary_by_model_and_method.csv`：准确性、成本和成功率；
- `paired_contrasts_proposed_vs_dynin.csv`：同模型同 seed 配对差异；
- `benchmark_references.csv`：参考值及来源；
- `dynin_configurations.csv`：各模型实际 DynIn 参数；
- `child_output_manifest.csv`：两个四维 proposed 子实验的位置。

默认 pilot 使用3个 seed。确认所有模型无系统性失败后再运行30-seed full。
