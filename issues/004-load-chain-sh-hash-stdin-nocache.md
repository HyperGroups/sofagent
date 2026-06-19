# Bug 004: load-chain.sh hash_stdin 双缺失时缓存永久命中

**状态**: 已修复
**严重程度**: 低
**发现日期**: 2026-06-19
**修复提交**: (待提交)

## 问题描述

`load-chain.sh:90` 的 `hash_stdin()` 函数：

```bash
hash_stdin() { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "nocache"; }
```

当 shasum 和 sha256sum **都**缺失时，返回固定字符串 `"nocache"`。

## 影响

1. `calc_hash()` 计算 NEW_HASH 时，所有输入（文件内容 + SKILL_ENFORCEMENT）都哈希为 `"nocache"`
2. 最终 NEW_HASH = `"nocache"`（因为 `printf '%s' "nocache" | hash_stdin` 也返回 `"nocache"`）
3. 第二次运行时，OLD_HASH 也是 `"nocache"` → 匹配 → 缓存永久命中
4. think.md/rules.md 变更不再触发重注入（约束静默失效）

## 触发条件

- 精简 Linux 容器（无 perl、无 coreutils）
- 极端环境（嵌入式系统、最小化 Docker 镜像）
- 概率低于 Bug 002（至少需要 shasum 和 sha256sum **都**缺失）

## 复现步骤

```bash
# 模拟双缺失环境
docker run --rm -it alpine:latest
# 不安装 perl-core（无 shasum）和 coreutils（无 sha256sum，busybox 的 sha256sum 功能有限）
cd /workspace
bash sofagent/scripts/load-chain.sh
# 第一次运行：输出约束块
bash sofagent/scripts/load-chain.sh --check
# 期望：miss（因为文件可能变化）
# 实际：hit（缓存永久命中）
```

## 修复方案

当哈希工具双缺失时，返回唯一值（时间戳+PID+随机数），确保缓存永不命中：

```bash
hash_stdin() { 
  shasum -a 256 2>/dev/null || 
  sha256sum 2>/dev/null || 
  echo "nocache-$(date +%s%N 2>/dev/null || date +%s)-$$-$RANDOM"
}
```

## 修复代码

```diff
- hash_stdin() { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "nocache"; }
+ # 修复：双缺失时用唯一值（时间戳+PID+随机数）确保缓存永不命中。
+ hash_stdin() { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "nocache-$(date +%s%N 2>/dev/null || date +%s)-$$-$RANDOM"; }
```

## 相关文件

- `sofagent/scripts/load-chain.sh:90`
- `sofagent/scripts/load-chain.sh:92-104` (calc_hash 函数)

## 备注

此 bug 与已修复的 stdin 消费问题（commit a145761）属于同一类：跨平台哈希工具兼容性。修复后的行为：
- 有 shasum/sha256sum：正常哈希缓存
- 双缺失：每次运行都重建缓存（性能略差，但保证正确性）
