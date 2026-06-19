# Bug 013: install.sh .sofagent/ 数据目录位置依赖 PWD

**状态**: 已修复
**严重程度**: 中
**发现日期**: 2026-06-19
**修复提交**: a72f81d

## 问题描述

`install.sh` 旧版硬编码数据目录位置：

```bash
SOFAGENT_DATA="${PWD}/.sofagent"
```

用户无法指定数据目录位置，始终创建在执行 install.sh 时的 PWD。

## 影响

- 用户在项目目录外运行 install.sh → 数据目录创建在错误位置
- 多项目场景下数据目录混乱
- 无法统一管理数据目录

## 复现步骤

```bash
cd /tmp
bash ~/projects/my-app/sofagent/scripts/install.sh
# 期望: 数据目录在 ~/projects/my-app/.sofagent/
# 实际: 数据目录在 /tmp/.sofagent/
```

## 修复方案

添加 `--project-dir` 参数，允许用户指定项目工作目录：

```bash
bash sofagent/scripts/install.sh --project-dir ~/my-project
```

## 修复代码

参数解析：
```bash
--project-dir)  PROJECT_DIR="$2"; shift 2 ;;
--project-dir=*) PROJECT_DIR="${1#*=}"; shift ;;
```

路径确定：
```bash
if [ -n "${PROJECT_DIR:-}" ]; then
  PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
    err "--project-dir 目录不存在或无法访问: $PROJECT_DIR"
    exit 1
  }
  ok "数据目录: ${PROJECT_DIR}/.sofagent/"
else
  PROJECT_DIR="$PWD"
  warn "未指定 --project-dir，.sofagent/ 数据目录将创建在当前目录: ${PROJECT_DIR}"
fi

SOFAGENT_DATA="${SOFAGENT_DATA:-${PROJECT_DIR}/.sofagent}"
```

## 相关文件

- `sofagent/scripts/install.sh:61-62` (参数解析)
- `sofagent/scripts/install.sh:98-113` (路径确定)

## 备注

此修复是 Bug 001 的前置工作。Bug 001 修复了 `--project-dir` 被后续硬编码覆盖的问题。
