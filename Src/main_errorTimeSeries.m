%% main_errorTimeSeries - 离线误差时间序列入口脚本
%
% 功能描述：
%   批量加载 config.m 中 Comb / NESP 轨迹与子地图配置，校验输入路径，
%   生成带时间戳的结果目录，调用 errorTimeSeries(cfg) 计算 ping-level 误差，
%   并在脚本内置的可视化函数中绘制/保存时间序列曲线。
%
% 作者信息：
%   作者：Chihong（游子昂）
%   邮箱：you.ziang@hrbeu.edu.cn
%   单位：哈尔滨工程大学
%
% 版本信息：
%   当前版本：v1.0
%   创建日期：251118
%   最后修改：251118
%
% 版本历史：
%   v1.0 (251118) - 首次发布
%       + 新增时间戳输出目录与 MAT/图像统一保存流程
%       + 集成可配置的横轴截断与图例/坐标风格
%
% 输入参数：
%   无直接输入；脚本依赖 config.m 中的 cfg.errorTimeSeries.*
%
% 输出结果：
%   Results/ErrorTimeSeries/<timestamp>_errorTimeSeries 目录，包含：
%       - ping_error.mat（变量 pingErrorTable）
%       - error_time_series.<fmt> 图像
%
% 注意事项：
%   1. 运行前需在 config.m 中配置 Comb/NESP 轨迹与子地图路径。
%   2. 若某数据集缺少指定轨迹/目录将直接报错终止。
%   3. 可通过 cfg.errorTimeSeries.truncateToCommonRange 控制横轴截断。
%
% 调用示例：
%   >> main_errorTimeSeries
%
% 依赖脚本/函数：
%   - config.m
%   - errorTimeSeries.m

clear; close all; clc;

%% 1. 配置与依赖
addpath(genpath('Src'));
cfg = config();

if ~cfg.errorTimeSeries.enable
    fprintf('[errorTimeSeries] 模块未启用，终止执行。\n');
    return;
end

%% 2. 路径校验
fprintf('[errorTimeSeries] 开始校验输入路径...\n');

paths_to_check = {
    'Comb poses_original', cfg.errorTimeSeries.comb.originalPath, true
    'Comb poses_corrupted', cfg.errorTimeSeries.comb.insPath, true
    'Comb poses_optimized', cfg.errorTimeSeries.comb.slamPath, true
    'Comb submaps dir', cfg.errorTimeSeries.comb.submapDir, false
    'NESP poses_original', cfg.errorTimeSeries.nesp.originalPath, true
    'NESP poses_optimized', cfg.errorTimeSeries.nesp.slamPath, true
    'NESP submaps dir', cfg.errorTimeSeries.nesp.submapDir, false
};

for idx = 1:size(paths_to_check, 1)
    label = paths_to_check{idx, 1};
    current_path = paths_to_check{idx, 2};
    is_file = paths_to_check{idx, 3};

    if is_file
        if ~isfile(current_path)
            error('[errorTimeSeries] 未找到文件: %s (%s)', current_path, label);
        end
    else
        if ~isfolder(current_path)
            error('[errorTimeSeries] 未找到目录: %s (%s)', current_path, label);
        end
    end
end

fprintf('[errorTimeSeries] 所有输入路径已通过校验。\n');

%% 3. 输出目录准备
shouldSaveArtifacts = cfg.errorTimeSeries.saveData && cfg.global.save.figures;
cfg_local = cfg;

if shouldSaveArtifacts
    baseOutputDir = cfg.errorTimeSeries.outputDir;
    if ~exist(baseOutputDir, 'dir')
        mkdir(baseOutputDir);
    end

    timestamp = datestr(now, cfg.global.save.timestamp);
    runOutputDir = fullfile(baseOutputDir, [timestamp, '_errorTimeSeries']);
    if ~exist(runOutputDir, 'dir')
        mkdir(runOutputDir);
    end

    [~, matBaseName, matExt] = fileparts(cfg.errorTimeSeries.outputMat);
    if isempty(matBaseName)
        matBaseName = 'ping_error';
    end
    if isempty(matExt)
        matExt = '.mat';
    end

    cfg_local.errorTimeSeries.outputDir = runOutputDir;
    cfg_local.errorTimeSeries.outputMat = fullfile(runOutputDir, [matBaseName, matExt]);
else
    fprintf('[errorTimeSeries] 保存开关关闭，跳过输出目录创建。\n');
end

cfg = cfg_local;

%% 4. 数据生成
fprintf('[errorTimeSeries] 开始生成误差时间序列...\n');
pingErrorTable = errorTimeSeries(cfg);
if shouldSaveArtifacts
    fprintf('[errorTimeSeries] 数据生成完成，输出目录：%s\n', cfg.errorTimeSeries.outputDir);
else
    fprintf('[errorTimeSeries] 数据生成完成，当前配置未保存结果到目录。\n');
end

%% 5. 可视化与导出
fprintf('[errorTimeSeries] %s开始绘制误差时间序列曲线...\n', newline);
plotErrorTimeSeriesFigure(pingErrorTable, cfg);
fprintf('[errorTimeSeries] 绘制完成。\n');

