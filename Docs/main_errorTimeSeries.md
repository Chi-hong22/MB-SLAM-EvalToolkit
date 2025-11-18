# `errorTimeSeries` 模块文档

## 1. 模块概述

`errorTimeSeries` 模块用于将 Comb 与 NESP 两套离线 SLAM 结果转成“时间 vs XY 平面误差”曲线，并导出统一的 `ping_error.mat`（文件名可在配置中改，变量名固定为 `pingErrorTable`）。整体设计遵循 [在线定位误差评估方案](https://raw.githubusercontent.com/Chi-hong22/bathymetric_slam/feature/NESP_online-rewrite/docs/online_error_plan.md) 的“按子地图均匀展开误差”思想，但实现保持离线批处理，输入仅依赖 `poses_*.txt` 与对应子地图点云。

### 文件结构（脚本 + 函数）

- `Src/main_errorTimeSeries.m`（脚本）：入口脚本。负责加载 `config.m`、检查路径、调用核心函数生成数据，并在脚本内部的辅助函数中完成时间序列绘图/导出；同时按照 `cfg.global.save.timestamp` 自动创建时间戳子目录，隔离每次运行的输出。
- `Src/errorTimeSeries.m`（函数）：核心数据函数，导出为
  ```matlab
  function pingErrorTable = errorTimeSeries(cfg)
  ```
  仅负责读取轨迹、展开误差并保存 `ping_error.mat`，返回 `pingErrorTable` 供上层脚本使用。

### 输出曲线

- **INS**：Comb 数据集中 `poses_corrupted` vs `poses_original` 的误差。
- **Comb**：Comb 数据集中 `poses_optimized` vs `poses_original` 的误差。
- **NESP**：NESP 数据集中 `poses_optimized` vs `poses_original` 的误差。

每条曲线都按子地图 ping 数平均展开，横轴由 `ping_idx * cfg.errorTimeSeries.pingDt` 得到时间。

## 2. 输入数据与配置

### 2.1 轨迹文件

| 数据集 | 轨迹 | 配置字段 |
| --- | --- | --- |
| Comb | `poses_original.txt`（真值）、`poses_corrupted.txt`（INS）、`poses_optimized.txt`（SLAM） | `cfg.errorTimeSeries.comb.originalPath`, `cfg.errorTimeSeries.comb.insPath`, `cfg.errorTimeSeries.comb.slamPath` |
| NESP | `poses_original.txt`（真值）、`poses_optimized.txt`（SLAM） | `cfg.errorTimeSeries.nesp.originalPath`, `cfg.errorTimeSeries.nesp.slamPath` |

> 建议使用 `fullfile` 与数据根目录组合路径，保持与 ATE/APE 入口脚本相同的可读性。

### 2.2 子地图与 ping 计数

子地图均为 ASCII PCD/PDC，需解析头部字段：

- `WIDTH` 或 `POINTS`：子地图包含的点 / ping 数。
- `DATA`：用来定位正文开始位置（无需加载整个点云）。

配置示例：

```matlab
cfg.errorTimeSeries.comb.submapDir = fullfile(DATASET_ROOT, 'Comb', 'submaps');
cfg.errorTimeSeries.nesp.submapDir = fullfile(DATASET_ROOT, 'NESP', 'submaps');
cfg.errorTimeSeries.submapExtList  = {'.pcd', '.pdc'};
```

### 2.3 时间与可视化参数

- `cfg.errorTimeSeries.pingDt`: 统一的 per-ping 时间间隔（例如 1.0 s）。若未来需要区分 Comb/NESP，可在配置内显式声明 `combPingDt`、`nespPingDt`，但默认值保持一致。
- 三条曲线统一命名为 `INS` / `Comb` / `NESP`。
- 可视化参数继承全局设置：`errorTimeSeries.vis.curves.*` 默认直接引用 `cfg.global.visual` 的三条线样式（类似 `cfg.global.visual.est_color` 的写法），在此基础上可按需覆写：

```matlab
cfg.errorTimeSeries.vis.curves = struct();
cfg.errorTimeSeries.vis.curves.INS  = struct( ...
    'color',     cfg.global.visual.corrupted_color, ...
    'lineStyle', cfg.global.visual.corrupted_line_style, ...
    'lineWidth', cfg.global.visual.corrupted_line_width);
cfg.errorTimeSeries.vis.curves.Comb = struct( ...
    'color',     cfg.global.visual.optimized_color, ...
    'lineStyle', cfg.global.visual.optimized_line_style, ...
    'lineWidth', cfg.global.visual.optimized_line_width);
cfg.errorTimeSeries.vis.curves.NESP = struct( ...
    'color',     cfg.global.visual.gt_color, ...
    'lineStyle', cfg.global.visual.gt_line_style, ...
    'lineWidth', cfg.global.visual.gt_line_width);

cfg.errorTimeSeries.vis.axes = struct( ...
    'xlabel', 'Time (s)', ...
    'ylabel', 'XY Error (m)', ...
    'ylim',   [0 50]);
```

- 导出格式、分辨率、文件命名全部沿用 `cfg.global.save`。`errorTimeSeries` 只读取这些参数，不在脚本内重复设置；与 `plotATEDistributions`、`plotAPEComparison` 的行为一致。

### 2.4 `config.m` 修改清单（驼峰命名）

在 `config()` 中新增如下结构，写法与现有模块保持一致（段落注释、缩进、字段命名全部使用 CamelCase）：

```matlab
cfg.errorTimeSeries = struct();
cfg.errorTimeSeries.enable     = true;
cfg.errorTimeSeries.pingDt     = 1.0;
cfg.errorTimeSeries.outputDir  = 'Results/ErrorTimeSeries';
cfg.errorTimeSeries.outputMat  = fullfile(cfg.errorTimeSeries.outputDir, 'ping_error.mat');
cfg.errorTimeSeries.savePlot   = true;
cfg.errorTimeSeries.truncateToCommonRange = true;

cfg.errorTimeSeries.comb = struct( ...
    'originalPath', 'Data/250911_Comb_noINS/.../poses_original.txt', ...
    'insPath',      'Data/250911_Comb_noINS/.../poses_corrupted.txt', ...
    'slamPath',     'Data/250911_Comb_noINS/.../poses_optimized.txt', ...
    'submapDir',    'Data/250911_Comb_noINS/submaps');

cfg.errorTimeSeries.nesp = struct( ...
    'originalPath', 'Data/250911_NESP_noINS/.../poses_original.txt', ...
    'slamPath',     'Data/250911_NESP_noINS/.../poses_optimized.txt', ...
    'submapDir',    'Data/250911_NESP_noINS/submaps');

cfg.errorTimeSeries.submapExtList = {'.pcd', '.pdc'};
```

## 3. 数据处理流程

1. **加载配置**  
   `cfg = config();`，脚本 `main_errorTimeSeries` 将 `cfg` 传入同名函数。

2. **读取轨迹**  
   函数内部调用 `readTrajectory` 读取 `poses_original / poses_corrupted / poses_optimized`，并按子地图顺序对齐。

3. **计算子地图误差**  
   - `INS`: `poses_corrupted - poses_original`  
   - `Comb`: `poses_optimized - poses_original`（Comb 数据集）  
   - `NESP`: `poses_optimized - poses_original`（NESP 数据集）  
   保存 `submapId`、`err_xy`、`poseIdx` 等属性。

4. **解析子地图 ping 数**  
   `parsePcdHeader` 逐个读取子地图头部，返回 `pingCount`。异常立即抛错，保持与其他入口脚本一致的报错风格。

5. **均匀展开误差**  
   `expandSubmapError` 根据 `pingCount` 将每个子地图的误差线性展开为 `pingCount` 个样本，记录：
   - `pingIdx`（累积伪时间）
   - `timeSec = pingIdx * cfg.errorTimeSeries.pingDt`
   - `dataset` / `metric`

6. **时间戳输出目录**  
   `main_errorTimeSeries` 以 `cfg.errorTimeSeries.outputDir` 作为根目录，并按照 `cfg.global.save.timestamp` 生成 `<timestamp>_errorTimeSeries` 子文件夹。本次运行生成的 `ping_error.mat` 与图像均写入该时间戳目录，便于区分多次实验。

7. **保存 MAT**  
   `savePingErrorMat` 将完整的 `table` 保存在 `cfg.errorTimeSeries.outputMat`，变量名为 `pingErrorTable`，字段包含：

   | dataset | metric | submap_id | ping_idx | time_s | err_xy |
   | --- | --- | --- | --- | --- | --- |
   | Comb | INS | 12 | 340 | 340.0 | 4.21 |
   | Comb | Comb | 12 | 340 | 340.0 | 1.35 |
   | NESP | NESP | 77 | 920 | 920.0 | 0.98 |

8. **绘制时间序列曲线**  
   `main_errorTimeSeries` 内部的 `plotErrorTimeSeriesFigure`（局部函数）读取前面返回的 `pingErrorTable`，按 `metric` 分组绘制 `time_s` vs `err_xy`，样式采用 `cfg.errorTimeSeries.vis`，保存逻辑复用 `cfg.global.save`。当 `cfg.errorTimeSeries.truncateToCommonRange`（默认 true）开启时，会根据各曲线最小的可用时间范围截断横轴，保证不同数据集子地图数量不一致时仍能在同一范围内对比；如需完整展示，可关闭该开关。可在其他脚本复用此逻辑，或从 MAT 载入 `pingErrorTable` 后自行绘图。

## 4. 与在线方案的差异

- **触发时机**：在线方案在增量优化阶段实时记录误差；当前模块一次性读完离线轨迹后统一生成时间序列。
- **误差来源**：在线模式依赖 DR 链条累计噪声；我们基于已有轨迹做差，结果等价但无需实时求解。
- **日志结构**：保留 `ping_error.mat`（变量 `pingErrorTable`），包含 `dataset` / `metric` 字段，方便同一张图比较三条曲线。

## 5. 调试与扩展建议

1. **路径校验**：`main_errorTimeSeries` 在调用核心函数前逐一检查轨迹与子地图目录；报错格式与 `main_plotAPE`、`main_plotBoxViolin` 保持一致。
2. **辅助函数集中**：`errorTimeSeries.m` 内部使用局部函数（MATLAB 支持），避免额外 `.m` 文件；包含 `validateErrorTimeSeriesConfig`, `parsePcdHeader`, `expandSubmapError`, `savePingErrorMat`, `plotErrorTimeSeries` 等。
3. **pingDt 调参**：若未来有真实时间戳，只需在 `config.m` 调整 `pingDt` 或改为从 CSV 读取 `timestamp`，无需改动主体框架。
4. **可视化联动**：如需与小提琴图或其他模块统一主题，可通过修改 `cfg.global.visual` 一处生效；`errorTimeSeries.vis.curves` 默认引用这些全局值，`main_errorTimeSeries` 的局部绘图函数也会继承全局图窗尺寸。

## 6. 快速复现步骤

1. 在 `Src/config.m` 中补齐 `cfg.errorTimeSeries` 与 `cfg.errorTimeSeries.vis`，设置数据路径、`pingDt`、输出目录。
2. 运行脚本：
   ```matlab
   >> main_errorTimeSeries
   ```
3. 在 `cfg.errorTimeSeries.outputDir` 中获取：
   - `ping_error.mat`（或配置指定的文件名，变量 `pingErrorTable`）
   - `error_time_series.png` / `.eps`（或 `cfg.global.save.formats` 指定的其它格式）

这样即可将 Comb 与 NESP 的定位误差随时间演化情况纳入统一评估流程。若需要扩展（例如引入 yaw 误差或真实时间戳），可在本文档的配置与函数结构基础上迭代。 

