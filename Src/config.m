%% config - MB-SLAM-EvalToolkit 全局配置入口
%
% 功能描述：
%   统一管理全项目（global/ate/ape/cbee/errorTimeSeries 等）的可视化、保存、
%   输入路径与算法参数，调用一次返回 cfg 结构供各模块复用。
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
%   v1.0 (251118) - 首次整理分层配置
%       + 建立 global/ate/ape/cbee/errorTimeSeries 模块化参数
%       + 引入统一的可视化与保存策略
%
% 输入参数：
%   无（脚本调用即可返回配置）
%
% 输出参数：
%   cfg - struct，包含全项目所需的配置字段
%
% 注意事项：
%   1. 修改参数后需重新执行 config() 以刷新 cfg。
%   2. 路径建议使用 fullfile，以兼容多平台。
%   3. errorTimeSeries 模块依赖新增的 cfg.errorTimeSeries.* 字段。
%
% 调用示例：
%   cfg = config();

function cfg = config()

    cfg = struct();
    
%% === global（全局：含可视化、通用保存

    cfg.global = struct();

    % 可视化参数（全局共享）
    cfg.global.visual = struct();
    cfg.global.visual.font_name           = 'Arial';
    cfg.global.visual.font_size_base      = 8;      % pt

    cfg.global.visual.font_size_multiple  = 3;      % 字体放缩倍数
    cfg.global.visual.figure_size_multiple= 3;      % 图窗放缩倍数

    % 模块专用绘图尺寸（单位：cm）
    cfg.global.visual.figure_sizes = struct();
    cfg.global.visual.figure_sizes.ateTrajectory = struct( ...
        'width_cm', 4.4, ...
        'height_cm', 4.4);
    cfg.global.visual.figure_sizes.ateDistribution = struct( ...
        'width_cm', 8.8, ...
        'height_cm', 8.8);
    cfg.global.visual.figure_sizes.apeComparison = struct( ...
        'width_cm', 8.8, ...
        'height_cm', 4.4);
    cfg.global.visual.figure_sizes.errorTimeSeries = struct( ...
        'width_cm', 8.8, ...
        'height_cm', 4.4);
    cfg.global.visual.figure_sizes.cbee = struct( ...
        'width_cm', 4.4, ...
        'height_cm', 4.4);
    cfg.global.visual.figure_width_cm     = 4.4;    % cm 无设置的默认宽度
    cfg.global.visual.figure_height_cm    = 4.4;    % cm 无设置的默认高度


    % 轨迹样式（全局共享）
    cfg.global.visual.gt_color            = [25, 158, 34]/255;  % 绿色 rgb(25,158,34)
    cfg.global.visual.gt_line_style       = '-';
    cfg.global.visual.gt_line_width       = 1.5;

    cfg.global.visual.corrupted_color     = [255, 66, 37]/255;  % 红色 rgb(255,66,37)
    cfg.global.visual.corrupted_line_style= '-';
    cfg.global.visual.corrupted_line_width= 1.5;

    cfg.global.visual.optimized_color     = [58, 104, 231]/255;  % 蓝色 rgb(58,104,231)
    cfg.global.visual.optimized_line_style= '-';
    cfg.global.visual.optimized_line_width= 1.5;

    cfg.global.visual.est_color           = cfg.global.visual.corrupted_color;  % 与corrupted_color相同
    cfg.global.visual.est_line_style      = '-';
    cfg.global.visual.trajectory_line_width = 1.5;

    % 关键帧标记样式
    cfg.global.visual.keyframe_marker = struct();
    cfg.global.visual.keyframe_marker.enable        = true;
    cfg.global.visual.keyframe_marker.symbol        = 'o';
    cfg.global.visual.keyframe_marker.size          = 2.5;
    cfg.global.visual.keyframe_marker.face_color    = []; % 实际绘制时使用轨迹颜色
    cfg.global.visual.keyframe_marker.edge_width    = 0.8;


    % 通用保存
    cfg.global.save = struct();
    cfg.global.save.enable    = true;
    cfg.global.save.figures   = true;
    cfg.global.save.data      = true;
    cfg.global.save.formats   = {'png','eps'};
    cfg.global.save.dpi       = 600;
    cfg.global.save.timestamp = 'yyyymmdd_HHMMSS';  % 格式：yyyymmdd_HHMMSS

