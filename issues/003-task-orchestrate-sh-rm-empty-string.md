# Bug 003: task-orchestrate.sh `rm -f ""` 在 set -e 下崩溃

**状态**: 已修复
**严重程度**: 中
**发现日期**: 2026-06-19
**修复提交**: (待提交)

## 问题描述

`task-orchestrate.sh:466` 清理临时文件时：

```bash
rm -f "$WORKFLOW_FILE" "${SOFAGENT_CONSTRAINT_FILE:-}"
```

当 Harness 约束注入被跳过/失败时（lines 404-420），`SOFAGENT_CONSTRAINT_FILE` 未设置，`${SOFAGENT_CONSTRAINT_FILE:-}` 展开为空串。

## 影响

- `rm -f ""` 在 GNU coreutils 返回 exit 1（参数为空）
- `set -e` 下脚本立即崩溃
- 跳过最终汇总输出（lines 468-473）
- 用户看不到任务执行结果和编排深度

## 复现步骤

```bash
# 场景 1: Harness 约束注入失败（HOOK_PATH 不存在）
# 场景 2: 约束块为空（constraint_block 为空）
# 两种情况下 SOFAGENT_CONSTRAINT_FILE 都不会设置
bash sofagent/scripts/task-orchestrate.sh "test task"
# 脚本在 line 466 崩溃，看不到最终汇总
```

## 修复方案

分拆 rm 命令，仅在约束文件存在时才删除：

```bash
rm -f "$WORKFLOW_FILE"
[ -n "${SOFAGENT_CONSTRAINT_FILE:-}" ] && rm -f "$SOFAGENT_CONSTRAINT_FILE"
```

## 修复代码

```diff
- rm -f "$WORKFLOW_FILE" "${SOFAGENT_CONSTRAINT_FILE:-}"
+ rm -f "$WORKFLOW_FILE"
+ [ -n "${SOFAGENT_CONSTRAINT_FILE:-}" ] && rm -f "$SOFAGENT_CONSTRAINT_FILE"
```

## 相关文件

- `sofagent/scripts/task-orchestrate.sh:466`
- `sofagent/scripts/task-orchestrate.sh:404-420` (约束注入逻辑)

## 备注

这是 `set -e` 与命令参数展开的经典陷阱。类似问题的防御性写法：
- 使用条件判断：`[ -n "$var" ] && cmd "$var"`
- 或使用数组：`args=("$WORKFLOW_FILE"); [ -n "${SOFAGENT_CONSTRAINT_FILE:-}" ] && args+=("$SOFAGENT_CONSTRAINT_FILE"); rm -f "${args[@]}"`
