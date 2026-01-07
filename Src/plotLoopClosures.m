%% plotLoopClosures - 可视化回环约束网络
% 文件输入：位姿文件（poses_*.txt）、回环文件（loop_closures.txt）
% 文件输出：回环约束可视化图（png/eps，论文级导出）
% 文件地位：核心绘图模块，实现关键帧节点、里程计边、回环边的可视化
%
% 功能描述：
%   读取关键帧位姿与回环约束数据，绘制：
%   1. 关键帧节点（尺寸按回环度数映射）
%   2. 里程计边（顺序连接）
%   3. 回环边（来自 loop_closures.txt）
%   按 /paper-visual 规范导出（尺寸/字体等比放大，600 dpi，png+eps）
%
% 输入参数：
%   pose_file_path  - (string) 位姿文件完整路径
%   loop_file_path  - (string) 回环数据文件完整路径
%   cfg             - (struct) 配置结构（来自 config()）
%   varargin        - Name-Value 参数对
%                     'SaveDir' - 输出目录（默认使用 cfg.loop.paths.output_folder）
%                     'SaveEnable' - 是否保存（默认使用 cfg.loop.save.enable）
%
% 输出参数：
%   fig_handle      - (figure handle) 生成的图窗句柄
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
% 调用示例：
%   cfg = config();
%   pose_path = fullfile(cfg.loop.paths.input_folder, cfg.loop.paths.pose_file);
%   loop_path = fullfile(cfg.loop.paths.input_folder, cfg.loop.paths.loop_file);
%   fig = plotLoopClosures(pose_path, loop_path, cfg);

function fig_handle = plotLoopClosures(pose_file_path, loop_file_path, cfg, varargin)

%% 参数解析
    p = inputParser;
    addParameter(p, 'SaveDir', cfg.loop.paths.output_folder, @ischar);
    addParameter(p, 'SaveEnable', cfg.loop.save.enable, @islogical);
    parse(p, varargin{:});
    
    save_dir = p.Results.SaveDir;
    save_enable = p.Results.SaveEnable;

%% 读取位姿数据
    fprintf('正在读取位姿数据: %s\n', pose_file_path);
    if ~isfile(pose_file_path)
        error('位姿文件不存在: %s', pose_file_path);
    end
    
    % 使用 readTrajectory 读取位姿（仅需要位置）
    [~, positions, ~] = readTrajectory(pose_file_path, 'Mode', 'onlypose');
    num_keyframes = size(positions, 1);
    fprintf('成功读取 %d 个关键帧位姿\n', num_keyframes);

%% 读取并解析回环数据
    fprintf('正在读取回环数据: %s\n', loop_file_path);
    if ~isfile(loop_file_path)
        error('回环文件不存在: %s', loop_file_path);
    end
    
    % 解析回环文件，返回无向边集合
    loop_edges = parseLoopClosures(loop_file_path, num_keyframes);
    fprintf('成功解析 %d 条回环边\n', size(loop_edges, 1));

%% 统计节点回环度数（无向计数）
    loop_degrees = zeros(num_keyframes, 1);
    for i = 1:size(loop_edges, 1)
        id1 = loop_edges(i, 1);
        id2 = loop_edges(i, 2);
        loop_degrees(id1) = loop_degrees(id1) + 1;
        loop_degrees(id2) = loop_degrees(id2) + 1;
    end
    fprintf('节点回环度数统计完成（最大度数: %d）\n', max(loop_degrees));

%% 计算节点尺寸映射
    node_sizes = cfg.loop.visual.node_base_size + ...
                 cfg.loop.visual.node_scale_factor * loop_degrees;
    
    % 限制尺寸范围
    node_sizes = max(node_sizes, cfg.loop.visual.node_min_size);
    node_sizes = min(node_sizes, cfg.loop.visual.node_max_size);

%% 构建里程计边（顺序连接）
    odom_edges = [(1:num_keyframes-1)', (2:num_keyframes)'];
    fprintf('构建 %d 条里程计边\n', size(odom_edges, 1));

