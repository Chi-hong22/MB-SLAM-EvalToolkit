%% errorTimeSeries - 通用 ping 级误差时间序列生成函数
%
% 功能描述：
%   读取配置中的 reference 数据集、多个 benchmark 数据集及可选 INS 来源，
%   计算各数据集自身的 XY 平面误差序列，并按 ping 数展开、写入 MAT，
%   供可视化或后处理使用。
%
% 作者信息：
%   作者：Chihong（游子昂）
%   邮箱：you.ziang@hrbeu.edu.cn
%   单位：哈尔滨工程大学
%
% 版本信息：
%   当前版本：v2.0
%   创建日期：251118
%   最后修改：260327
%
% 版本历史：
%   v2.0 (260327) - 泛化重构
%       + 支持 1 个 reference + 多个 benchmark + 1 条可配置 INS
%       + 移除固定 Comb/NESP 分支，改为通用数据集循环
%       + 新增配置校验：displayName 唯一性、INS 来源合法性、metricOrder 完整性
%   v1.0 (251118) - 首次发布
%       + 支持 Comb/NESP 轨迹读取、子地图 ping 展开与 MAT 保存
%
% 输入参数：
%   cfg - config() 返回的结构体，需包含 cfg.errorTimeSeries.*
%
% 输出参数：
%   pingErrorTable - table，字段包含 dataset/metric/submap_id/ping_idx/time_s/err_xy
%
% 注意事项：
%   1. 轨迹行数需与子地图数量一致，否则抛出错误。
%   2. 每个数据集的误差仅使用该数据集自己的路径计算，禁止跨数据集混用。
%   3. INS 曲线来源由 cfg.errorTimeSeries.ins.sourceDatasetId 指定。
%   4. displayName 必须唯一，metricOrder 与 vis.curves 必须与实际曲线集合一致。
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

    % 构造所有数据集列表
    allDatasets = [];

    % 添加 reference 数据集
    refDs = buildDatasetStruct( ...
        etsCfg.referenceDataset.displayName, ...
        etsCfg.referenceDataset, ...
        submapExtList, ...
        false);
    allDatasets = [allDatasets, refDs];

    % 添加 benchmark 数据集
    for i = 1:numel(etsCfg.benchmarkDatasets)
        bmDs = buildDatasetStruct( ...
            etsCfg.benchmarkDatasets(i).displayName, ...
            etsCfg.benchmarkDatasets(i), ...
            submapExtList, ...
            false);
        allDatasets = [allDatasets, bmDs];
    end

    % 处理 INS（如果启用）
    insDataset = [];
    if etsCfg.ins.enable
        insSourceId = etsCfg.ins.sourceDatasetId;
        insSourceCfg = findDatasetById(etsCfg, insSourceId);
        if isempty(insSourceCfg)
            error('[errorTimeSeries] INS sourceDatasetId "%s" 未找到。', insSourceId);
        end
        insDataset = buildDatasetStruct( ...
            insSourceCfg.displayName, ...
            insSourceCfg, ...
            submapExtList, ...
            true);
        insDataset.metrics(1).name = etsCfg.ins.displayName;
    end

    % 展开所有数据集误差
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

    % 添加 INS 表
    if ~isempty(insDataset)
        metric = insDataset.metrics(1);
        metricTable = expandSubmapError(insDataset.name, metric.name, insDataset.submapIds, ...
            insDataset.pingCounts, insDataset.pingIdxStart, metric.errors, pingDt);
        tables{end+1, 1} = metricTable;
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

function datasetStruct = buildDatasetStruct(datasetName, datasetCfg, submapExtList, isInsMode)
    pingCounts = collectPingCounts(datasetCfg.submapDir, submapExtList);
    submapCount = numel(pingCounts);

    [~, trajOriginal] = readTrajectory(datasetCfg.originalPath, 'Mode', 'onlypose');
    if size(trajOriginal, 1) ~= submapCount
        error('[errorTimeSeries:%s] 轨迹行数(%d)与子地图数量(%d)不一致。', datasetName, size(trajOriginal, 1), submapCount);
    end

    datasetStruct = struct();
    datasetStruct.name = datasetName;
    datasetStruct.submapIds = (1:submapCount).';
    datasetStruct.pingCounts = pingCounts;
    datasetStruct.pingIdxStart = computePingIndexStart(pingCounts);

    if isInsMode
        % INS 模式：计算 insPath vs originalPath
        if ~isfield(datasetCfg, 'insPath') || isempty(datasetCfg.insPath)
            error('[errorTimeSeries:%s] INS 模式需要 insPath。', datasetName);
        end
        [~, trajIns] = readTrajectory(datasetCfg.insPath, 'Mode', 'onlypose');
        assertTrajectoryLength(trajOriginal, trajIns, 'INS');
        xyError = computeXYError(trajIns, trajOriginal);
        datasetStruct.metrics = struct('name', {'INS'}, 'errors', {xyError});
    else
        % 普通模式：计算 slamPath vs originalPath
        [~, trajSlam] = readTrajectory(datasetCfg.slamPath, 'Mode', 'onlypose');
        assertTrajectoryLength(trajOriginal, trajSlam, 'SLAM');
        xyError = computeXYError(trajSlam, trajOriginal);
        datasetStruct.metrics = struct('name', {datasetName}, 'errors', {xyError});
    end
end

