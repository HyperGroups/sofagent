# Bug 009: task-record.sh `$((STEPS*100/LIMIT))` 除零崩溃

**状态**: 已修复
**严重程度**: 低
**发现日期**: 2026-06-19
**修复提交**: e3a7646

## 问题描述

`task-record.sh:133` 计算预算百分比：

```bash
PCT=$(( TASK_STEPS * 100 / BUDGET_LIMIT ))
```

未校验 `BUDGET_LIMIT` 是否为正整数。`--limit 0` 或非数字会导致除零或非数字算术错误。

## 影响

- `--limit 0` → 除零错误 → `set -e` 下脚本崩溃
- `--limit abc` → 非数字算术错误 → 脚本崩溃
- 用户无法使用预算检查功能

## 复现步骤

```bash
bash sofagent/scripts/task-record.sh --budget --task "test" --steps 10 --limit 0
# 期望: 错误提示或安全处理
# 实际: bash: 10 * 100 / 0: division by 0 (error token is "0")
```

## 修复方案

添加正整数校验：

```bash
if ! [[ "$TASK_STEPS" =~ ^[0-9]+$ ]] || ! [[ "$BUDGET_LIMIT" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUDGET_CHECK: 参数无效（--steps 需非负整数，--limit 需正整数）"
  exit 0
fi
```

## 修复代码

```diff
+ # 防除零/非数字：--limit 0 或非整数会让 $(( )) 报错并在 set -e 下崩脚本
+ if ! [[ "$TASK_STEPS" =~ ^[0-9]+$ ]] || ! [[ "$BUDGET_LIMIT" =~ ^[1-9][0-9]*$ ]]; then
+   echo "BUDGET_CHECK: 参数无效（--steps 需非负整数，--limit 需正整数）"
+   exit 0
+ fi
  PCT=$(( TASK_STEPS * 100 / BUDGET_LIMIT ))
```

## 相关文件

- `sofagent/scripts/task-record.sh:129-132` (新增校验)
- `sofagent/scripts/task-record.sh:133` (原除零位置)

## 备注

正则校验：
- `^[0-9]+$` — 非负整数（0, 1, 2, ...）
- `^[1-9][0-9]*$` — 正整数（1, 2, 3, ...，不含 0）

防御性写法：算术运算前必须校验操作数有效性。
