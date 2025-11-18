%% getFigureSize - 全局/模块绘图尺寸解析工具
%
% 功能描述：
%   根据 cfg.global.visual 及可选的模块 key 计算最终绘图尺寸（cm），
%   支持模块级覆盖与全局倍数统一缩放，供所有入口脚本保持一致风格。
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
%       + 支持全局倍数缩放
%       + 支持 figure_sizes.* 覆盖模块尺寸
%       + 提供默认宽高回退逻辑
%
% 输入参数：
%   visualCfg     - struct，config().global.visual 结构
%   key           - string，可选，指定 figure_sizes 中的字段名
%   defaultWidth  - double，可选，默认宽度（cm）
%   defaultHeight - double，可选，默认高度（cm）
%
% 输出参数：
%   width_cm, height_cm - double，最终计算得到的宽/高（cm）
%
% 注意事项：
%   1. 若 key 为空或未命中 figure_sizes，将使用全局默认尺寸。
%   2. 所有返回尺寸都会乘以 visualCfg.figure_size_multiple。
%   3. defaultWidth / defaultHeight 主要用于特殊调用场景的回退。
%
% 调用示例：
%   [w, h] = getFigureSize(cfg.global.visual, 'errorTimeSeries');
%
% 依赖关系：
%   无（内部仅使用 MATLAB 基础语法）

function [width_cm, height_cm] = getFigureSize(visualCfg, key, defaultWidth, defaultHeight)

    multiplier = visualCfg.figure_size_multiple;

    if nargin < 3 || isempty(defaultWidth)
        defaultWidth = visualCfg.figure_width_cm;
    end
    if nargin < 4 || isempty(defaultHeight)
        defaultHeight = visualCfg.figure_height_cm;
    end

    width_cm = defaultWidth;
    height_cm = defaultHeight;

    if nargin < 2 || isempty(key)
        width_cm  = width_cm  * multiplier;
        height_cm = height_cm * multiplier;
        return;
    end

    if isfield(visualCfg, 'figure_sizes') && isfield(visualCfg.figure_sizes, key)
        sizeCfg = visualCfg.figure_sizes.(key);
        if isfield(sizeCfg, 'width_cm') && ~isempty(sizeCfg.width_cm)
            width_cm = sizeCfg.width_cm;
        end
        if isfield(sizeCfg, 'height_cm') && ~isempty(sizeCfg.height_cm)
            height_cm = sizeCfg.height_cm;
        end
    end

    width_cm  = width_cm  * multiplier;
    height_cm = height_cm * multiplier;
end