%% === 辅助函数 ===
function plotErrorTimeSeriesFigure(dataTable, cfg)
    etsCfg = cfg.errorTimeSeries;
    visCfg = etsCfg.vis;
    truncateEnabled = isfield(etsCfg, 'truncateToCommonRange') && logical(etsCfg.truncateToCommonRange);

    metricOrder = {'INS', 'Comb', 'NESP'};
    fig = figure('Name', 'Error Time Series');
    ax = gca;
    hold(ax, 'on');
    grid(ax, 'off');
    set(ax, 'Box', 'on');

    commonMaxTime = [];
    if truncateEnabled
        metricMaxTimes = [];
    end

    % 预先统计各曲线可用的最大时间，便于截断
    for i = 1:numel(metricOrder)
        metricName = metricOrder{i};
        if ~any(strcmp(dataTable.metric, metricName))
            continue;
        end
        if ~isfield(visCfg.curves, metricName)
            continue;
        end
        metricRows = dataTable(strcmp(dataTable.metric, metricName), :);
        if truncateEnabled && ~isempty(metricRows)
            metricMaxTimes(end+1) = max(metricRows.time_s); %#ok<AGROW>
        end
    end

    if truncateEnabled && exist('metricMaxTimes', 'var') && ~isempty(metricMaxTimes)
        commonMaxTime = min(metricMaxTimes);
    end

    for i = 1:numel(metricOrder)
        metricName = metricOrder{i};
        if ~any(strcmp(dataTable.metric, metricName))
            continue;
        end
        if ~isfield(visCfg.curves, metricName)
            continue;
        end
        curveCfg = visCfg.curves.(metricName);
        metricRows = dataTable(strcmp(dataTable.metric, metricName), :);
        if truncateEnabled && ~isempty(commonMaxTime)
            metricRows = metricRows(metricRows.time_s <= commonMaxTime, :);
        end
        if isempty(metricRows)
            continue;
        end
        plot(ax, metricRows.time_s, metricRows.err_xy, ...
            'Color', curveCfg.color, ...
            'LineStyle', curveCfg.lineStyle, ...
            'LineWidth', curveCfg.lineWidth, ...
            'DisplayName', metricName);
    end

    xlabel(ax, visCfg.axes.xlabel);
    ylabel(ax, visCfg.axes.ylabel);

    yLimConfigured = isfield(visCfg, 'axes') && isfield(visCfg.axes, 'ylim') ...
        && ~isempty(visCfg.axes.ylim) && numel(visCfg.axes.ylim) == 2;
    if yLimConfigured
        ylim(ax, visCfg.axes.ylim);
        maxErrVal = max(dataTable.err_xy);
        if maxErrVal > visCfg.axes.ylim(2)
            warning('errorTimeSeries:YLimExceeded', ...
                'errorTimeSeries: 数据最大值 %.2f 超出配置的 ylim 上限 %.2f，建议增大范围。', ...
                maxErrVal, visCfg.axes.ylim(2));
        end
    else
        maxErrVal = max(dataTable.err_xy);
        if isempty(maxErrVal) || maxErrVal <= 0
            maxErrVal = 1;
        end
        margin = max(0.05 * maxErrVal, 1);
        ylim(ax, [0, maxErrVal + margin]);
    end
    if truncateEnabled && ~isempty(commonMaxTime)
        xlim(ax, [0, commonMaxTime]);
    end
    legend(ax, 'Location', 'northwest', 'Box', 'on');

    applyGlobalFigureStyleLocal(fig, cfg.global.visual, 'errorTimeSeries');

    if etsCfg.saveData && cfg.global.save.figures
        fprintf('[errorTimeSeries] 正在保存图像，请勿关闭图窗...\n');
        baseName = fullfile(etsCfg.outputDir, 'error_time_series');
        exportFigureLocal(fig, baseName, cfg.global.save);
    end
end

function applyGlobalFigureStyleLocal(fig, visualCfg, figureSizeKey)
    set(findall(fig, '-property', 'FontSize'), 'FontSize', visualCfg.font_size_base * visualCfg.font_size_multiple);
    set(findall(fig, '-property', 'FontName'), 'FontName', visualCfg.font_name);
    set(fig, 'Units', 'centimeters');
    pos = get(fig, 'Position');
    [width_cm, height_cm] = getFigureSize(visualCfg, figureSizeKey);
    pos(3) = width_cm;
    pos(4) = height_cm;
    set(fig, 'Position', pos);
    set(fig, 'PaperUnits', 'centimeters');
    set(fig, 'PaperSize', [width_cm, height_cm]);
    set(fig, 'PaperPosition', [0 0 width_cm height_cm]);
end

function exportFigureLocal(fig, baseName, saveCfg)
    formats = saveCfg.formats;
    dpiVal = saveCfg.dpi;
    dpiOpt = ['-r', num2str(dpiVal)];
    for k = 1:numel(formats)
        fmt = lower(formats{k});
        switch fmt
            case 'png'
                print(fig, [baseName, '.png'], '-dpng', dpiOpt);
            case 'eps'
                print(fig, [baseName, '.eps'], '-depsc', dpiOpt);
            otherwise
                warning('[errorTimeSeries] 不支持的导出格式: %s', fmt);
        end
    end
    fprintf('[errorTimeSeries] 图像已保存至 %s (formats: %s)\n', baseName, strjoin(formats, ', '));
end

