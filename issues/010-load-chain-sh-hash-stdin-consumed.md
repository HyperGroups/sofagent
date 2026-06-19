# Bug 010: load-chain.sh 哈希 stdin 消费问题

**状态**: 已修复
**严重程度**: 高
**发现日期**: 2026-06-19
**修复提交**: a145761

## 问题描述

`load-chain.sh` 旧版 `hash_stdin()`:

```bash
hash_stdin() { echo "$1" | shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "nocache"; }
```

在缺 shasum 的精简 Linux（Alpine/无 perl）上：
1. `echo "$1" | shasum` 失败（shasum 不存在）
2. `echo` 的输出已被失败的 shasum 管道消费
3. fallback 的 `sha256sum` 读到空 stdin
4. 哈希恒等于 `SHA-256("")` = `e3b0c442...b855`

## 影响

- 哈希与文件内容脱钩
- 缓存永久命中
- think.md/rules.md 改了也不再注入（约束静默失效）

## 复现步骤

```bash
# 在无 shasum 的 Alpine 环境
docker run --rm -it alpine:latest
apk add bash
# 手动创建测试文件
echo "content1" > test.txt
echo "content2" > test2.txt
# 旧版 hash_stdin 对两个文件返回相同哈希
```

## 修复方案

把工具选择放进同一管道级，数据只 pipe 一次：

```bash
hash_stdin() { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "nocache"; }
```

调用时：`printf '%s' "$data" | hash_stdin`（数据只进入管道一次）

## 修复代码

```diff
- hash_stdin() { echo "$1" | shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "nocache"; }
+ hash_stdin() { shasum -a 256 2>/dev/null || sha256sum 2>/dev/null || echo "nocache"; }
```

调用处：
```diff
- combined+=$(hash_stdin "$SKILL_ENFORCEMENT")
+ combined+=$(printf '%s' "$SKILL_ENFORCEMENT" | hash_stdin)
```

## 相关文件

- `sofagent/scripts/load-chain.sh:90` (修复后)
- `sofagent/scripts/load-chain.sh:102-103` (调用处)

## 备注

管道数据消费的经典陷阱：`cmd1 | tool || fallback` 中，`cmd1` 的输出已被 `tool` 消费（即使失败），`fallback` 读不到数据。

正确做法：`tool || fallback` 在同一管道级，数据从上游 pipe 一次。
