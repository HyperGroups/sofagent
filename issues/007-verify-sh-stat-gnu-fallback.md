# Bug 007: verify.sh `stat -f %m` 无 GNU 回退

**状态**: 已修复
**严重程度**: 中
**发现日期**: 2026-06-19
**修复提交**: e3a7646

## 问题描述

`verify.sh:466` 计算 think.md 修改时间：

```bash
modified_sec=$(($(date +%s) - $(stat -f %m ".sofagent/think.md" 2>/dev/null || echo 0)))
```

`stat -f %m` 是 macOS/BSD 语法，GNU coreutils 用 `stat -c %Y`。

## 影响

- Linux 上 `stat -f %m` 失败 → `echo 0` → `modified_sec` 恒为当前时间戳
- think.md 永远显示"超旧"（modified_days 极大）
- 用户误以为闭环未正常运转

## 复现步骤

```bash
# Linux 环境
bash sofagent/scripts/verify.sh
# 反思更新频率检查：
# 期望: think.md X 天前更新（活跃）
# 实际: think.md 19738 天前更新——闭环可能未正常运转
```

## 修复方案

GNU 优先，macOS 回退（与同文件 line 200 的权限检查对齐）：

```bash
modified_sec=$(($(date +%s) - $(stat -c %Y ".sofagent/think.md" 2>/dev/null || stat -f %m ".sofagent/think.md" 2>/dev/null || echo 0)))
```

## 修复代码

```diff
- modified_sec=$(($(date +%s) - $(stat -f %m ".sofagent/think.md" 2>/dev/null || echo 0)))
+ modified_sec=$(($(date +%s) - $(stat -c %Y ".sofagent/think.md" 2>/dev/null || stat -f %m ".sofagent/think.md" 2>/dev/null || echo 0)))
```

## 相关文件

- `sofagent/scripts/verify.sh:466`
- `sofagent/scripts/verify.sh:200` (权限检查，已正确使用 GNU 优先)

## 备注

跨平台 `stat` 语法差异：
- macOS/BSD: `stat -f %m` (修改时间), `stat -f %Lp` (权限)
- GNU: `stat -c %Y` (修改时间), `stat -c %a` (权限)

防御性写法：GNU 优先（Linux 用户更多），BSD 回退。
