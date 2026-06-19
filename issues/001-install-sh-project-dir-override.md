# Bug 001: install.sh `--project-dir` 被静默覆盖

**状态**: 已修复
**严重程度**: 高
**发现日期**: 2026-06-19
**修复提交**: (待提交)

## 问题描述

`install.sh` 在 line 113 正确设置 `SOFAGENT_DATA="${SOFAGENT_DATA:-${PROJECT_DIR}/.sofagent}"`，但在 line 414（OpenClaw Step 6 内）硬覆盖为 `SOFAGENT_DATA="${PWD}/.sofagent"`。

## 影响

- `--project-dir` 参数指定的数据目录位置被忽略
- 数据目录始终创建在 PWD（当前工作目录）
- 安装完成 summary（line 588）显示错误路径
- 用户指定的 `--project-dir ~/my-project` 无效，数据目录仍在执行 install.sh 时的 PWD

## 复现步骤

```bash
cd /tmp
bash sofagent/scripts/install.sh --platform openclaw --project-dir ~/my-project
# 期望: 数据目录在 ~/my-project/.sofagent/
# 实际: 数据目录在 /tmp/.sofagent/
```

## 修复方案

删除 line 414 的重复赋值，复用 line 113 已定义的 `SOFAGENT_DATA` 变量。

## 修复代码

```diff
- SOFAGENT_DATA="${PWD}/.sofagent"
  if [ ! -d "$SOFAGENT_DATA" ]; then
    mkdir -p "$SOFAGENT_DATA/task/logs" "$SOFAGENT_DATA/orchestrator/workflows"
```

## 相关文件

- `sofagent/scripts/install.sh:113` (正确定义)
- `sofagent/scripts/install.sh:414` (错误覆盖)
- `sofagent/scripts/install.sh:588` (summary 显示错误路径)
