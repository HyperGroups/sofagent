# 确定性修复记录（fork 专用）

> 本目录是 **HyperGroups fork 自有记录**，只存在于 fork 仓库的镜像分支（`upstream`），
> **不向上游提 PR**。向上游贡献时从 `upstream/main` 另切干净的 `fix/xxx` 主题分支，
> 只带代码改动，不带本目录。
>
> 与 `issues/`（gitignored，本地审计草稿）的分工：
> - `issues/` —— 原始发现台账，本地保留，不进版本库。
> - `docs/bug_fix/` —— 已确认的**确定性** bug + 复现 + 修复，提交到 fork，按拟提的主题分支分组。

「确定性」= 100% 可复现、与模型能力无关的脚本 bug（区别于 `docs/anti-cases/` 记录的模型行为问题）。

## 工作流

1. 在镜像分支（`upstream`）按自己的方式修问题、记录到本目录、打 tag 标记。
2. 真要回贡上游时，从最新 `upstream/main` 切 `fix/xxx` 主题分支，把对应那一组修复做成**原子提交**。
3. 按作者规矩（CONTRIBUTING.md + PR 模板）走：`verify.sh` 全过 → 部署循环 → 非 OpenClaw 平台测试。
4. 先推到自己 fork（`origin`）的主题分支试，再决定是否提 PR 到 `upstream`。

## 拟分组（= 拟提的主题分支）

相对最新 `upstream/main`（含 v0.82）的净改动，按主题归为 4 个主题分支：

### 1. `fix/set-e-premature-exit` — `set -e` 下裸命令提前退出（高）

`task-orchestrate.sh` 在 `set -euo pipefail`（line 69）下，3 处裸 `ao run` 失败即退出，
后续失败处理/重试逻辑全成死代码。

| 位置 | 修复 |
|------|------|
| L3 模板分支 | `EXIT_CODE=0; ao run ... \|\| EXIT_CODE=$?` |
| L4 直接执行 | 同上 |
| 重试循环（上游 v0.73 新增） | 把 `\|\| EXIT_CODE=$?` 并入上游循环，否则重试永不触发 |

**复现**：`ao` 返回非 0 → 脚本立即终止，看不到"重试 N/M"和失败汇总。

### 2. `fix/arg-parsing-shift` — `for arg in "$@"` + `shift` 失效（中）

`for arg` 循环里 `shift` 无效、取 `$2` 拿到的是脚本位置参数而非"下一个 arg"，
导致 `--quiet --platform X` 把 PLATFORM 误设为字面量 `--platform`。改用 `while [[ $# -gt 0 ]]` + `shift`。

| 文件 | 备注 |
|------|------|
| `verify.sh` | 同时保留上游新增的 `--quick` |
| `uninstall.sh` | 同类修复 |

**复现**：`bash verify.sh --quiet --platform claude` → 平台探测错误。

### 3. `fix/cross-platform-portability` — BSD/GNU 工具差异（中）

作者在 CONTRIBUTING「最需要的技能」里点名的 bash BSD/macOS 兼容性。

| 位置 | 修复 |
|------|------|
| `task-orchestrate.sh` TASK_SLUG | `shasum` 缺失时回退 `sha256sum`（Alpine/精简 Linux 无 shasum） |
| `verify.sh` think.md 时间 | `stat -c %Y`（GNU）回退 `stat -f %m`（BSD），原代码 BSD-only 在 Linux 永远算超旧 |

**复现**：精简 Linux 容器跑 `task-orchestrate.sh` → TASK_SLUG 恒为 unknown；Linux 跑 `verify.sh` → 反思频率永远报"超旧"。

### 4. `fix/numeric-and-unbound-guards` — 数值/未绑定健壮性（低-中）

| 文件 | 修复 |
|------|------|
| `task-record.sh` 预算 | `--limit 0`/非数字在 `$(( ))` 前拦截，防除零崩溃 |
| `task-record.sh` 闭环计数 | 修 `grep -c ... \|\| echo 0` 在 0 匹配时输出 `"0\n0"` |
| `task-orchestrate.sh` 清理 | guard 空 `$SOFAGENT_CONSTRAINT_FILE`，避免 set -u 下 `rm ""` |
| `install.sh` 数据目录 | `SOFAGENT_DATA="${SOFAGENT_DATA:-...}"` 保留外部环境变量覆盖 |

**复现**：`task-record.sh --budget --steps 5 --limit 0` → 除零，set -e 崩脚本。

## 回归测试

`dev` 分支已有针对前 5 个确定性 bug 的回归用例（A–E，commit `44a0778`）。
提主题分支时一并带上对应用例，满足作者 PR 模板的「verify.sh 全过」要求。

## 不在本目录的改动

- `install.ps1` + `install.sh` 环境检测 —— **功能新增**，不是确定性 bug 修复，不归此处。
  按 fork 原则（见 `issues/FORK.md` §1.3）走独立 feature 分支评估。
- `load-chain.sh` 哈希缓存修复 —— 上游 v0.64 已删该文件（hook 替代，无缓存层），修复已无对象。
