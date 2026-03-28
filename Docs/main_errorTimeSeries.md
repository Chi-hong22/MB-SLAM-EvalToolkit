# `errorTimeSeries` 模块文档

## 1. 模块概述

`errorTimeSeries` 模块将一组 SLAM 离线结果转成"时间 vs XY 平面误差"曲线，导出统一的 `ping_error.mat`（文件名可在配置中改，变量名固定为 `pingErrorTable`）。整体设计基于"按子地图均匀展开误差"思想，输入仅依赖 `poses_*.txt` 与对应子地图点云。

模块支持：

- **1 个 reference 数据集**：通常为主算法（如 NESP）
- **多个 benchmark 数据集**：对比数据（如 Comb、Ling），可随时在配置中新增
- **1 条可配置 INS 曲线**：来源可指向 reference 或任意 benchmark

每条误差曲线只能在各自数据集内部计算，禁止跨数据集混用路径。

### 文件结构（脚本 + 函数）

- `Src/main_errorTimeSeries.m`（脚本）：入口脚本。负责加载 `config.m`、动态检查路径、调用核心函数生成数据，并在脚本内部的辅助函数中完成时间序列绘图/导出；同时按照 `cfg.global.save.timestamp` 自动创建时间戳子目录。
- `Src/errorTimeSeries.m`（函数）：核心数据函数，导出为
  ```matlab
  function pingErrorTable = errorTimeSeries(cfg)
  ```
  负责读取轨迹、展开误差并保存 `ping_error.mat`，返回 `pingErrorTable` 供上层脚本使用。

### 输出曲线

曲线由 `cfg.errorTimeSeries.vis.metricOrder` 决定，典型示例：

- **INS**：选定来源数据集的 `insPath` vs `originalPath` 误差
- **NESP**（reference）：`poses_optimized` vs `poses_original` 误差
- **Comb / Ling 等**（benchmark）：各自 `poses_optimized` vs `poses_original` 误差

每条曲线按子地图 ping 数均匀展开，横轴由 `ping_idx * cfg.errorTimeSeries.pingDt` 得到时间。

## 2. 输入数据与配置

### 2.1 数据集字段

每个数据集（reference 或 benchmark）包含以下字段：

| 字段 | 说明 |
| --- | --- |
| `id` | 内部唯一标识，用于配置引用（如 INS 来源指定） |
| `displayName` | 输出图例与表格中的显示名，必须唯一 |
| `originalPath` | 真值轨迹 `poses_original.txt` |
| `slamPath` | SLAM 优化后轨迹 `poses_optimized.txt` |
| `submapDir` | 子地图目录 |
| `insPath` | INS 轨迹 `poses_corrupted.txt`（可选；若被选为 INS 来源则必填） |

### 2.2 子地图与 ping 计数

子地图均为 ASCII PCD/PDC，需解析头部字段：

- `WIDTH` 或 `POINTS`：子地图包含的 ping 数
- `DATA`：用来定位正文开始位置（无需加载整个点云）

### 2.3 INS 配置

`ins` 字段控制单条 INS 曲线的行为：

| 字段 | 说明 |
| --- | --- |
| `enable` | 是否启用 INS 曲线 |
| `displayName` | INS 曲线的图例名（不能与任何数据集 displayName 冲突） |
| `sourceDatasetId` | 指定 INS 数据来源的数据集 `id`（可为 reference 或任一 benchmark） |

### 2.4 `config.m` 配置示例

```matlab
cfg.errorTimeSeries = struct();
cfg.errorTimeSeries.enable    = true;
cfg.errorTimeSeries.pingDt    = 0.003;
cfg.errorTimeSeries.outputDir = 'Results/ErrorTimeSeries';
cfg.errorTimeSeries.outputMat = fullfile(cfg.errorTimeSeries.outputDir, 'ping_error.mat');
cfg.errorTimeSeries.saveData  = false;
cfg.errorTimeSeries.truncateToCommonRange = true;
cfg.errorTimeSeries.submapExtList = {'.pcd', '.pdc'};

% reference 数据集（主算法）
cfg.errorTimeSeries.referenceDataset = struct( ...
    'id', 'nesp', ...
    'displayName', 'NESP', ...
    'originalPath', 'Data/251111_NESP_noINS/.../poses_original.txt', ...
    'slamPath',     'Data/251111_NESP_noINS/.../poses_optimized.txt', ...
    'submapDir',    'Data/251111_NESP_noINS/submaps', ...
    'insPath',      'Data/251111_NESP_noINS/.../poses_corrupted.txt');

% benchmark 数据集列表（可继续追加）
cfg.errorTimeSeries.benchmarkDatasets = [ ...
    struct('id','ling','displayName','Ling', ...
        'originalPath','Data/260326_Ling_noINS/.../poses_original.txt', ...
        'slamPath',    'Data/260326_Ling_noINS/.../poses_optimized.txt', ...
        'submapDir',   'Data/260326_Ling_noINS/submaps', ...
        'insPath',     'Data/260326_Ling_noINS/.../poses_corrupted.txt') ...
];

% INS 配置
cfg.errorTimeSeries.ins = struct( ...
    'enable', true, ...
    'displayName', 'INS', ...
    'sourceDatasetId', 'ling');

% 可视化配置
cfg.errorTimeSeries.vis = struct();
cfg.errorTimeSeries.vis.metricOrder = {'INS', 'NESP', 'Ling'};
cfg.errorTimeSeries.vis.curves = [ ...
    struct('metricName','INS',  'color',[1.0,0.26,0.15],'lineStyle','-','lineWidth',1.5), ...
    struct('metricName','NESP', 'color',[0.10,0.62,0.13],'lineStyle','-','lineWidth',1.5), ...
    struct('metricName','Ling', 'color',[0.23,0.41,0.91],'lineStyle','-','lineWidth',1.5) ...
];
cfg.errorTimeSeries.vis.axes = struct( ...
    'xlabel', 'Time (s)', ...
    'ylabel', 'Position Error (m)', ...
    'ylim',   []);
```