%% 创建图窗并应用论文级可视化规范
    % 计算实际尺寸（基准尺寸 × 放大倍数）
    actual_width_cm = cfg.loop.visual.figure_width_cm * ...
                      cfg.loop.visual.figure_size_multiple;
    actual_height_cm = cfg.loop.visual.figure_height_cm * ...
                       cfg.loop.visual.figure_size_multiple;
    
    % 创建图窗并设置物理尺寸
    fig_handle = figure('Units', 'centimeters', ...
                        'Position', [5, 5, actual_width_cm, actual_height_cm], ...
                        'Color', 'w', ...
                        'PaperUnits', 'centimeters', ...
                        'PaperSize', [actual_width_cm, actual_height_cm], ...
                        'PaperPosition', [0, 0, actual_width_cm, actual_height_cm]);
    
    ax = axes('Parent', fig_handle, ...
              'Units', 'normalized', ...
              'Position', [0.12, 0.12, 0.82, 0.82]); % 预留边距
    
    hold(ax, 'on');

%% 绘制里程计边
    for i = 1:size(odom_edges, 1)
        id1 = odom_edges(i, 1);
        id2 = odom_edges(i, 2);
        plot(ax, [positions(id1, 1), positions(id2, 1)], ...
                 [positions(id1, 2), positions(id2, 2)], ...
                 'Color', cfg.loop.visual.odom_color, ...
                 'LineStyle', cfg.loop.visual.odom_line_style, ...
                 'LineWidth', cfg.loop.visual.odom_line_width);
    end

%% 绘制回环边
    for i = 1:size(loop_edges, 1)
        id1 = loop_edges(i, 1);
        id2 = loop_edges(i, 2);
        plot(ax, [positions(id1, 1), positions(id2, 1)], ...
                 [positions(id1, 2), positions(id2, 2)], ...
                 'Color', cfg.loop.visual.loop_color, ...
                 'LineStyle', cfg.loop.visual.loop_line_style, ...
                 'LineWidth', cfg.loop.visual.loop_line_width);
    end

%% 绘制关键帧节点（按度数调整尺寸）
    scatter(ax, positions(:, 1), positions(:, 2), ...
            node_sizes, ...
            'MarkerFaceColor', cfg.loop.visual.node_color, ...
            'MarkerEdgeColor', cfg.loop.visual.node_color, ...
            'LineWidth', cfg.loop.visual.node_edge_width, ...
            'Marker', cfg.loop.visual.node_marker);

%% 设置坐标轴与论文级字体
    axis(ax, 'equal');
    grid(ax, 'off');
    box(ax, 'off');
    
    % 计算实际字号（基准字号 × 放大倍数）
    actual_font_size = cfg.loop.visual.font_size_base * ...
                       cfg.loop.visual.font_size_multiple;
    
    % 统一字体设置（轴标签、刻度）
    xlabel(ax, 'X (m)', 'FontName', cfg.loop.visual.font_name, ...
           'FontSize', actual_font_size);
    ylabel(ax, 'Y (m)', 'FontName', cfg.loop.visual.font_name, ...
           'FontSize', actual_font_size);
    set(ax, 'FontName', cfg.loop.visual.font_name, ...
            'FontSize', actual_font_size, ...
            'TickDir', 'out', ...
            'LineWidth', 1.0);
    
    % 紧凑布局
    set(ax, 'LooseInset', get(ax, 'TightInset'));
    
    hold(ax, 'off');
    
    fprintf('回环可视化绘制完成\n');

