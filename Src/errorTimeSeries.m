%% errorTimeSeries - Comb/NESP ping 级误差时间序列生成函数
%
% 功能描述：
%   读取配置中的 Comb/NESP 轨迹与子地图信息，计算 INS / Comb / NESP
%   三条 XY 平面误差序列，并按 ping 数展开、写入 MAT，供可视化或
%   后处理使用。
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
%       + 支持 Comb/NESP 轨迹读取、子地图 ping 展开与 MAT 保存
%       + 输出 pingErrorTable 供上层脚本可视化
%
% 输入参数：
%   cfg - config() 返回的结构体，需包含 cfg.errorTimeSeries.*
%
% 输出参数：
%   pingErrorTable - table，字段包含 dataset/metric/submap_id/ping_idx/time_s/err_xy
%
% 注意事项：
%   1. 轨迹行数需与子地图数量一致，否则抛出错误。
%   2. cfg.errorTimeSeries.submapExtList 用于筛选子地图文件扩展名。
%   3. 输出 MAT 路径由 cfg.errorTimeSeries.outputMat 指定，需可写。
%
% 调用示例：
%   pingTbl = errorTimeSeries(config());
%
% 依赖函数：
%   readTrajectory, parsePcdHeader, expandSubmapError
function pingErrorTable = errorTimeSeries(cfg)
    etsCfg = cfg.errorTimeSeries;
    validateErrorTimeSeriesConfig(etsCfg);

    pingDt = etsCfg.pingDt;
    submapExtList = etsCfg.submapExtList;

    % Comb 数据集
    combDataset = buildDatasetStruct( ...
        'Comb', ...
        etsCfg.comb, ...
        submapExtList, ...
        {'INS', 'Comb'}, ...
        @(traj) computeCombMetrics(traj) ...
    );

    % NESP 数据集
    nespDataset = buildDatasetStruct( ...
        'NESP', ...
        etsCfg.nesp, ...
        submapExtList, ...
        {'NESP'}, ...
        @(traj) computeNespMetrics(traj) ...
    );

    allDatasets = [combDataset, nespDataset];

    tables = cell(0, 1);
    for dIdx = 1:numel(allDatasets)
        dataset = allDatasets(dIdx);
        for mIdx = 1:numel(dataset.metrics)
            metric = dataset.metrics(mIdx);
            metricTable = expandSubmapError(dataset.name, metric.name, dataset.submapIds, ...
                dataset.pingCounts, dataset.pingIdxStart, metric.errors, pingDt);
            tables{end+1, 1} = metricTable; %#ok<AGROW>
        end
    end


    fprintf('\n[errorTimeSeries] 生成 ping 误差样本...\n');
    combinedTable = vertcat(tables{:});
    combinedTable = sortrows(combinedTable, {'dataset', 'metric', 'ping_idx'});

    if etsCfg.saveData && cfg.global.save.figures
        fprintf('[errorTimeSeries] 已生成 %d 条 ping 误差样本，开始保存 MAT 文件...\n', height(combinedTable));
        savePingErrorMat(combinedTable, etsCfg);
        fprintf('[errorTimeSeries] MAT 保存完成。\n');
    else
        fprintf('[errorTimeSeries] 已生成 %d 条 ping 误差样本，按配置跳过 MAT 保存。\n', height(combinedTable));
    end

    pingErrorTable = combinedTable;
end

function datasetStruct = buildDatasetStruct(datasetName, datasetCfg, submapExtList, metricNames, metricFunc)
    traj = readDatasetTrajectories(datasetCfg, metricNames);
    pingCounts = collectPingCounts(datasetCfg.submapDir, submapExtList);
    submapCount = numel(pingCounts);

    if size(traj.original, 1) ~= submapCount
        error('[errorTimeSeries:%s] 轨迹行数(%d)与子地图数量(%d)不一致。', datasetName, size(traj.original, 1), submapCount);
    end

    datasetStruct = struct();
    datasetStruct.name = datasetName;
    datasetStruct.submapIds = (1:submapCount).';
    datasetStruct.pingCounts = pingCounts;
    datasetStruct.pingIdxStart = computePingIndexStart(pingCounts);
    datasetStruct.metrics = metricFunc(traj);
end

function traj = readDatasetTrajectories(datasetCfg, metricNames)
    [~, trajOriginal] = readTrajectory(datasetCfg.originalPath, 'Mode', 'onlypose');
    traj = struct();
    traj.original = trajOriginal;

    if any(strcmp(metricNames, 'INS'))
        [~, trajIns] = readTrajectory(datasetCfg.insPath, 'Mode', 'onlypose');
        assertTrajectoryLength(traj.original, trajIns, 'INS');
        traj.ins = trajIns;
    end

    if any(strcmp(metricNames, 'Comb')) || any(strcmp(metricNames, 'NESP'))
        [~, trajSlam] = readTrajectory(datasetCfg.slamPath, 'Mode', 'onlypose');
        assertTrajectoryLength(traj.original, trajSlam, 'SLAM');
        traj.slam = trajSlam;
    end
end

function metrics = computeCombMetrics(traj)
    metrics = struct( ...
        'name', {'INS', 'Comb'}, ...
        'errors', { ...
            computeXYError(traj.ins, traj.original), ...
            computeXYError(traj.slam, traj.original) ...
        } ...
    );
end

function metrics = computeNespMetrics(traj)
    metrics = struct( ...
        'name', {'NESP'}, ...
        'errors', {computeXYError(traj.slam, traj.original)} ...
    );
