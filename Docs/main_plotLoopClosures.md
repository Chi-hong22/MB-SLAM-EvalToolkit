
# `main_plotLoopClosures.m` 模块文档

## 1. 模块概述

`main_plotLoopClosures.m` 是一个专门用于可视化SLAM系统回环约束网络的入口脚本。该脚本的核心功能是调用 `plotLoopClosures` 函数，生成一个包含关键帧节点、里程计边和回环边的可视化图表。节点大小按回环度数（受约束边数量）动态映射，直观体现SLAM系统的约束拓扑结构。

此脚本主要用于分析SLAM系统的回环检测性能和全局约束分布，帮助理解位姿图优化的约束网络特征。

## 2. 功能特性

- **简单入口**: 提供清晰的配置入口点，用户只需在 `config.m` 中修改路径即可运行。
- **文件校验**: 在执行主功能前，脚本会检查位姿文件和回环文件是否存在，并在文件缺失时提供明确的错误提示。
- **自动化流程**: 自动读取位姿数据、解析回环关系、统计节点度数、生成可视化图表。
- **论文级导出**: 遵循 `/paper-visual` 规范，支持尺寸/字体等比放大、600 dpi 高分辨率、同时导出 PNG 和 EPS 格式。
- **配置集成**: 通过 `config()` 加载项目统一的配置，确保图表样式（字体、颜色、尺寸）与其他模块保持一致。
- **灵活的位姿源**: 支持选择 `poses_optimized.txt` 或 `poses_corrupted.txt`，分析优化前后的回环网络差异。
- **智能度数映射**: 节点尺寸按回环度数线性映射（带最小/最大值限制），直观展示约束密度。
- **错误处理**: 使用 `try-catch` 结构捕获执行过程中的错误，并提供详细的错误信息。

## 3. 核心逻辑流程

1.  **初始化**:
    - `clear; clc; close all;` 清理工作区和关闭所有图窗。
    - 打印脚本开始执行的标题和分隔线。

2.  **加载配置**:
    - 调用 `config()` 获取全局配置结构体 `cfg`。
    - 从 `cfg.loop` 中提取输入路径、位姿文件名、回环文件名、输出目录等参数。

3.  **构建文件路径**:
    - 位姿文件路径：`fullfile(cfg.loop.paths.input_folder, cfg.loop.paths.pose_file)`
    - 回环文件路径：`fullfile(cfg.loop.paths.input_folder, cfg.loop.paths.loop_file)`
    - 输出目录：`cfg.loop.paths.output_folder`

4.  **文件存在性检查**:
    - 检查位姿文件是否存在，如不存在则抛出错误并提示检查配置。
    - 检查回环文件是否存在，如不存在则抛出错误并提示检查配置。

5.  **调用绘图函数**:
    - 调用核心函数 `plotLoopClosures`，并传入以下参数：
      - **位姿文件路径**: 完整的位姿文件路径。
      - **回环文件路径**: 完整的回环文件路径。
      - **配置结构体**: 全局配置 `cfg`。
      - **`'SaveDir'`**: 输出目录。
      - **`'SaveEnable'`**: 是否保存图像（由 `cfg.loop.save.enable` 控制）。

6.  **完成与收尾**:
    - 如果函数成功执行，打印完成信息、输出路径、导出格式和分辨率信息。
    - 如果在 `try` 块中发生任何错误，`catch` 块会捕获该错误，打印详细的错误信息（包括错误位置和行号），然后重新抛出该错误。

## 4. 数据格式要求

### 4.1 位姿文件格式

位姿文件应为 `.txt` 格式，支持 `readTrajectory` 函数的所有格式：
- **3列格式**: `[x, y, z]` - 仅位置，自动生成索引
- **4列格式**: `[timestamp/pose_id, x, y, z]` - 带时间戳的位置
- **7列格式**: `[x, y, z, qx, qy, qz, qw]` - 位置+四元数
- **8列格式**: `[timestamp/pose_id, x, y, z, qx, qy, qz, qw]` - 完整位姿（TUM格式）

