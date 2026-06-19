# Bug 002: task-orchestrate.sh shasum 无 sha256sum 回退

**状态**: 已修复
**严重程度**: 中
**发现日期**: 2026-06-19
**修复提交**: (待提交)

## 问题描述

`task-orchestrate.sh:112` 使用 `shasum -a 256` 生成任务唯一标识（TASK_SLUG），但缺少 `sha256sum` 回退：

```bash
TASK_SLUG=$(echo "$TASK_DESC" | shasum -a 256 2>/dev/null | cut -c1-8 || echo "unknown")
```

## 影响

- 在精简 Linux 环境（Alpine、无 perl 的容器）上，shasum 不可用
- Pipeline 失败 → TASK_SLUG 恒为 `"unknown"`
- 所有任务共享同一 slug → 缓存碰撞 + 历史分析错乱
- `analyze_track_record()` 和 `sliding_window_rollback()` 分析错误任务的历史数据

## 复现步骤

```bash
# 在无 shasum 的环境中运行
docker run --rm -it alpine:latest
apk add bash git
cd /workspace
bash sofagent/scripts/task-orchestrate.sh "test task"
# 所有任务的 TASK_SLUG 都是 "unknown"
```

## 修复方案

与 `load-chain.sh:90` 的 `hash_stdin()` 对齐，添加 `sha256sum` 回退：

```bash
TASK_SLUG=$(echo "$TASK_DESC" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | cut -c1-8 || echo "unknown")
```

## 修复代码

```diff
- TASK_SLUG=$(echo "$TASK_DESC" | shasum -a 256 2>/dev/null | cut -c1-8 || echo "unknown")
+ # 修复：shasum 缺失时用 sha256sum 回退（与 load-chain.sh hash_stdin 对齐）
+ TASK_SLUG=$(echo "$TASK_DESC" | { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null; } | cut -c1-8 || echo "unknown")
```

## 相关文件

- `sofagent/scripts/task-orchestrate.sh:112`
- `sofagent/scripts/load-chain.sh:90` (参考实现)

## 备注

此 bug 与已修复的 Bug 004（load-chain.sh stdin 消费问题）属于同一类问题：跨平台哈希工具兼容性。
