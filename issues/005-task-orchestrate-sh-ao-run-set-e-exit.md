# Bug 005: task-orchestrate.sh `ao run` 失败后 set -e 直接退出

**状态**: 已修复
**严重程度**: 高
**发现日期**: 2026-06-19
**修复提交**: e3a7646

## 问题描述

`task-orchestrate.sh` 中多处使用裸命令后接 `EXIT_CODE=$?`：

```bash
ao run "$WORKFLOW_FILE" 2>&1
EXIT_CODE=$?
```

在 `set -e` 下，`ao run` 一旦失败（exit 非 0），脚本立即退出，后续代码全是死代码。

## 影响

- 失败日志/结果汇总/sliding_window_rollback 自动降级全是死代码
- 失败时最该跑的降级逻辑永不触发
- 用户看不到任务失败原因和降级建议

## 复现步骤

```bash
# 模拟 ao run 失败（例如无 API Key）
bash sofagent/scripts/task-orchestrate.sh "test task"
# 脚本在 ao run 失败时立即退出
# 看不到失败汇总和降级建议
```

## 修复方案

改用 `|| EXIT_CODE=$?` 捕获失败：

```bash
EXIT_CODE=0
ao run "$WORKFLOW_FILE" 2>&1 || EXIT_CODE=$?
```

## 修复代码（3 处）

```diff
- ao run "$WORKFLOW_FILE" 2>&1
- EXIT_CODE=$?
+ EXIT_CODE=0
+ ao run "$WORKFLOW_FILE" 2>&1 || EXIT_CODE=$?
```

## 相关文件

- `sofagent/scripts/task-orchestrate.sh:295` (L4 自主执行)
- `sofagent/scripts/task-orchestrate.sh:253` (L3 模板调度)
- `sofagent/scripts/task-orchestrate.sh:430` (Step 4 执行编排)

## 备注

这是 `set -e` 的经典陷阱：裸命令失败会立即退出，`var=$?` 永远拿不到非 0 值。防御性写法：`EXIT_CODE=0; cmd || EXIT_CODE=$?`