本模块只需要位置信息（X, Y坐标用于绘图），四元数数据会被忽略。

### 4.2 回环文件格式

回环文件应为 `.txt` 格式，采用**"大ID→小ID"单向记录**方式，每行格式为：

```
<当前子图ID> <比它小的回环子图ID1> <比它小的回环子图ID2> ...
```

**示例**：
```txt
17 14 15                      ← 节点17与节点14、15有回环
18 13 14                      ← 节点18与节点13、14有回环
121 85 92 115 116 117 118     ← 节点121与多个小ID节点有回环
```

**格式说明**：
- 第一列为当前子图ID
- 其余列为与之产生回环的子图ID（必须小于当前ID）
- ID从0开始编号，必须在关键帧数量范围内 `[0, num_keyframes)`
- 每条边只记录一次，天然保证唯一性
- 空行和以 `#` 开头的注释行会被自动跳过

## 5. 如何使用

### 5.1 基本使用流程

1.  **准备数据**:
    - 确保您有位姿文件（如 `poses_optimized.txt`）和回环文件（如 `loop_closures.txt`）在同一目录下。
    - 位姿文件和回环文件的关键帧ID应当对应（ID从0开始）。

2.  **修改配置文件**:
    - 打开 `Src/config.m` 文件。
    - 在 `cfg.loop` 部分修改以下参数：
      ```matlab
      % 输入目录
      cfg.loop.paths.input_folder = 'Data\您的数据目录';
      
      % 位姿文件选择
      cfg.loop.paths.pose_file = 'poses_optimized.txt';  % 或 'poses_corrupted.txt'
      
      % 输出目录
      cfg.loop.paths.output_folder = 'Results/LoopClosures';
      
      % 是否保存图像
      cfg.loop.save.enable = true;
      ```

3.  **运行脚本**:
    - 在MATLAB中，直接点击 "运行" 或在命令行中输入 `main_plotLoopClosures` 并回车。

4.  **查看结果**:
    - 脚本会生成一个图窗，其中包含：
      - **关键帧节点**: 红色圆点，尺寸随回环度数增大。
      - **里程计边**: 灰色实线，连接相邻关键帧（顺序连接）。
      - **回环边**: 蓝色实线，显示检测到的回环约束。
      - **坐标轴**: X-Y平面俯视图，单位为米。
    - 由于遵循论文级导出规范，图像会按配置的放大倍数显示。
    - 如果 `cfg.loop.save.enable = true`，图像会自动保存到输出目录。

### 5.2 配置参数说明

#### 路径配置
- `cfg.loop.paths.input_folder`: 数据输入目录，建议使用完整路径。
- `cfg.loop.paths.pose_file`: 位姿文件名（默认 `poses_optimized.txt`）。
- `cfg.loop.paths.loop_file`: 回环文件名（默认 `loop_closures.txt`）。
- `cfg.loop.paths.output_folder`: 结果输出目录。

#### 可视化参数
- **节点样式**:
  - `node_color`: 节点颜色，默认红色 `[255, 66, 37]/255`
  - `node_base_size`: 基准尺寸（无回环时），默认 20
  - `node_scale_factor`: 尺寸放大系数（每增加1个回环度数），默认 8
  - `node_min_size`: 最小尺寸限制，默认 15
  - `node_max_size`: 最大尺寸限制，默认 200

- **里程计边样式**:
  - `odom_color`: 边颜色，默认灰色 `[150, 150, 150]/255`
  - `odom_line_width`: 线宽，默认 1.0

- **回环边样式**:
  - `loop_color`: 边颜色，默认蓝色 `[58, 104, 231]/255`
  - `loop_line_width`: 线宽，默认 0.8