%% === errorTimeSeries（误差时间序列模块） ===
    cfg.errorTimeSeries = struct();
    cfg.errorTimeSeries.enable    = true;
    cfg.errorTimeSeries.pingDt    = 0.003;
    cfg.errorTimeSeries.outputDir = 'Results/ErrorTimeSeries';
    cfg.errorTimeSeries.outputMat = fullfile(cfg.errorTimeSeries.outputDir, 'ping_error.mat');
    cfg.errorTimeSeries.savePlot  = true;
    cfg.errorTimeSeries.truncateToCommonRange = true;

    cfg.errorTimeSeries.comb = struct( ...
        'originalPath', 'Data/250911_Comb_noINS/Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_original.txt', ...
        'insPath',      'Data/250911_Comb_noINS/Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_corrupted.txt', ...
        'slamPath',     'Data/250911_Comb_noINS/Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_optimized.txt', ...
        'submapDir',    'Data/250911_Comb_noINS/submaps');

    cfg.errorTimeSeries.nesp = struct( ...
        'originalPath', 'Data/251111_NESP_noINS/NESP_noINS_seed20_yaw_0.05_0.005rad_overlap_coverage_0.6/poses_original.txt', ...
        'slamPath',     'Data/251111_NESP_noINS/NESP_noINS_seed20_yaw_0.05_0.005rad_overlap_coverage_0.6/poses_optimized.txt', ...
        'submapDir',    'Data/251111_NESP_noINS/submaps');

    cfg.errorTimeSeries.submapExtList = {'.pcd', '.pdc'};

    cfg.errorTimeSeries.vis = struct();
    cfg.errorTimeSeries.vis.curves = struct();
    cfg.errorTimeSeries.vis.curves.INS = struct( ...
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
        'ylabel', 'Position Error (m)', ...
        'ylim',   []);

%% === ate（ATE 模块） ===
    cfg.ate = struct();

    % 输入与辅助参数
    cfg.ate.paths = struct();

    % ATE 主流程输入文件夹与标准文件名
    % cfg.ate.paths.input_folder = 'Data\250911_Comb_noINS\Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5';
    cfg.ate.paths.input_folder = 'Data\251111_NESP_noINS\NESP_noINS_seed20_yaw_0.05_0.005rad_overlap_coverage_0.6';

    cfg.ate.paths.gt_file_name         = 'poses_original.txt';
    cfg.ate.paths.est_corrupted_name   = 'poses_corrupted.txt';
    cfg.ate.paths.est_optimized_name   = 'poses_optimized.txt';
    
    % ATE 输出路径配置
    cfg.ate.paths.output_data = 'Results/ATE/ATE_data';
    cfg.ate.paths.output_distributions = 'Results/ATE/ATE_distributions';
    
    % 可视化/分析参数
    cfg.ate.histogram_bins = 50;

    % ATE 分布（BoxViolin）输入
    cfg.ate.paths.boxviolin_files      = {
        'Data\251111_NESP_noINS\20251113_174148_ATE_data\ate_details_optimized.csv', ...
        'Data\250911_Comb_noINS\20251113_174602_ATE_data\ate_details_optimized.csv'
    };

    % 标签/绘图辅助
    cfg.ate.labels = {'NESP', 'Comb'};

    % 保存
    cfg.ate.save = struct();
    cfg.ate.save.enable = true;

