# Bug 008: task-record.sh `grep -c ... || echo 0` 输出 "0\n0"

**状态**: 已修复
**严重程度**: 低
**发现日期**: 2026-06-19
**修复提交**: e3a7646

## 问题描述

`task-record.sh:149` 计算今日记录数：

```bash
COUNT=$(grep -c "^## " "$LOG_FILE" 2>/dev/null || echo 0)
```

`grep -c` 在 0 匹配时返回 exit 1（无匹配），触发 `|| echo 0`。但 `grep -c` 本身已输出 "0"，加上 `echo 0` 变成 "0\n0"。

## 影响

- `COUNT` 值为 "0\n0"（两行）
- 后续算术运算 `$((COUNT))` 报错（非数字）
- 闭环检查输出错误

## 复现步骤

```bash
# 创建空日志文件
mkdir -p .sofagent/task/logs/2026-06
touch .sofagent/task/logs/2026-06/2026-06-19.md
bash sofagent/scripts/task-record.sh --closure-check
# 期望: CLOSURE_CHECK: ... 存在 0 条记录
# 实际: 算术错误或非预期输出
```

## 修复方案

`|| true` 抑制 exit 1，`${COUNT:-0}` 提供默认值：

```bash
COUNT=$(grep -c "^## " "$LOG_FILE" 2>/dev/null || true); COUNT=${COUNT:-0}
```

## 修复代码

```diff
- COUNT=$(grep -c "^## " "$LOG_FILE" 2>/dev/null || echo 0)
+ COUNT=$(grep -c "^## " "$LOG_FILE" 2>/dev/null || true); COUNT=${COUNT:-0}
```

## 相关文件

- `sofagent/scripts/task-record.sh:149`

## 备注

`grep -c` 的行为：
- 有匹配：输出匹配行数，exit 0
- 无匹配：输出 "0"，exit 1
- 错误：无输出，exit 2

`|| echo 0` 在 exit 1 时追加 "0"，导致 "0\n0"。正确做法：`|| true` 抑制退出码，`${var:-0}` 提供默认值。