- **图窗与字体**:
  - `figure_width_cm` / `figure_height_cm`: 图窗物理尺寸（cm），默认 8.8×8.8
  - `font_name`: 字体名称，默认 'Arial'
  - `font_size_base`: 基准字号，默认 8pt
  - `font_size_multiple`: 字体放大倍数，默认 3
  - `figure_size_multiple`: 图窗放大倍数，默认 3

#### 保存配置
- `cfg.loop.save.enable`: 是否保存图像（true/false）
- `cfg.loop.save.formats`: 导出格式，默认 `{'png', 'eps'}`
- `cfg.loop.save.dpi`: 分辨率，默认 600

### 5.3 高级使用技巧

#### 切换位姿源
比较优化前后的回环网络差异：
```matlab
% 查看优化后的回环网络
cfg.loop.paths.pose_file = 'poses_optimized.txt';

% 查看优化前的回环网络
cfg.loop.paths.pose_file = 'poses_corrupted.txt';
```

#### 调整节点尺寸映射
根据回环密度调整可视化效果：
```matlab
% 适用于回环较少的场景（增强对比度）
cfg.loop.visual.node_base_size = 30;
cfg.loop.visual.node_scale_factor = 12;

% 适用于回环密集的场景（降低对比度）
cfg.loop.visual.node_base_size = 15;
cfg.loop.visual.node_scale_factor = 5;
```

#### 导出高质量矢量图
EPS格式适合论文插图：
```matlab
cfg.loop.save.formats = {'eps'};  % 仅导出矢量格式
cfg.loop.save.dpi = 600;          % 高分辨率
```

## 6. 核心算法逻辑

### 6.1 数据读取与解析

1. **位姿读取**: 使用 `readTrajectory` 函数读取位姿文件，提取关键帧位置（X, Y坐标）。
2. **回环解析**: 逐行解析回环文件，跳过空行和注释行。
3. **边构建**: 对每一行，将当前ID与其他ID配对，生成无向边列表 `(id1, id2)`，保证 `id1 < id2`。
4. **数据验证**: 过滤自环（ID与自身连接），验证ID范围是否在 `[0, num_keyframes)` 内。

### 6.2 度数统计（无向计数）

对每条回环边 `(id1, id2)`：
- `loop_degrees(id1) += 1`
- `loop_degrees(id2) += 1`

因为是无向图约束，每条边的两端节点都应增加度数。

### 6.3 节点尺寸映射

```matlab
node_sizes = base_size + scale_factor * loop_degrees
node_sizes = max(node_sizes, min_size)  % 下限裁剪
node_sizes = min(node_sizes, max_size)  % 上限裁剪
```

**映射逻辑**：
- 无回环节点（度数=0）: 显示基准尺寸
- 每增加1个回环度数: 尺寸增加 `scale_factor`
- 限制在 `[min_size, max_size]` 范围内，防止尺寸过小/过大

### 6.4 绘图顺序

1. **里程计边（底层）**: 灰色细线，连接相邻关键帧 `i → i+1`，形成轨迹骨架。
2. **回环边（中层）**: 蓝色实线，显示长距离约束关系。
3. **节点（顶层）**: 红色圆点，按度数映射尺寸，突出关键节点。

### 6.5 论文级导出规范

遵循 `/paper-visual` 要求：
- **等比放大**: 图窗物理尺寸和字体同时乘以放大倍数（默认3倍）。
- **屏幕一致**: 屏幕显示的物理尺寸与导出的纸张尺寸完全一致。
- **高分辨率**: 600 dpi 确保打印质量。
- **双格式**: 同时导出位图（PNG）和矢量（EPS），适配不同使用场景。
- **插入缩放**: 插入文档后按相同比例缩小，最终视觉字号回到基准要求。

## 7. 注意事项

- **ID从0开始**: 回环文件中的ID必须从0开始编号，与位姿文件行号对应。
- **数据一致性**: 回环文件中的最大ID不能超过位姿文件的关键帧数量。
- **单向记录**: 当前实现假设回环文件采用"大ID→小ID"单向记录格式，无需去重。
- **内存占用**: 对于大规模数据（数千个节点），绘图可能较慢，建议调整采样率或增加 `node_line_width` 以提高渲染速度。
- **MATLAB版本**: 推荐 MATLAB R2018b 或更高版本，确保 `scatter` 函数支持尺寸向量参数。

