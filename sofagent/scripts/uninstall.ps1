# ============================================================
# sofagent uninstall.ps1 · Windows PowerShell 卸载脚本
# ============================================================
# 删除 sofagent 约束文件，保留 .sofagent/ 用户数据。
# 与 uninstall.sh (WSL/Linux/macOS) 按环境解耦；与 install.ps1 对称。
#
# 用法：
#     .\uninstall.ps1 -Platform workbuddy
#     .\uninstall.ps1 -Force          跳过确认直接删除
#     .\uninstall.ps1 -List           仅列出将删除项，不执行
#     .\uninstall.ps1 -Help
# ============================================================

param(
    [string]$Platform = "",
    [switch]$Force,
    [switch]$List,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$VERSION = "1.0.0"

function Write-Info { param($msg) Write-Host "[sofagent] $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[X] $msg" -ForegroundColor Red }

# 帮助
if ($Help) {
    Write-Host "sofagent uninstall.ps1 v$VERSION"
    Write-Host ""
    Write-Host "Windows PowerShell 卸载脚本 (WorkBuddy / OpenClaw on Windows)"
    Write-Host ""
    Write-Host "用法:"
    Write-Host "    .\uninstall.ps1 -Platform workbuddy"
    Write-Host "    .\uninstall.ps1 -Force      跳过确认直接删除"
    Write-Host "    .\uninstall.ps1 -List       仅列出将删除项，不执行"
    Write-Host ""
    Write-Host "参数:"
    Write-Host "    -Platform   目标平台 (workbuddy|openclaw)"
    Write-Host "    -Force      跳过交互确认"
    Write-Host "    -List       预览将删除的文件"
    Write-Host "    -Help       显示此帮助"
    Write-Host ""
    Write-Host "保留: .sofagent/ 数据目录 (如需清除请手动删除)"
    exit 0
}

# 环境检测
Write-Host ""
Write-Host "  +===================================+"
Write-Host "  |   sofagent Harness - uninstaller   |"
Write-Host "  |   (Windows PowerShell)            |"
Write-Host "  +===================================+"
Write-Host ""

# WSL 检测 (仅认 WSL_DISTRO_NAME——WSLENV 在装了 WSL 的 Windows 主机上也会被设, 不能作判据)
if ($env:WSL_DISTRO_NAME) {
    Write-Err "检测到 WSL 环境, 请使用 uninstall.sh (bash) 而非本脚本"
    Write-Warn "  bash sofagent/scripts/uninstall.sh --platform workbuddy"
    exit 1
}
if (-not $IsWindows -and -not ($env:OS -eq "Windows_NT")) {
    Write-Err "本脚本仅支持 Windows, 非 Windows 环境请使用 uninstall.sh"
    exit 1
}

# 平台探测
if ([string]::IsNullOrEmpty($Platform)) {
    if (Test-Path "$env:USERPROFILE\.workbuddy") {
        $Platform = "workbuddy"
    } elseif (Test-Path "$env:USERPROFILE\.openclaw") {
        $Platform = "openclaw"
    } else {
        $Platform = "workbuddy"
    }
}
$Platform = $Platform.ToLower()

switch ($Platform) {
    "workbuddy" { $TARGET = "$env:USERPROFILE\.workbuddy" }
    "openclaw"  { $TARGET = "$env:USERPROFILE\.openclaw" }
    default     { $TARGET = "$env:USERPROFILE\.workbuddy" }
}
Write-Info "平台: $Platform -> 目标: $TARGET"

# 收集将删除项 (对应 install.ps1 部署的内容)
$skillDir  = Join-Path $TARGET "skills\sofagent"
$rulesFile = Join-Path $TARGET "rules.md"
$scriptsDir = Join-Path $TARGET "scripts"
$targets = @()
if (Test-Path $skillDir)   { $targets += $skillDir }
if (Test-Path $rulesFile)  { $targets += $rulesFile }
if (Test-Path $scriptsDir) { $targets += $scriptsDir }

if ($targets.Count -eq 0) {
    Write-Warn "未发现 sofagent 部署文件 ($TARGET 下无 skills\sofagent 或 rules.md)"
    exit 0
}

Write-Host ""
Write-Host "  将删除以下 sofagent 约束文件:"
foreach ($t in $targets) {
    if (Test-Path $t -PathType Container) {
        $n = (Get-ChildItem $t -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        Write-Host "    $t\  ($n 个文件)"
    } else {
        Write-Host "    $t"
    }
}
Write-Host ""
Write-Host "  保留: 工作区 .sofagent/ 数据目录 (如需清除请手动删除)"
Write-Host ""

# -List: 仅预览
if ($List) {
    Write-Host "  (-List 模式, 未执行删除)"
    exit 0
}

# 确认
if (-not $Force) {
    $confirm = Read-Host "  确认删除? [y/N]"
    if ($confirm -notmatch '^[yY]') {
        Write-Host "  已取消。"
        exit 0
    }
}

# 执行删除
$removed = 0
foreach ($t in $targets) {
    Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue
    if (-not (Test-Path $t)) { Write-Ok "已删除: $t"; $removed++ }
    else { Write-Err "删除失败: $t" }
}

Write-Host ""
Write-Host "  +====================================+"
Write-Host "  |  sofagent - 卸载完成                |"
Write-Host "  +====================================+"
Write-Host ""
Write-Host "  共删除 $removed 项约束文件。.sofagent/ 工作区数据已保留。"
Write-Host "  重新安装: .\install.ps1 -Platform $Platform"
Write-Host ""
