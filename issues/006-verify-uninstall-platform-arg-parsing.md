# Bug 006: verify.sh/uninstall.sh `--platform "$2"` 在 for arg 里 shift 无效

**状态**: 已修复
**严重程度**: 中
**发现日期**: 2026-06-19
**修复提交**: e3a7646

## 问题描述

`verify.sh` 和 `uninstall.sh` 使用 `for arg in "$@"` 解析参数：

```bash
for arg in "$@"; do
  case "$arg" in
    --platform) PLATFORM="$2"; shift ;;
  esac
done
```

在 `for` 循环里，`$2` 是脚本的位置参数（非"下一个 arg"），且 `shift` 对 `for` 循环无效。

## 影响

- `--force --platform X` 会把 PLATFORM 误设为 `"--platform"`（下一个位置参数）
- 参数解析完全错误，平台探测失败

## 复现步骤

```bash
bash sofagent/scripts/uninstall.sh --force --platform openclaw
# 期望: PLATFORM="openclaw"
# 实际: PLATFORM="--platform"（或空）
```

## 修复方案

改用 `while [[ $# -gt 0 ]]` + `shift` 解析（与 `install.sh` 一致）：

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
  esac
done
```

## 修复代码

```diff
- for arg in "$@"; do
-   case "$arg" in
-     --platform) PLATFORM="$2"; shift ;;
-   esac
- done
+ while [[ $# -gt 0 ]]; do
+   case "$1" in
+     --platform) PLATFORM="$2"; shift 2 ;;
+   esac
+ done
```

## 相关文件

- `sofagent/scripts/verify.sh:27-43`
- `sofagent/scripts/uninstall.sh:27-43`
- `sofagent/scripts/install.sh:57-81` (参考正确实现)

## 备注

`for arg in "$@"` 里 `$2` 是脚本位置参数，不是"下一个 arg"。`shift` 对 `for` 循环无效（循环变量已展开）。参数解析必须用 `while + shift`。