## 8. 保存与导出说明

### 8.1 输出文件命名

文件名格式：`<timestamp>_loop_closures.<format>`

示例：
- `20260107_143052_loop_closures.png`
- `20260107_143052_loop_closures.eps`

### 8.2 导出格式特性

- **PNG**: 位图格式，适用于快速预览和网页展示。
  - 优点：兼容性好，文件大小适中。
  - 缺点：缩放会损失清晰度（已通过高 dpi 缓解）。

- **EPS**: 矢量格式，适用于论文插图和出版印刷。
  - 优点：无损缩放，线条清晰，符合出版标准。
  - 缺点：文件较大，部分软件兼容性一般。

### 8.3 插入论文的建议流程

1. 使用放大后的图像（屏幕显示 8.8cm×3倍 = 26.4cm）
2. 导出 EPS 格式（600 dpi）
3. 插入 LaTeX 或 Word 文档
4. 缩小到原始尺寸（26.4cm → 8.8cm，缩放比例 1/3）
5. 最终效果：字号准确回到 9pt，图像清晰无锯齿

## 9. 常见问题

### Q1: 为什么节点尺寸差异不明显？
**A**: 调整 `node_scale_factor` 增大对比度，或检查回环密度是否过于均匀。

### Q2: 回环边太多导致图像混乱怎么办？
**A**: 
1. 调低 `loop_line_width` 使回环边更细
2. 调整 `loop_color` 透明度（需修改代码支持 alpha 通道）
3. 增大图窗尺寸（修改 `figure_width_cm` / `figure_height_cm`）

### Q3: 如何处理双向记录格式的回环文件？
**A**: 在 `plotLoopClosures.m` 的第285行添加去重代码：
```matlab
loop_edges = unique(edges_temp, 'rows');
```

### Q4: 导出的图像字体太小/太大怎么办？
**A**: 调整 `font_size_multiple` 参数，或修改 `font_size_base` 基准字号。

### Q5: 能否显示回环约束的强度（如置信度）？
**A**: 当前实现不支持。如需显示，需修改回环文件格式添加权重列，并在 `plotLoopClosures.m` 中扩展边宽度或颜色映射逻辑。

## 10. 扩展与定制

### 10.1 添加图例
在 `plotLoopClosures.m` 第174行后添加：
```matlab
legend({'Odometry Edges', 'Loop Closures', 'Keyframes'}, ...
       'Location', 'best', ...
       'FontName', cfg.loop.visual.font_name, ...
       'FontSize', actual_font_size);
```

### 10.2 支持3D可视化
将绘图从2D扩展到3D（需要Z坐标）：
```matlab
plot3(ax, [pos1(1), pos2(1)], [pos1(2), pos2(2)], [pos1(3), pos2(3)], ...)
scatter3(ax, positions(:,1), positions(:,2), positions(:,3), node_sizes, ...)
```

### 10.3 添加节点ID标签
在绘制节点后添加文本标注：
```matlab
for i = 1:num_keyframes
    text(ax, positions(i,1), positions(i,2), sprintf('%d', i-1), ...
         'FontSize', 6, 'HorizontalAlignment', 'center');
end
```

## 11. 相关文档

- **[README.md](../README.md)**: 项目总览与快速入门
- **[config.m](../Src/config.m)**: 全局配置文件
- **[plotLoopClosures.m](../Src/plotLoopClosures.m)**: 核心绘图函数源码
- **[readTrajectory.m](../Src/readTrajectory.m)**: 位姿数据读取函数文档

## 12. 版本历史

- **v1.0** (2026-01-07): 初始版本发布
  - 实现基本的回环网络可视化
  - 支持节点度数映射与论文级导出
  - 提供完整的配置接口
