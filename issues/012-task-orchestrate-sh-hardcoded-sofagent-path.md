# Bug 012: task-orchestrate.sh 硬编码 .sofagent 忽略 SOFAGENT_DATA 环境变量

**状态**: 已修复
**严重程度**: 低
**发现日期**: 2026-06-19
**修复提交**: a145761

## 问题描述

`task-orchestrate.sh` 多处硬编码 `.sofagent` 路径：

```bash
SOFAGENT_DATA="${PWD}/.sofagent"
```

未尊重 `SOFAGENT_DATA` 环境变量，与 `install.sh --project-dir` 和 `load-chain.sh` 不对齐。

## 影响

- 用户指定 `--project-dir` 后，`task-orchestrate.sh` 仍读取 PWD/.sofagent
- 数据目录不一致，任务记录写错位置
- 编排缓存和历史分析读取错误数据

## 复现步骤

```bash
# 指定项目目录
bash sofagent/scripts/install.sh --project-dir ~/my-project
cd ~/my-project
bash sofagent/scripts/task-orchestrate.sh "test task"
# 期望: 读取 ~/my-project/.sofagent/
# 实际: 读取 $(pwd)/.sofagent/
```

## 修复方案

改为 `${SOFAGENT_DATA:-${PWD}/.sofagent}`，与 install/load-chain 对齐：

```bash
SOFAGENT_DATA="${SOFAGENT_DATA:-${PWD}/.sofagent}"
```

## 修复代码

```diff
- SOFAGENT_DATA="${PWD}/.sofagent"
+ # honor SOFAGENT_DATA 环境变量（与 install.sh --project-dir / load-chain.sh 对齐）；缺省回退 PWD
+ SOFAGENT_DATA="${SOFAGENT_DATA:-${PWD}/.sofagent}"
```

## 相关文件

- `sofagent/scripts/task-orchestrate.sh:116` (修复后)
- `sofagent/scripts/install.sh:113` (参考实现)
- `sofagent/scripts/load-chain.sh:68` (参考实现)

## 备注

数据目录路径应统一使用 `${SOFAGENT_DATA:-${PWD}/.sofagent}`，确保：
1. 尊重环境变量（用户可覆盖）
2. 缺省回退 PWD（向后兼容）
3. 与 install.sh --project-dir 对齐
