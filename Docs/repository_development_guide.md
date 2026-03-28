# 仓库开发说明

本文档面向仓库内开发者，帮助快速理解 MB-SLAM-EvalToolkit 的代码组织、主入口、配置关系与常见开发路径。它不替代 README，而是补充“进入代码后怎么改、从哪里下手”。

## 1. 项目定位

MB-SLAM-EvalToolkit 是一个基于 MATLAB 的多波束 SLAM 评估与可视化工具箱。当前仓库的核心用途不是训练或部署，而是：

- 读取 `Data/` 下的轨迹与子地图数据；
- 运行 ATE / APE / CBEE / 误差时间序列 / 回环可视化等分析流程；
- 将图像、统计结果、MAT/CSV/TXT 等导出到 `Results/`。

因此，这个仓库更像“离线分析工具链”，而不是持续运行的应用程序。

## 2. 目录职责

### `Src/`
生产代码目录。所有 MATLAB 脚本和函数都在这里。

可按职责粗分为两类：

1. **入口脚本**：`main_*.m`
   - 负责加载配置、检查输入、调用核心函数、组织输出。
2. **实现函数**：其余 `.m`
   - 负责轨迹读取、误差计算、绘图、子地图处理、回环解析等具体逻辑。

### `Test/`
验证脚本目录。

这里不是统一的自动化测试框架，而是混合了：
- 可直接调用的函数式测试；
- 依赖本地数据集的脚本式验证。

因此，修改代码后需要按模块选择合适的验证脚本，而不是期待一个统一 test runner。

### `Data/`
输入数据目录。通常包括：
- `poses_original.txt`
- `poses_corrupted.txt`
- `poses_optimized.txt`
- `submaps/`
- 某些数据集下的 `loop_closures.txt`

### `Results/`
输出目录。多数工作流会创建时间戳目录或带时间戳文件名，把当前运行结果和历史结果隔离开。

### `Docs/`
模块级说明文档目录。适合查某个工作流的背景、输入输出和使用方式，但若文档与代码不一致，应以 `Src/` 里的现状为准。

## 3. 配置系统：先看 `Src/config.m`

`Src/config.m` 是整个仓库的统一配置入口，也是改动时最先应该检查的文件。

它负责集中定义：
- 输入数据路径；
- 输出目录；
- 图像尺寸、字体、颜色、导出格式；
- 模块级算法参数；
- 标签、图例、保存开关等。

当前主要配置段包括：
- `cfg.global`
- `cfg.ate`
- `cfg.ape`
- `cfg.cbee`
- `cfg.errorTimeSeries`
- `cfg.loop`

### 开发建议

如果你要改的是下面这些内容，优先改 `config.m`：
- 数据集路径；
- 输出路径；
- 图像导出格式、分辨率、尺寸；
- 模块参数；
- 曲线标签与颜色。

只有当工作流行为本身需要调整时，再修改对应的 `main_*.m` 或核心函数。

## 4. 主入口脚本与模块关系

仓库当前可以按六条主工作流理解。

### 4.1 ATE 主流程：`Src/main_calculateATE.m`

职责：
- 读取一个数据目录中的真值轨迹与估计轨迹；
- 执行轨迹对齐；
- 计算 ATE 统计量；
- 绘制轨迹图、时间序列图、直方图、CDF；
- 导出结果到 `Results/ATE/...`。

常见相关函数：
- `readTrajectory.m`
- `alignAndComputeATE.m`
- `plotTrajectories.m`
- `plotATEData.m`
- `saveTrajectoryData.m`

适合改动场景：
- ATE 指标或输出格式调整；
- 轨迹图风格修改；
- 结果导出内容调整。

### 4.2 APE 对比：`Src/main_plotAPE.m`

职责：
- 从 `cfg.ape.paths` 中读取 NESP / Comb 两组轨迹；
- 调用 `plotAPEComparison.m` 生成 XY 平面误差对比图。

适合改动场景：
- APE 对比图样式；
- 对齐开关与对比标签；
- 输入数据源切换。

### 4.3 ATE 分布对比：`Src/main_plotBoxViolin.m`

职责：
- 读取多个已导出的 ATE CSV；
- 使用 `plotATEDistributions.m` 绘制箱线图/小提琴图；
- 用于横向比较不同实验结果。

适合改动场景：
- 多组实验对比图风格；
- 标签布局；
- 对比文件列表来源。

### 4.4 CBEE 一致性误差评估：`Src/main_evaluateCBEE.m`

这是当前最重、最长的一条分析链。

职责：
- 加载配置并做严格校验；
- 按配置决定是否生成优化子地图；
- 加载所有子地图点云；
- 构建一致性误差栅格；
- 计算 RMS 一致性误差；
- 可视化误差图/高程图；
- 导出统计结果与图像。

核心相关函数：
- `setupParallelPool.m`
- `generateOptimizedSubmaps.m`
- `loadAllSubmaps.m`
- `buildCbeeErrorGrid.m`
- `computeRmsConsistencyError.m`
- `visualizeSubmaps.m`

### 为什么 CBEE 需要单独强调

因为它不只是“一个画图脚本”，而是完整流水线：
1. 子地图准备；
2. 坐标处理；
3. 栅格化；
4. 邻域误差计算；
5. 统计汇总；
6. 导出与可视化。