%% 导出图像（论文级规范：600 dpi，png+eps）
    if save_enable
        % 确保输出目录存在
        if ~isfolder(save_dir)
            mkdir(save_dir);
            fprintf('创建输出目录: %s\n', save_dir);
        end
        
        % 生成时间戳文件名
        timestamp = datestr(now, cfg.global.save.timestamp);
        base_filename = sprintf('%s_loop_closures', timestamp);
        
        % 导出各种格式
        for i = 1:length(cfg.loop.save.formats)
            fmt = cfg.loop.save.formats{i};
            output_path = fullfile(save_dir, [base_filename, '.', fmt]);
            
            switch lower(fmt)
                case 'png'
                    % 位图导出（高分辨率）
                    print(fig_handle, output_path, '-dpng', ...
                          sprintf('-r%d', cfg.loop.save.dpi));
                case 'eps'
                    % 矢量导出
                    print(fig_handle, output_path, '-depsc', ...
                          sprintf('-r%d', cfg.loop.save.dpi));
                otherwise
                    warning('不支持的导出格式: %s', fmt);
            end
            
            fprintf('已导出: %s\n', output_path);
        end
    end

end

%% 辅助函数：解析回环文件
function loop_edges = parseLoopClosures(loop_file_path, num_keyframes)
% 解析回环文件并返回无向边集合（过滤自环）
%
% 数据格式要求（单向记录）：
%   采用"大ID→小ID"记录方式，每行格式为：
%   <当前子图ID> <比它小的回环子图ID1> <比它小的回环子图ID2> ...
%
% 输入格式示例：
%   17 14 15       ← 节点17与节点14、15有回环
%   18 13 14       ← 节点18与节点13、14有回环
%   121 85 92 115 116 117 118  ← 节点121与多个小ID节点有回环
%
% 说明：
%   此格式天然保证边的唯一性（每条边只从大ID端记录一次），无需去重。
%
% 输出：
%   loop_edges - (Mx2 double) 无向边列表 [id1, id2]，id1 < id2

    % 读取文件所有行
    fid = fopen(loop_file_path, 'r');
    if fid == -1
        error('无法打开回环文件: %s', loop_file_path);
    end
    
    % 存储所有边（临时）
    edges_temp = [];
    
    line_num = 0;
    while ~feof(fid)
        line = fgetl(fid);
        line_num = line_num + 1;
        
        % 跳过空行和注释行
        if isempty(line) || ischar(line) && (isempty(strtrim(line)) || startsWith(strtrim(line), '#'))
            continue;
        end
        
        % 解析数字
        nums = str2num(line); %#ok<ST2NM>
        if isempty(nums) || length(nums) < 2
            warning('第 %d 行格式不正确，已跳过: %s', line_num, line);
            continue;
        end
        
        current_id = nums(1);
        loop_ids = nums(2:end);
        
        % 验证ID范围
        if current_id < 0 || current_id >= num_keyframes
            warning('第 %d 行：当前ID %d 超出范围 [0, %d)，已跳过', ...
                    line_num, current_id, num_keyframes);
            continue;
        end
        
        % 为每个回环ID创建边（MATLAB索引从1开始）
        for i = 1:length(loop_ids)
            loop_id = loop_ids(i);
            
            % 验证回环ID范围
            if loop_id < 0 || loop_id >= num_keyframes
                warning('第 %d 行：回环ID %d 超出范围 [0, %d)，已跳过', ...
                        line_num, loop_id, num_keyframes);
                continue;
            end
            
            % 过滤自环
            if current_id == loop_id
                continue;
            end
            
            % 统一为 MATLAB 索引（+1）并保证 id1 < id2
            id1 = min(current_id, loop_id) + 1;
            id2 = max(current_id, loop_id) + 1;
            
            edges_temp = [edges_temp; id1, id2]; %#ok<AGROW>
        end
    end
    
    fclose(fid);
    
    % 说明：本工具假设输入数据采用"大ID→小ID"单向记录格式，天然保证边的唯一性，
    %       无需执行去重操作。代码已通过 min/max 统一边的方向为 (id1 < id2)。
    %       若数据来源采用双向记录格式，建议在此处添加：
    %       loop_edges = unique(edges_temp, 'rows');
    loop_edges = edges_temp;
    
    fprintf('解析完成: %d 行数据，%d 条有效回环边\n', ...
            line_num, size(loop_edges, 1));
end
