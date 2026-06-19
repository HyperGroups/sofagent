# sofagent Issues

本目录记录已发现的 bug 和问题，按发现顺序编号。

## 索引

| # | 严重程度 | 标题 | 文件 | 状态 | 修复提交 |
|---|---------|------|------|------|---------|
| 001 | 高 | `install.sh --project-dir` 被 PWD 静默覆盖 | `install.sh:414` | 已修复 | (未提交) |
| 002 | 中 | `task-orchestrate.sh` shasum 无 sha256sum 回退 | `task-orchestrate.sh:112` | 已修复 | (未提交) |
| 003 | 中 | `task-orchestrate.sh` `rm -f ""` 在 set -e 下崩溃 | `task-orchestrate.sh:466` | 已修复 | (未提交) |
| 004 | 低 | `load-chain.sh` hash_stdin 双缺失时缓存永久命中 | `load-chain.sh:90` | 已修复 | (未提交) |
| 005 | 高 | `task-orchestrate.sh` `ao run` 失败后 set -e 直接退出 | `task-orchestrate.sh:253,295,430` | 已修复 | e3a7646 |
| 006 | 中 | `verify.sh/uninstall.sh` `--platform "$2"` 在 for arg 里 shift 无效 | `verify.sh:27`, `uninstall.sh:27` | 已修复 | e3a7646 |
| 007 | 中 | `verify.sh` `stat -f %m` 无 GNU 回退 | `verify.sh:466` | 已修复 | e3a7646 |
| 008 | 低 | `task-record.sh` `grep -c ... \|\| echo 0` 输出 "0\n0" | `task-record.sh:149` | 已修复 | e3a7646 |
| 009 | 低 | `task-record.sh` `$((STEPS*100/LIMIT))` 除零崩溃 | `task-record.sh:133` | 已修复 | e3a7646 |
| 010 | 高 | `load-chain.sh` 哈希 stdin 消费问题（缓存永久命中） | `load-chain.sh:90` | 已修复 | a145761 |
| 011 | 中 | `install.sh` claude/codex/hermes 收尾 SOFAGENT_DATA 未绑定崩溃 | `install.sh:588` | 已修复 | a145761 |
| 012 | 低 | `task-orchestrate.sh` 硬编码 .sofagent 忽略 SOFAGENT_DATA 环境变量 | `task-orchestrate.sh:116` | 已修复 | a145761 |
| 013 | 中 | `install.sh` .sofagent/ 数据目录位置依赖 PWD | `install.sh:414` | 已修复 | a72f81d |

## 按提交分组

### 未提交（本次审计）

- **001** `install.sh --project-dir` 被 PWD 静默覆盖
- **002** `task-orchestrate.sh` shasum 无 sha256sum 回退
- **003** `task-orchestrate.sh` `rm -f ""` 在 set -e 下崩溃
- **004** `load-chain.sh` hash_stdin 双缺失时缓存永久命中

### commit e3a7646 — 5 处确定性 shell bug

- **005** `ao run` 失败后 set -e 直接退出（失败降级全是死代码）
- **006** `--platform "$2"` 在 `for arg` 里 shift 无效
- **007** `stat -f %m` 无 GNU 回退（Linux 上 think.md 永远显示超旧）
- **008** `grep -c ... || echo 0` 在 0 匹配时输出 "0\n0"
- **009** `$((STEPS*100/LIMIT))` 不防 0/非数字，除零崩脚本

### commit a145761 — 3 处 bug 修复（移植自 HyperGroups fork）

- **010** 哈希 stdin 消费问题（缺 shasum 时缓存永久命中）
- **011** claude/codex/hermes 收尾 SOFAGENT_DATA 未绑定崩溃（set -u）
- **012** 硬编码 `.sofagent` 忽略 SOFAGENT_DATA 环境变量

### commit a72f81d — install.sh --project-dir 支持

- **013** .sofagent/ 数据目录位置依赖 PWD（功能缺陷 + 修复）

## 按严重程度统计

| 严重程度 | 数量 | 编号 |
|---------|------|------|
| 高 | 4 | 001, 005, 010, (002 中→高边界) |
| 中 | 6 | 002, 003, 006, 007, 011, 013 |
| 低 | 3 | 004, 008, 009, 012 |

## 常见问题模式

审计中发现的重复性陷阱，供后续开发参考：

1. **`set -e` + 裸命令** — 命令失败立即退出，后续 `var=$?` 是死代码。用 `EXIT_CODE=0; cmd || EXIT_CODE=$?`
2. **`for arg in "$@"` + `shift`** — shift 对 for 循环无效。参数解析必须用 `while + shift`
3. **`cmd | tool || fallback`** — 管道数据已被 tool 消费，fallback 读到空 stdin。把工具选择放同一管道级
4. **`grep -c || echo 0`** — grep -c 无匹配时已输出 "0"，echo 追加变 "0\n0"。用 `|| true; ${var:-0}`
5. **跨平台 `stat`** — macOS `stat -f` vs GNU `stat -c`。GNU 优先 + BSD 回退
6. **`set -u` + 条件赋值** — 变量只在部分分支赋值，其他分支引用即崩。提前统一定义

## 文件命名规范

- `NNN-简短描述.md`
- NNN: 三位数编号，按发现顺序递增
- 简短描述: 用连字符分隔的关键词

## 状态定义

- **待修复**: 已发现，未修复
- **已修复**: 代码已修改，待提交
- **已关闭**: 已提交并验证
