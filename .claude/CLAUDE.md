## 通知功能配置

### Bark 推送配置
* Bark URL: `https://api.day.app/x2QYYwV9RjQ84soB9Mvws6`

### 主动通知场景
AI 应该在以下场景主动发送通知：
1. **长时间任务完成** - 构建、测试、部署等耗时任务完成时
2. **需要用户确认** - 重要决策或需要用户介入时（使用 `-Call` 参数持续响铃）
3. **重要里程碑** - 代码审查完成、PR 创建成功等
4. **错误警报** - 构建失败、测试未通过等异常情况

### 发送通知方法
使用 Bash 工具调用 bark.ps1 脚本：

```powershell
# 基础通知
powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Users/Chihong/.claude/plugins/cache/claude-notification/windows/2.0.0/skills/notification-config/scripts/bark.ps1" -Url "https://api.day.app/x2QYYwV9RjQ84soB9Mvws6" -Title "Claude Code" -Message "任务完成"

# 紧急通知（持续响铃30秒）
powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Users/Chihong/.claude/plugins/cache/claude-notification/windows/2.0.0/skills/notification-config/scripts/bark.ps1" -Url "https://api.day.app/x2QYYwV9RjQ84soB9Mvws6" -Title "Claude Code" -Message "需要确认" -Call

# 分组通知
powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Users/Chihong/.claude/plugins/cache/claude-notification/windows/2.0.0/skills/notification-config/scripts/bark.ps1" -Url "https://api.day.app/x2QYYwV9RjQ84soB9Mvws6" -Title "构建完成" -Message "项目构建成功" -Group "build"
```

### 使用原则
* 在用户明确要求通知时发送
* 完成重要任务后主动发送（如代码审查、PR创建、长时间构建等）
* 紧急情况使用 `-Call` 参数
* 相关任务使用 `-Group` 参数分组