function dsCfg = findDatasetById(etsCfg, targetId)
    if strcmp(etsCfg.referenceDataset.id, targetId)
        dsCfg = etsCfg.referenceDataset;
        return;
    end
    for i = 1:numel(etsCfg.benchmarkDatasets)
        if strcmp(etsCfg.benchmarkDatasets(i).id, targetId)
            dsCfg = etsCfg.benchmarkDatasets(i);
            return;
        end
    end
    dsCfg = [];
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
    % 基础字段校验
    requiredFields = {'enable', 'pingDt', 'outputDir', 'outputMat', 'saveData', ...
        'referenceDataset', 'benchmarkDatasets', 'ins', 'submapExtList', 'vis'};
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

    % referenceDataset 字段校验
    dsRequiredFields = {'id', 'displayName', 'originalPath', 'slamPath', 'submapDir'};
    for i = 1:numel(dsRequiredFields)
        if ~isfield(etsCfg.referenceDataset, dsRequiredFields{i})
            error('[errorTimeSeries] referenceDataset 缺少字段: %s', dsRequiredFields{i});
        end
    end

    % benchmarkDatasets 校验（允许为空）
    if ~isempty(etsCfg.benchmarkDatasets)
        if ~isstruct(etsCfg.benchmarkDatasets)
            error('[errorTimeSeries] benchmarkDatasets 必须为 struct array 或空数组。');
        end
        for i = 1:numel(etsCfg.benchmarkDatasets)
            for j = 1:numel(dsRequiredFields)
                if ~isfield(etsCfg.benchmarkDatasets(i), dsRequiredFields{j})
                    error('[errorTimeSeries] benchmarkDatasets(%d) 缺少字段: %s', i, dsRequiredFields{j});
                end
            end
        end
    end

    % 收集所有 id 和 displayName，校验唯一性
    allIds = {etsCfg.referenceDataset.id};
    allNames = {etsCfg.referenceDataset.displayName};
    for i = 1:numel(etsCfg.benchmarkDatasets)
        allIds{end+1} = etsCfg.benchmarkDatasets(i).id; %#ok<AGROW>
        allNames{end+1} = etsCfg.benchmarkDatasets(i).displayName; %#ok<AGROW>
    end
    if numel(unique(allIds)) ~= numel(allIds)
        error('[errorTimeSeries] dataset id 存在重复，请确保唯一。');
    end
    if numel(unique(allNames)) ~= numel(allNames)
        error('[errorTimeSeries] dataset displayName 存在重复，请确保唯一。');
    end

    % INS 配置校验
    insFields = {'enable', 'displayName', 'sourceDatasetId'};
    for i = 1:numel(insFields)
        if ~isfield(etsCfg.ins, insFields{i})
            error('[errorTimeSeries] ins 缺少字段: %s', insFields{i});
        end
    end
    if etsCfg.ins.enable
        if any(strcmp(allNames, etsCfg.ins.displayName))
            error('[errorTimeSeries] ins.displayName "%s" 与某个 dataset displayName 冲突。', etsCfg.ins.displayName);
        end
        insSourceCfg = findDatasetById(etsCfg, etsCfg.ins.sourceDatasetId);
        if isempty(insSourceCfg)
            error('[errorTimeSeries] ins.sourceDatasetId "%s" 未匹配任何已配置数据集。', etsCfg.ins.sourceDatasetId);
        end
        if ~isfield(insSourceCfg, 'insPath') || isempty(insSourceCfg.insPath)
            error('[errorTimeSeries] ins 来源数据集 "%s" 缺少 insPath。', insSourceCfg.displayName);
        end
    end

    % 绘图配置校验
    if ~isfield(etsCfg.vis, 'metricOrder') || ~isfield(etsCfg.vis, 'curves')
        error('[errorTimeSeries] vis 缺少 metricOrder 或 curves 字段。');
    end

    % 构造 finalMetrics
    finalMetrics = allNames;
    if etsCfg.ins.enable
        finalMetrics{end+1} = etsCfg.ins.displayName;
    end

    % metricOrder 必须与 finalMetrics 完全一致（顺序可不同）
    metricOrder = etsCfg.vis.metricOrder;
    if ~isequal(sort(metricOrder(:)'), sort(finalMetrics(:)'))
        error('[errorTimeSeries] vis.metricOrder 与实际曲线集合不一致。\n  期望: {%s}\n  实际: {%s}', ...
            strjoin(sort(finalMetrics(:)'), ', '), strjoin(sort(metricOrder(:)'), ', '));
    end

    % vis.curves 每项必须有 metricName，且集合与 finalMetrics 完全一致
    curveNames = cell(1, numel(etsCfg.vis.curves));
    for i = 1:numel(etsCfg.vis.curves)
        if ~isfield(etsCfg.vis.curves(i), 'metricName')
            error('[errorTimeSeries] vis.curves(%d) 缺少 metricName 字段。', i);
        end
        curveNames{i} = etsCfg.vis.curves(i).metricName;
    end
    if numel(unique(curveNames)) ~= numel(curveNames)
        error('[errorTimeSeries] vis.curves 中存在重复的 metricName。');
    end
    if ~isequal(sort(curveNames), sort(finalMetrics(:)'))
        error('[errorTimeSeries] vis.curves 的 metricName 集合与实际曲线集合不一致。\n  期望: {%s}\n  实际: {%s}', ...
            strjoin(sort(finalMetrics(:)'), ', '), strjoin(sort(curveNames), ', '));
    end

    % ins.enable=false 时 metricOrder 中不应出现 ins.displayName
    if ~etsCfg.ins.enable && any(strcmp(metricOrder, etsCfg.ins.displayName))
        error('[errorTimeSeries] ins.enable=false 但 vis.metricOrder 中包含 ins.displayName "%s"。', etsCfg.ins.displayName);
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

