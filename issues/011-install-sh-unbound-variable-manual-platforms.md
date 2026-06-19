# Bug 011: install.sh claude/codex/hermes 收尾 SOFAGENT_DATA 未绑定崩溃

**状态**: 已修复
**严重程度**: 中
**发现日期**: 2026-06-19
**修复提交**: a145761

## 问题描述

`install.sh` 在 `set -u` 下，`SOFAGENT_DATA` 变量只在 OpenClaw/WorkBuddy 路径赋值（line 414），但手动平台（claude/codex/hermes）的收尾 summary（line 588）引用该变量：

```bash
echo "    数据目录:       $SOFAGENT_DATA"
```

在 claude/codex/hermes 平台，`SOFAGENT_DATA` 未绑定 → `set -u` 下脚本崩溃。

## 影响

- `bash install.sh --platform claude` 在收尾阶段崩溃
- 用户看不到安装完成信息
- exit code 非 0（安装看似失败）

## 复现步骤

```bash
bash sofagent/scripts/install.sh --platform claude
# 期望: 输出种子指令和安装完成信息
# 实际: line 588: SOFAGENT_DATA: unbound variable
```

## 修复方案

在 `PROJECT_DIR` 确定后提前统一定义 `SOFAGENT_DATA`（line 113），避免 set -u 下未绑定：

```bash
# 数据目录变量提前统一定义——避免 set -u 下 claude/codex/hermes 收尾 summary 引用未绑定变量
SOFAGENT_DATA="${SOFAGENT_DATA:-${PROJECT_DIR}/.sofagent}"
```

## 修复代码

```diff
  fi
  
+ # 数据目录变量提前统一定义——避免 set -u 下 claude/codex/hermes 收尾 summary 引用未绑定变量
+ SOFAGENT_DATA="${SOFAGENT_DATA:-${PROJECT_DIR}/.sofagent}"
+ 
  # ── 按平台确定目标路径 ──
  case "$PLATFORM" in
```

## 相关文件

- `sofagent/scripts/install.sh:113` (新增统一定义)
- `sofagent/scripts/install.sh:588` (summary 引用处)

## 备注

`set -u` 的陷阱：引用未绑定变量会立即退出。防御性写法：
- 提前统一定义变量（即使后续可能覆盖）
- 使用 `${var:-default}` 提供默认值
