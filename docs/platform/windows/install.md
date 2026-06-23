# 原生 Windows 安装与使用指南（PowerShell）

> 面向 **Windows 11 + WorkBuddy/OpenClaw + 纯 PowerShell（非 WSL）** 用户。
> 这是 [`sofagent-quickstart.md`](../../../sofagent-quickstart.md)（bash 版）的 PowerShell 平行版。
> 环境矩阵与编码踩坑见 [README.md](README.md) 与 [`docs/bug_fix/tests/ENVIRONMENTS.md`](../../bug_fix/tests/ENVIRONMENTS.md)。

> **何时用 .ps1，何时用 .sh**
> - Windows 11 + WorkBuddy/OpenClaw + 纯 PowerShell → **本指南（.ps1）**
> - WSL / Linux / macOS / Git Bash → [`sofagent-quickstart.md`](../../../sofagent-quickstart.md)（.sh）
> - install.ps1 检测到 WSL（`$env:WSL_DISTRO_NAME`）会拒绝并提示改用 install.sh。

## 1. 前置依赖

| 依赖 | 推荐 | 用途 | 检查 |
|---|---|---|---|
| Windows PowerShell | 5.1（`powershell.exe`） | 运行 .ps1 脚本 | `$PSVersionTable.PSVersion` |
| git | 任意 | 拉取仓库 | `git --version` |
| Node / npm | 18+ / 9+ | （可选）`agency-orchestrator` 编排 | `node --version` |

- 只用基础约束层时，Node/npm 非必需。
- `ao` 是纯 Node 包，`npm i -g agency-orchestrator` 在 Windows 原生可装可跑，**无需 WSL/Python**。
- 无需安装 `jq`：.ps1 用 `ConvertFrom-Json` 原生解析。

## 2. 执行策略（首次必看）

PowerShell 默认可能禁止运行脚本。按当前用户放开（无需管理员）：

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

或单次运行时绕过（不改全局策略）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sofagent\scripts\install.ps1 -Platform workbuddy
```

## 3. 安装

```powershell
git clone https://github.com/KongFangXun/sofagent.git
cd sofagent
.\sofagent\scripts\install.ps1 -Platform workbuddy -ProjectDir "D:\my-project"
```

平台切换：

```powershell
.\sofagent\scripts\install.ps1 -Platform openclaw -ProjectDir "D:\my-project"
```

不传 `-Platform` 时按 `~\.workbuddy` / `~\.openclaw` 是否存在自动探测（都没有则默认 workbuddy）。

### 参数

| 参数 | 说明 | 对应 install.sh |
|---|---|---|
| `-Platform <workbuddy\|openclaw>` | 目标平台 | `--platform` |
| `-ProjectDir <path>` | `.sofagent\` 数据目录位置（不传则当前目录） | `--project-dir` |
| `-NoAO` | 跳过 agency-orchestrator 安装 | `--no-ao` |
| `-NoConfigInject` | 不注入 OpenClaw 断路器 loopDetection | `--no-config-inject` |
| `-Help` | 显示帮助 | `--help` |

> **OpenClaw 专属**：`-Platform openclaw` 会额外部署加载链 Hook（`sofagent-load-chain`）、在 `openclaw.json` 注册、向 `config.json` 注入 loopDetection 断路器（除非 `-NoConfigInject`）。WorkBuddy 不做这些（无内部 hook 机制）。

## 4. 安装后生成什么

WorkBuddy 典型结果：

```text
~\.workbuddy\
├── skills\sofagent\        # SKILL.md(置 disable:true) / engine / entry-gate /
│                           #   task-aware / task-closure / loop-check / rules.md / data\
└── scripts\                # 16 个 .ps1 移植 + ab-eval.ps1，含 lib\config.ps1 / lib\daemon-lib.ps1
```

项目目录下生成 `.sofagent\`（`think.md` / `task\logs\` / `orchestrator\`，部分首次闭环后才出现）。

> v0.84：部署到平台的 SKILL.md 副本会被置 `disable: true`，防止安装副本被平台重复自动加载（与 install.sh 行为一致）。

## 5. 验证

```powershell
.\sofagent\scripts\verify.ps1 -Quick      # 快速
.\sofagent\scripts\verify.ps1             # 完整
.\sofagent\scripts\verify.ps1 -Json       # JSON（CI 用）
```

首次使用前没有 `think.md` / 任务日志属正常，不算失败。

## 6. 跨平台脚本调用约定（重要）

SKILL.md 第 1 层包含「跨平台脚本调用约定」：文档里写的 `bash X.sh --flag`，在纯 PowerShell 环境改为：

```
bash task-record.sh --task "..."   →   powershell -File task-record.ps1 -Task "..."
```

规则：`bash X.sh` → `powershell -File X.ps1`；kebab-case 旗标 → PascalCase 参数（`--project-dir` → `-ProjectDir`）。Agent 在 WorkBuddy 上应按此转换。

## 7. 卸载

```powershell
.\sofagent\scripts\uninstall.ps1 -Platform workbuddy           # 交互确认
.\sofagent\scripts\uninstall.ps1 -Platform workbuddy -Force    # 跳过确认
.\sofagent\scripts\uninstall.ps1 -Platform workbuddy -List     # 仅预览
```

- 保留项目内 `.sofagent\`（任务记录/反思）。需要清除请手动删。
- `-Platform openclaw` 会一并清理 Hook、`openclaw.json` 注册项、`config.json` 的 loopDetection，并调用 `daemon-uninstall.ps1`。

## 8. 写 .ps1 / 改脚本的编码三铁律

含中文的 .ps1 在 PS 5.1 下极易乱码，务必遵守（详见 [README.md](README.md) / ENVIRONMENTS.md）：

1. 含中文 `.ps1` 存 **UTF-8 BOM**（无 BOM 会按 GBK 解析 → 乱码）。
2. 读取转换用 `Get-Content -Raw -Encoding UTF8`（否则 GBK 误读读坏）。
3. 写 `.md`/JSON 等给平台读的文件用 **UTF-8 无 BOM**（BOM 在 frontmatter 首行 `---` 前会破坏解析）。
4. `.gitattributes` 已锁 `*.ps1=CRLF` / `*.sh=LF`，不要改。

## 9. 常见问题

| 现象 | 处理 |
|---|---|
| `无法加载…禁止运行脚本` | 见 §2 执行策略 |
| 中文输出乱码 | 脚本顶部已设 UTF-8 输出；若仍乱码检查终端字体/代码页 `chcp 65001` |
| `install.ps1` 报「检测到 WSL」 | 你在 WSL 里，改用 install.sh |
| `ao` 不可用 | `npm i -g agency-orchestrator`；或装时加 `-NoAO` 只用约束层 |
| 版本号显示 0.82 而非 0.84 | 已知问题 issues/026（.ps1 版本滞后），仅展示性，不影响功能 |

## 10. 一页速查

```powershell
git clone https://github.com/KongFangXun/sofagent.git ; cd sofagent
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned          # 首次
.\sofagent\scripts\install.ps1 -Platform workbuddy -ProjectDir "D:\my-project"
.\sofagent\scripts\verify.ps1 -Quick
# 卸载
.\sofagent\scripts\uninstall.ps1 -Platform workbuddy -Force
```

## 关联

- 环境矩阵 / .ps1 移植现状 / PowerShell 语法坑 → [README.md](README.md)
- WorkBuddy A/B 评测 → [`../workbuddy/ab-test-manual.md`](../workbuddy/ab-test-manual.md)
- bash 版上手 → [`sofagent-quickstart.md`](../../../sofagent-quickstart.md)