end

function assertTrajectoryLength(reference, target, label)
    if size(reference, 1) ~= size(target, 1)
        error('[errorTimeSeries:%s] 轨迹长度不匹配: %d vs %d', label, size(reference, 1), size(target, 1));
    end
end

function pingCounts = collectPingCounts(submapDir, extList)
    listing = dir(submapDir);
    isFile = ~[listing.isdir];
    listing = listing(isFile);

    if isempty(listing)
        error('[errorTimeSeries] 子地图目录 %s 为空。', submapDir);
    end

    selected = [];
    for i = 1:numel(listing)
        [~, ~, ext] = fileparts(listing(i).name);
        if any(strcmpi(extList, ext))
            selected = [selected; listing(i)]; %#ok<AGROW>
        end
    end

    if isempty(selected)
        error('[errorTimeSeries] 目录 %s 中未找到扩展名 %s 对应的子地图。', submapDir, strjoin(extList, ', '));
    end

    [~, order] = sort({selected.name});
    selected = selected(order);

    pingCounts = zeros(numel(selected), 1);
    for i = 1:numel(selected)
        filePath = fullfile(submapDir, selected(i).name);
        pingCounts(i) = parsePcdHeader(filePath);
    end
end

function pingIdxStart = computePingIndexStart(pingCounts)
    pingIdxStart = zeros(numel(pingCounts), 1);
    cumulative = 0;
    for i = 1:numel(pingCounts)
        pingIdxStart(i) = cumulative;
        cumulative = cumulative + pingCounts(i);
    end
end

function metricTable = expandSubmapError(datasetName, metricName, submapIds, pingCounts, pingIdxStart, submapErrors, pingDt)
    if numel(submapIds) ~= numel(pingCounts) || numel(submapIds) ~= numel(submapErrors)
        error('[errorTimeSeries:%s] 子地图长度不一致。', metricName);
    end

    rows = cell(numel(submapIds), 1);
    for i = 1:numel(submapIds)
        count = pingCounts(i);
        startIdx = pingIdxStart(i);
        pingIdx = (startIdx:(startIdx + count - 1)).';
        timeSec = pingIdx * pingDt;
        errVal = repmat(submapErrors(i), count, 1);
        submapCol = repmat(submapIds(i), count, 1);
        datasetCol = repmat(string(datasetName), count, 1);
        metricCol = repmat(string(metricName), count, 1);

        rows{i} = table(datasetCol, metricCol, submapCol, pingIdx, timeSec, errVal, ...
            'VariableNames', {'dataset', 'metric', 'submap_id', 'ping_idx', 'time_s', 'err_xy'});
    end

    metricTable = vertcat(rows{:});
end

function xyError = computeXYError(estPoses, gtPoses)
    delta = estPoses(:, 1:2) - gtPoses(:, 1:2);
    xyError = sqrt(sum(delta.^2, 2));
end

function savePingErrorMat(dataTable, etsCfg)
    outputMat = etsCfg.outputMat;
    outputDir = fileparts(outputMat);
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    pingErrorTable = dataTable; %#ok<NASGU>
    save(outputMat, 'pingErrorTable', '-v7.3');
    fprintf('[errorTimeSeries] MAT 文件已保存: %s (变量: pingErrorTable)\n', outputMat);
end

function validateErrorTimeSeriesConfig(etsCfg)
    requiredFields = {'enable', 'pingDt', 'outputDir', 'outputMat', 'saveData', 'comb', 'nesp', 'submapExtList'};
    for i = 1:numel(requiredFields)
        if ~isfield(etsCfg, requiredFields{i})
            error('[errorTimeSeries] 缺少配置字段: %s', requiredFields{i});
        end
    end

    if etsCfg.pingDt <= 0
        error('[errorTimeSeries] pingDt 必须为正数。');
    end

    if ~iscell(etsCfg.submapExtList) || isempty(etsCfg.submapExtList)
        error('[errorTimeSeries] submapExtList 必须为非空 cell 数组。');
    end

    datasetFields = {'originalPath', 'slamPath', 'submapDir'};
    combFields = [datasetFields, {'insPath'}];
    for i = 1:numel(combFields)
        if ~isfield(etsCfg.comb, combFields{i})
            error('[errorTimeSeries] 缺少 Comb 配置字段: %s', combFields{i});
        end
    end

    for i = 1:numel(datasetFields)
        if ~isfield(etsCfg.nesp, datasetFields{i})
            error('[errorTimeSeries] 缺少 NESP 配置字段: %s', datasetFields{i});
        end
    end
end

function pingCount = parsePcdHeader(filePath)
    fid = fopen(filePath, 'r');
    if fid == -1
        error('[errorTimeSeries] 无法打开文件: %s', filePath);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    pingCount = [];
    while true
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end
        trimmed = strtrim(line);
        if isempty(trimmed) || startsWith(trimmed, '#')
            continue;
        end
        tokens = strsplit(trimmed);
        key = upper(tokens{1});
        switch key
            case {'WIDTH', 'POINTS'}
                if numel(tokens) < 2
                    error('[errorTimeSeries] 文件 %s 的 %s 行格式错误。', filePath, key);
                end
                pingCount = str2double(tokens{2});
            case 'DATA'
                break;
        end
    end

    if isempty(pingCount) || isnan(pingCount)
        error('[errorTimeSeries] 文件 %s 的头部缺少 WIDTH/POINTS。', filePath);
    end
end