> **新增 benchmark 只需在 `benchmarkDatasets` 中追加一项，并在 `metricOrder` 和 `vis.curves` 中同步添加对应条目，无需修改任何主流程代码。**

## 3. 数据处理流程

1. **加载配置**
   `cfg = config();`，脚本 `main_errorTimeSeries` 将 `cfg` 传入同名函数。

2. **配置校验**
   `validateErrorTimeSeriesConfig` 检查：
   - 基础字段完整性
   - 所有 `id` / `displayName` 唯一性
   - INS 来源数据集存在且有 `insPath`
   - `metricOrder` 与 `vis.curves` 和实际曲线集合完全一致（多一项少一项均报错）

3. **读取轨迹与子地图**
   对每个数据集各自读取 `originalPath` 与 `slamPath`（或 INS 来源的 `insPath`），并解析子地图 ping 数。

4. **计算子地图误差**
   每个数据集只在自己的轨迹内计算 XY 误差，禁止跨数据集混用。

5. **均匀展开误差**
   `expandSubmapError` 将每个子地图的误差按 ping 数线性展开，生成：
   - `pingIdx`（累积伪时间索引）
   - `timeSec = pingIdx * pingDt`

6. **合并输出**
   合并所有数据集和 INS 的表格，写入 `pingErrorTable`，变量字段：

   | dataset | metric | submap_id | ping_idx | time_s | err_xy |
   | --- | --- | --- | --- | --- | --- |
   | Ling | INS  | 12 | 340 | 1.02 | 4.21 |
   | NESP | NESP | 77 | 920 | 2.76 | 0.98 |
   | Ling | Ling | 12 | 340 | 1.02 | 1.35 |

   - 对 reference / benchmark 自身曲线：`dataset = metric = displayName`
   - 对 INS 曲线：`dataset = INS 来源数据集的 displayName`，`metric = ins.displayName`

7. **绘图**
   `main_errorTimeSeries` 内部的 `plotErrorTimeSeriesFigure` 按 `metricOrder` 遍历，从 `vis.curves` 列表按 `metricName` 查找样式后绘制。

## 4. 配置校验规则

`finalMetrics = {referenceDataset.displayName} ∪ {benchmarkDatasets.displayName...} ∪ {ins.displayName if ins.enable}`

- `metricOrder` 必须与 `finalMetrics` 完全一致（多一项或少一项均报错）
- `vis.curves` 的 `metricName` 集合也必须与 `finalMetrics` 完全一致
- `ins.displayName` 不能与任何数据集 `displayName` 冲突
- `ins.enable = false` 时，`metricOrder` 中不能出现 `ins.displayName`

## 5. 调试与扩展建议

1. **路径校验**：`main_errorTimeSeries` 动态遍历所有数据集校验路径，报错信息包含数据集名称。
2. **新增 benchmark**：在 `benchmarkDatasets` 追加 struct，同步更新 `metricOrder` 和 `vis.curves`。
3. **切换 INS 来源**：修改 `ins.sourceDatasetId` 为目标数据集的 `id`，确保该数据集有 `insPath`。
4. **关闭 INS**：设置 `ins.enable = false`，并从 `metricOrder` 和 `vis.curves` 中移除 INS 项。
5. **pingDt 调参**：若未来有真实时间戳，只需在 `config.m` 调整 `pingDt`，无需改动主体框架。

## 6. 快速复现步骤

1. 在 `Src/config.m` 中配置 `referenceDataset`、`benchmarkDatasets`、`ins`、`vis`。
2. 确保 `metricOrder` 与 `vis.curves` 的 `metricName` 集合与实际数据集加 INS 完全一致。
3. 运行脚本：
   ```matlab
   >> main_errorTimeSeries
   ```
4. 在 `cfg.errorTimeSeries.outputDir` 中获取：
   - `ping_error.mat`（变量 `pingErrorTable`）
   - `error_time_series.png` / `.eps`（或 `cfg.global.save.formats` 指定的其他格式）