%% === ape（APE 模块） ===
    cfg.ape = struct();

    % 输入路径
    cfg.ape.paths = struct();

    % % NESP数据文件路径    
    % cfg.ape.paths.nesp_slam = 'Data/250911_NESP_noINS/NESP_noINS_seed40_yaw_0.05_0.005rad/poses_optimized.txt';
    % cfg.ape.paths.nesp_gt   = 'Data/250911_NESP_noINS/NESP_noINS_seed40_yaw_0.05_0.005rad/poses_original.txt';

    cfg.ape.paths.nesp_slam = 'Data/251111_NESP_noINS/NESP_noINS_seed20_yaw_0.05_0.005rad_overlap_coverage_0.6/poses_optimized.txt';
    cfg.ape.paths.nesp_gt   = 'Data/251111_NESP_noINS/NESP_noINS_seed20_yaw_0.05_0.005rad_overlap_coverage_0.6/poses_original.txt';

    cfg.ape.paths.comb_slam = 'Data/250911_Comb_noINS/Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_optimized.txt';
    cfg.ape.paths.comb_gt   = 'Data/250911_Comb_noINS/Comb_noINS_seed40_yaw_0.05_0.005rad_overlapcoverage_0.5/poses_original.txt';

    % APE 输出路径配置
    cfg.ape.paths.output_visualization = 'Results/APE/APE_visualization';

    % 选项/绘图
    cfg.ape.options = struct();
    cfg.ape.options.enable_alignment = true;
    cfg.ape.plot = struct();
    cfg.ape.plot.legend_labels = {'NESP', 'Comb'};

    % 保存
    cfg.ape.save = struct();
    cfg.ape.save.enable = true;

    %% === cbee（CBEE 模块） ===
    cfg.cbee = struct();

    % 路径
    cfg.cbee.paths = struct();

    cfg.cbee.paths.gt_pcd_dir       = 'Data/251111_NESP_noINS/submaps';
    cfg.cbee.paths.poses_original   = 'Data/251111_NESP_noINS/NESP_noINS_seed20_yaw_0.05_0.005rad_overlap_coverage_0.6/poses_original.txt';
    cfg.cbee.paths.poses_optimized  = 'Data/251111_NESP_noINS/NESP_noINS_seed20_yaw_0.05_0.005rad_overlap_coverage_0.6/poses_optimized.txt';
    cfg.cbee.paths.poses_corrupted  = 'Data/251111_NESP_noINS/NESP_noINS_seed20_yaw_0.05_0.005rad_overlap_coverage_0.6/poses_corrupted.txt';


    % CBEE 输出路径配置
    cfg.cbee.paths.output_data_results = 'Results/CBEE/CBEE_data_results';
    cfg.cbee.paths.output_optimized_submaps = 'Results/CBEE/CBEE_optimized_submaps';

    % 算法参数
    cfg.cbee.cell_size_xy        = 1;  % 栅格边长(米)。建议 0.5~2.0，越小越精，但计算量增大。
    cfg.cbee.neighborhood_size   = 3; % 误差计算的邻域尺寸(k×k，奇数)。常用 3 或 5。
    cfg.cbee.nbr_averages        = 5; % 单格重复随机采样次数(蒙特卡洛平均)。数值越大越稳定但更慢。 原参数 10        
    cfg.cbee.min_points_per_cell = 3; % 参与误差计算的最小点数阈值。小于该值时该格的一致性误差记为 NaN。
    cfg.cbee.use_parallel        = true; % 是否在格级启用并行(parfor)。数据量大时建议开启。
    cfg.cbee.num_workers         = []; % int/[] 并行工作线程数；[] 表示由 MATLAB 自动管理。
    cfg.cbee.random_seed         = 42; % 随机种子，便于复现实验；[] 表示不固定。

    % 高程插值与掩码参数
    cfg.cbee.elevation_method      = 'mean';   % 'mean'|'median'|'max'|'min' 格内高程聚合方法
    cfg.cbee.elevation_interp      = 'linear'; % 'none'|'linear'|'nearest'|'natural' 高程插值方法
    cfg.cbee.elevation_smooth_win  = 0;        % int>=0 高程平滑窗口大小(奇数),0表示不平滑
    cfg.cbee.elevation_mask_enable = true;     % bool 是否启用距离掩码,避免过度插值产生假数据
    cfg.cbee.elevation_mask_radius = 2.0;      % double>0 掩码半径(格子单位):只保留距真实数据该范围内的插值结果

    % 可视化
    cfg.cbee.visualize = struct();
    cfg.cbee.visualize.enable                  = true; % 是否在流程中进行可视化
    cfg.cbee.visualize.colormap                = 'jet'; % 误差/高程图的色图(如 'parula'/'jet' 等)
    cfg.cbee.visualize.plot_individual_submaps = false; % 是否单独绘制每幅子地图
    cfg.cbee.visualize.sample_rate             = 0.2; % 子地图可视化采样率，降低绘制点数以提高速度

    % 处理选项
    cfg.cbee.options = struct();
    cfg.cbee.options.generate_optimized_submaps = true; % 是否先基于轨迹生成“优化子地图”
    cfg.cbee.options.skip_optimized_submaps     = false; % 是否跳过优化子地图生成(覆盖generate_optimized_submaps)
    cfg.cbee.options.submap_pose_mode           = 'optimized'; % 'optimized' 使用优化位姿, 'corrupted' 使用扰动位姿
    cfg.cbee.options.save_optimized_submaps     = true; % 是否将优化后的子地图持久化到磁盘
    cfg.cbee.options.save_CBEE_data_results     = true; % 是否导出 CBEE 结果(图片/CSV/MAT)
    cfg.cbee.options.load_only                  = false; % 仅加载数据，不执行 CBEE 计算与导出。
    cfg.cbee.options.distance_method    = 'bruteforce'; % 'bruteforce' | 'kdtree'
    cfg.cbee.options.kdtree_min_points  = 20;           % 构建 KD 树的最小点数
    % 预留: 未来可增加 cfg.cbee.options.strict_random = false; 以在并行下保持严格复现

end
