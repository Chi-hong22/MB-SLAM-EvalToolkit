%% main_plotBoxViolin - ATE 多数据集分布对比入口脚本
%
% 功能描述：
%   读取 config.m 中 cfg.ateViolin.datasets 配置，动态校验输入路径，
%   对每个数据集从原始轨迹文件直接计算 ATE（无需预先生成 CSV），
%   收集误差向量后调用 plotATEDistributions 绘制箱线图与小提琴图。
%
%   新增 benchmark 只需在 config.m 的 cfg.ateViolin.datasets 中追加一项，
%   无需修改本脚本。
%
% 作者信息：
%   作者：Chihong（游子昂）
%   邮箱：you.ziang@hrbeu.edu.cn
%   单位：哈尔滨工程大学
%
% 版本信息：
%   当前版本：v2.0
%   创建日期：251118
%   最后修改：260330
%
% 版本历史：
%   v2.0 (260330) - 重构，借鉴 errorTimeSeries 多 benchmark 驱动模式
%       + 改为从 cfg.ateViolin.datasets 读取数据集，不再依赖预计算 CSV
%       + 动态路径校验，支持任意数量 benchmark 数据集
%   v1.0 (251118) - 首次发布，读取预计算 CSV 文件绘图
%
% 输入参数：
%   无直接输入；脚本依赖 config.m 中的 cfg.ateViolin.*
%
% 调用示例：
%   >> main_plotBoxViolin
%
% 依赖脚本/函数：
%   - config.m
%   - readTrajectory.m
%   - alignAndComputeATE.m
%   - plotATEDistributions.m

clear; close all; clc;

%% 1. 配置与依赖
addpath(genpath('Src'));
cfg = config();

fprintf('=== ATE 多数据集分布对比绘制 ===\n');
fprintf('开始时间: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

violinCfg = cfg.ateViolin;

%% 2. 路径校验
fprintf('[ateViolin] 开始校验输入路径...\n');

for idx = 1:numel(violinCfg.datasets)
    ds = violinCfg.datasets(idx);
    checkPath(ds.gtPath,   sprintf('dataset(%s) gtPath',   ds.displayName));
    checkPath(ds.slamPath, sprintf('dataset(%s) slamPath', ds.displayName));
end

fprintf('[ateViolin] 所有输入路径已通过校验。\n\n');

%% 3. 计算各数据集 ATE
numDs    = numel(violinCfg.datasets);
allData  = cell(1, numDs);
labels   = cell(1, numDs);

for idx = 1:numDs
    ds = violinCfg.datasets(idx);
    labels{idx} = ds.displayName;

    fprintf('[ateViolin] 正在计算 %s 的 ATE...\n', ds.displayName);

    [gt_ts,   gt_traj,  ~] = readTrajectory(ds.gtPath,   'Mode', 'onlypose');
    [est_ts, est_traj,  ~] = readTrajectory(ds.slamPath, 'Mode', 'onlypose');

    [ate_metrics, ~, ~] = alignAndComputeATE(gt_ts, gt_traj, est_ts, est_traj);

    allData{idx} = ate_metrics.errors;
    fprintf('  RMSE: %.4f m  |  样本数: %d\n', ate_metrics.rmse, numel(ate_metrics.errors));
end

fprintf('\n[ateViolin] 全部数据集 ATE 计算完成。\n\n');

%% 4. 输出目录准备
shouldSave = logical(cfg.global.save.figures) && logical(violinCfg.save.enable);
outputDir  = '';

if shouldSave
    baseDir = violinCfg.outputDir;
    if ~exist(baseDir, 'dir')
        mkdir(baseDir);
    end
    timestamp = datestr(now, cfg.global.save.timestamp);
    outputDir = fullfile(baseDir, [timestamp, '_ATE_distributions']);
    mkdir(outputDir);
end

%% 5. 绘图
plotATEDistributions( ...
    'cfg',       cfg, ...
    'data',      allData, ...
    'labels',    labels, ...
    'save',      shouldSave, ...
    'outputDir', outputDir);

fprintf('[ateViolin] 绘制结束.\n');

%% === 辅助函数 ===
function checkPath(pathStr, label)
    if ~isfile(pathStr)
        error('[ateViolin] 未找到文件: %s (%s)', pathStr, label);
    end
end