所以凡是改 CBEE，建议同时阅读：
- `main_evaluateCBEE.m`
- `buildCbeeErrorGrid.m`
- `computeRmsConsistencyError.m`
- `loadAllSubmaps.m`

不要只改入口脚本。

### 4.5 误差时间序列：`Src/main_errorTimeSeries.m`

职责：
- 读取 reference 与多个 benchmark 的轨迹配置；
- 动态校验输入路径（reference / benchmark / INS 来源）；
- 调用 `errorTimeSeries.m` 生成 ping 级误差表；
- 绘制时间序列曲线；
- 按配置决定是否导出 MAT 和图像。

支持结构：
- 1 个 reference 数据集（主算法）
- 多个 benchmark 数据集（对比组，可在 `config.m` 中动态扩展）
- 1 条可配置 INS 曲线，来源由 `ins.sourceDatasetId` 指定

核心思路：
- 先算子地图级误差（每个数据集只在自己的路径内计算，禁止跨数据集混用）；
- 再根据每个子地图包含的 ping 数，把误差展开成 ping 级样本；
- 最终形成 `pingErrorTable`（字段：`dataset / metric / submap_id / ping_idx / time_s / err_xy`）。

新增 benchmark 只需修改 `config.m`，不需要改主流程代码。

### 4.6 回环约束可视化：`Src/main_plotLoopClosures.m`

职责：
- 根据 `cfg.loop.paths` 读取位姿文件与 `loop_closures.txt`；
- 调用 `plotLoopClosures.m` 解析回环边；
- 绘制关键帧节点、里程计边、回环边；
- 按度数映射节点尺寸并导出高质量图像。

核心理解：
- 这条工作流本质上是“位姿图拓扑可视化”；
- 输入不是栅格或误差序列，而是**图结构**。

## 5. 典型数据流

虽然模块不同，但仓库多数工作流都遵循同一结构：

```text
config.m → main_*.m → 核心函数 → Results/
```

展开后通常是：

```text
读取配置
→ 校验输入路径/文件
→ 读取轨迹或子地图
→ 执行计算 / 对齐 / 栅格化 / 图构建
→ 生成图像与统计量
→ 导出到 Results
```

这个共同模式很重要，因为它决定了排查问题的顺序：
1. 配置对不对；
2. 输入文件在不在；
3. 中间函数算得对不对；
4. 最终导出是否按预期。

## 6. 常用开发入口

仓库没有单独的 build/lint 系统，常见开发动作就是运行对应的 MATLAB 工作流。

### 运行主流程

```powershell
matlab -batch "run('Src/main_calculateATE.m')"
matlab -batch "run('Src/main_plotAPE.m')"
matlab -batch "run('Src/main_plotBoxViolin.m')"
matlab -batch "run('Src/main_evaluateCBEE.m')"
matlab -batch "run('Src/main_errorTimeSeries.m')"
matlab -batch "run('Src/main_plotLoopClosures.m')"
```

### 运行单个测试/验证

函数式测试示例：

```powershell
matlab -batch "addpath(genpath('Src')); addpath('Test'); test_computeRmsConsistencyError"
```

脚本式验证示例：

```powershell
matlab -batch "run('Test/test_run_visualization.m')"
matlab -batch "run('Test/test_loadAllSubmaps.m')"
matlab -batch "run('Test/test_generateOptimizedSubmaps.m')"
matlab -batch "run('Test/test_buildCbeeErrorGrid.m')"
matlab -batch "run('Test/test_run_cbee_evaluation.m')"
```

## 7. 测试与验证策略

### 当前现实

这个仓库的 `Test/` 不是统一自动化测试体系，而是“函数测试 + 手工验证脚本”混合结构。

因此，比较可靠的验证策略是：
1. 运行你修改模块对应的 `main_*.m`；
2. 再运行最接近的 `Test/` 脚本或测试函数；
3. 检查它是否依赖你本地存在的数据样例。

### 特别注意

部分旧测试脚本看起来仍保留较早期的配置结构假设，因此：
- 不要盲目把它们当作权威真相；
- 如果测试脚本和当前 `config.m` 不一致，应优先信任生产代码当前结构，再判断是否需要同步修测试。

## 8. 修改建议

### 改配置类问题
先看：`Src/config.m`

### 改某个工作流行为
先看对应的 `Src/main_*.m`

### 改算法/核心逻辑
继续往下读该入口脚本调用的函数

### 改图像风格或导出行为
先看：
- `cfg.global.visual`
- `cfg.global.save`
- 对应模块的 `plot*.m`

### 改结果组织方式
先看入口脚本里对 `Results/...` 的目录创建与时间戳命名逻辑

## 9. 开发时的边界意识

在这个仓库里，建议始终区分三类内容：

1. **原始输入**：`Data/`
2. **生产代码**：`Src/`
3. **生成结果**：`Results/`

不要把分析生成物回写到 `Data/`，也不要把临时实验结果误当成仓库源码的一部分。

## 10. 推荐阅读顺序

如果你第一次接手这个仓库，推荐顺序是：

1. `README.md`
2. `Src/config.m`
3. 你当前要改的那个 `Src/main_*.m`
4. 该脚本调用的核心函数
5. `Docs/` 中对应模块文档
6. `Test/` 中与该模块最相关的脚本或测试函数

这样能最快建立“配置 → 入口 → 实现 → 验证”的完整链路。
