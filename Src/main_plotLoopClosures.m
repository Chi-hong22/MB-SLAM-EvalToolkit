%% main_plotLoopClosures - 回环约束可视化主入口
% 文件输入：配置文件（config.m）
% 文件输出：回环可视化图像（png/eps）
% 文件地位：回环可视化模块的主入口，负责加载配置并调用绘图函数
%
% 功能描述：
%   1. 加载全局配置（config()）
%   2. 构建位姿文件与回环文件的完整路径
%   3. 调用 plotLoopClosures 进行可视化
%   4. 可选保存高质量图像（论文级导出）
%
% 使用方法：
%   方法1：直接运行（使用配置文件默认参数）
%       >> main_plotLoopClosures
%
%   方法2：修改配置后运行
%       修改 Src/config.m 中的 cfg.loop.* 参数，然后运行：
%       >> main_plotLoopClosures
%
% 配置要点：
%   - cfg.loop.paths.input_folder：数据输入目录
%   - cfg.loop.paths.pose_file：位姿文件名（poses_optimized.txt 或 poses_corrupted.txt）
%   - cfg.loop.paths.loop_file：回环文件名（默认 loop_closures.txt）
%   - cfg.loop.paths.output_folder：输出目录
%   - cfg.loop.save.enable：是否保存图像
%
% 作者信息：
%   作者：Chihong（游子昂）
%   邮箱：you.ziang@hrbeu.edu.cn
%   单位：哈尔滨工程大学
%
% 版本信息：
%   当前版本：v1.0
%   创建日期：2026-01-07
%   最后修改：2026-01-07
%
% 注意事项：
%   1. 确保 loop_closures.txt 与位姿文件在同一目录下
%   2. 回环文件格式：每行 <当前ID> <回环ID1> <回环ID2> ...
%   3. 位姿文件支持 readTrajectory 的所有格式（3/4/7/8列）
%   4. 导出遵循 /paper-visual 规范（等比放大、600 dpi、png+eps）

%% 清理环境
clc;
clear;
close all;

%% 加载配置
fprintf('==============================================\n');
fprintf('  回环约束可视化工具 (Loop Closure Visualization)\n');
fprintf('==============================================\n\n');

fprintf('正在加载配置...\n');
cfg = config();
fprintf('配置加载完成\n\n');

%% 构建文件路径
fprintf('--- 文件路径配置 ---\n');

% 输入目录
input_folder = cfg.loop.paths.input_folder;
fprintf('输入目录: %s\n', input_folder);

% 位姿文件
pose_file_path = fullfile(input_folder, cfg.loop.paths.pose_file);
fprintf('位姿文件: %s\n', pose_file_path);

% 回环文件
loop_file_path = fullfile(input_folder, cfg.loop.paths.loop_file);
fprintf('回环文件: %s\n', loop_file_path);

% 输出目录
output_folder = cfg.loop.paths.output_folder;
fprintf('输出目录: %s\n', output_folder);

fprintf('\n');

%% 文件存在性检查
fprintf('--- 文件检查 ---\n');
if ~isfile(pose_file_path)
    error('位姿文件不存在: %s\n请检查配置中的 cfg.loop.paths.input_folder 和 cfg.loop.paths.pose_file', ...
          pose_file_path);
end
fprintf('✓ 位姿文件存在\n');

if ~isfile(loop_file_path)
    error('回环文件不存在: %s\n请检查配置中的 cfg.loop.paths.loop_file', ...
          loop_file_path);
end
fprintf('✓ 回环文件存在\n');
fprintf('\n');

%% 执行可视化
fprintf('--- 开始可视化 ---\n');
try
    fig_handle = plotLoopClosures(pose_file_path, loop_file_path, cfg, ...
                                   'SaveDir', output_folder, ...
                                   'SaveEnable', cfg.loop.save.enable);
    fprintf('\n');
catch ME
    fprintf('\n❌ 可视化失败:\n');
    fprintf('  错误信息: %s\n', ME.message);
    fprintf('  错误位置: %s (第 %d 行)\n', ME.stack(1).name, ME.stack(1).line);
    rethrow(ME);
end

%% 完成提示
fprintf('==============================================\n');
fprintf('  回环可视化完成！\n');
fprintf('==============================================\n\n');

if cfg.loop.save.enable
    fprintf('✓ 图像已保存至: %s\n', output_folder);
    fprintf('✓ 导出格式: %s\n', strjoin(cfg.loop.save.formats, ', '));
    fprintf('✓ 分辨率: %d dpi\n', cfg.loop.save.dpi);
else
    fprintf('ℹ 图像保存已禁用（cfg.loop.save.enable = false）\n');
    fprintf('  如需保存，请在 config.m 中设置 cfg.loop.save.enable = true\n');
end

fprintf('\n提示：图窗已打开，可手动调整查看\n');
