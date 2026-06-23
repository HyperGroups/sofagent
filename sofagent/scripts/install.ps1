# ============================================================
# sofagent install.ps1 · Windows PowerShell 安装脚本
# ============================================================
# WorkBuddy (Windows 11) 原生安装脚本
# 与 install.sh (WSL/Linux/macOS) 功能对齐
#
# 用法：
#   .\install.ps1 -Platform workbuddy -ProjectDir "D:\my-project"
#   .\install.ps1 -Platform workbuddy
#   .\install.ps1 -Help
#
# 环境说明：
#   - Windows 11 + WorkBuddy → 使用本脚本 (PowerShell)
#   - WSL / Linux / macOS    → 使用 install.sh (bash)
#   - Git Bash (Windows)     → 可用 install.sh，但建议用本脚本
# ============================================================

param(
    [string]$Platform = "",
    [string]$ProjectDir = "",
    [switch]$NoAO,
    [switch]$NoConfigInject,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$VERSION = "0.82"

# ── 颜色输出 ──
function Write-Info  { param($msg) Write-Host "[sofagent] $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[X] $msg" -ForegroundColor Red }

# ── 帮助 ──
if ($Help) {
    Write-Host "sofagent install.ps1 v$VERSION"
    Write-Host ""
    Write-Host "Windows PowerShell 原生安装脚本（WorkBuddy on Windows 11）"
    Write-Host ""
    Write-Host "用法:"
    Write-Host "  .\install.ps1 -Platform workbuddy -ProjectDir 'D:\my-project'"
    Write-Host "  .\install.ps1 -Platform workbuddy"
    Write-Host ""
    Write-Host "参数:"
    Write-Host "  -Platform     目标平台 (workbuddy|openclaw)"
    Write-Host "  -ProjectDir   项目工作目录（.sofagent/ 数据目录位置）"
    Write-Host "  -NoAO         跳过 agency-orchestrator 安装"
    Write-Host "  -Help         显示此帮助"
    Write-Host ""
    Write-Host "环境区分:"
    Write-Host "  Windows + WorkBuddy  → install.ps1（本脚本）"
    Write-Host "  WSL / Linux / macOS  → install.sh"
    exit 0
}

# ── 环境检测 ──
Write-Host ""
Write-Host "  +===================================+"
Write-Host "  |   sofagent Harness · installer    |"
Write-Host "  |   (Windows PowerShell)            |"
Write-Host "  +===================================+"
Write-Host ""

# 检测是否在 WSL 中运行（仅认 WSL_DISTRO_NAME——WSLENV 在装了 WSL 的 Windows 主机上也会被设，不能作判据）
if ($env:WSL_DISTRO_NAME) {
    Write-Err "检测到 WSL 环境，请使用 install.sh (bash) 而非本脚本"
    Write-Warn "  bash sofagent/scripts/install.sh --platform workbuddy"
    exit 1
}

# 检测操作系统
if (-not $IsWindows -and -not ($env:OS -eq "Windows_NT")) {
    Write-Err "本脚本仅支持 Windows，非 Windows 环境请使用 install.sh"
    exit 1
}

Write-Ok "运行环境: Windows PowerShell"

# ── 确定脚本所在目录 ──
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
# scripts/ → sofagent/ (项目内 skill 源码目录)
$SKILL_SRC_DIR = Split-Path -Parent $SCRIPT_DIR
# sofagent/ → 项目根目录
$PROJECT_ROOT = Split-Path -Parent $SKILL_SRC_DIR

# ── 平台探测 ──
Write-Info "Step 1/4 · 确定安装平台..."

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

# ── 确定数据目录 ──
if ([string]::IsNullOrEmpty($ProjectDir)) {
    $ProjectDir = Get-Location
    Write-Warn "未指定 -ProjectDir，.sofagent/ 数据目录将创建在当前目录: $ProjectDir"
    Write-Warn "  建议: .\install.ps1 -ProjectDir 'D:\my-project'"
} else {
    if (-not (Test-Path $ProjectDir)) {
        Write-Err "-ProjectDir 目录不存在: $ProjectDir"
        exit 1
    }
    $ProjectDir = (Resolve-Path $ProjectDir).Path
}

$SOFAGENT_DATA = Join-Path $ProjectDir ".sofagent"
Write-Ok "数据目录: $SOFAGENT_DATA"

# ── 确定目标路径 ──
switch ($Platform) {
    "workbuddy" { $TARGET = "$env:USERPROFILE\.workbuddy" }
    "openclaw"  { $TARGET = "$env:USERPROFILE\.openclaw" }
    default     { $TARGET = "$env:USERPROFILE\.workbuddy" }
}

Write-Ok "平台: $Platform → 目标: $TARGET"

# ── 检查源文件 ──
if (-not (Test-Path $SKILL_SRC_DIR)) {
    Write-Err "找不到 sofagent/ 目录。请在 sofagent 项目根目录下运行此脚本。"
    Write-Err "  当前脚本位置: $SCRIPT_DIR"
    Write-Err "  期望目录: $SKILL_SRC_DIR"
    exit 1
}

# ════════════════════════════════════════
# Step 2: 部署 Skill 文件
# ════════════════════════════════════════
Write-Info "Step 2/4 · 部署 Skill 文件 → $TARGET\skills\sofagent"

$SKILL_DST = Join-Path $TARGET "skills\sofagent"
if (-not (Test-Path $SKILL_DST)) {
    New-Item -ItemType Directory -Path $SKILL_DST -Force | Out-Null
}

# 核心 Skill 文件
$skillFiles = @("SKILL.md", "engine.md", "entry-gate.md", "task-aware.md", "task-closure.md", "loop-check.md")
$copied = 0

foreach ($f in $skillFiles) {
    $src = Join-Path $SKILL_SRC_DIR $f
    $dst = Join-Path $SKILL_DST $f
    if (Test-Path $src) {
        $needCopy = $true
        if (Test-Path $dst) {
            $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash $dst -Algorithm SHA256).Hash
            if ($srcHash -eq $dstHash) { $needCopy = $false }
        }
        if ($needCopy) {
            Copy-Item $src $dst -Force
            $copied++
        }
    } else {
        Write-Warn "找不到 $f，跳过"
    }
}

# 数据模板
$DATA_SRC = Join-Path $SKILL_SRC_DIR "data"
$DATA_DST = Join-Path $SKILL_DST "data"
if (-not (Test-Path $DATA_DST)) {
    New-Item -ItemType Directory -Path $DATA_DST -Force | Out-Null
}

if (Test-Path $DATA_SRC) {
    Get-ChildItem $DATA_SRC -Filter "*.md" | ForEach-Object {
        $src = $_.FullName
        $dst = Join-Path $DATA_DST $_.Name
        $needCopy = $true
        if (Test-Path $dst) {
            $srcHash = (Get-FileHash $src -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash $dst -Algorithm SHA256).Hash
            if ($srcHash -eq $dstHash) { $needCopy = $false }
        }
        if ($needCopy) {
            Copy-Item $src $dst -Force
            $copied++
        }
    }
}

if ($copied -gt 0) {
    Write-Ok "$copied 个 Skill/数据文件已部署到 $SKILL_DST"
} else {
    Write-Ok "Skill 文件全部就绪（无变更）"
}

# v0.84: SKILL.md 部署后确保 disable: true（防止安装副本被平台自动加载）
$deployedSkill = Join-Path $SKILL_DST "SKILL.md"
if (Test-Path $deployedSkill) {
    $skillLines = Get-Content $deployedSkill -Encoding UTF8
    if (-not ($skillLines | Where-Object { $_ -match '^disable:' })) {
        $hasDisplay = [bool]($skillLines | Where-Object { $_ -match '^displayName:' })
        $anchorRe = if ($hasDisplay) { '^displayName:' } else { '^name:' }
        $outLines = New-Object System.Collections.Generic.List[string]
        $inserted = $false
        foreach ($ln in $skillLines) {
            $outLines.Add($ln)
            if (-not $inserted -and $ln -match $anchorRe) {
                $outLines.Add('disable: true')
                $inserted = $true
            }
        }
        # .md 不写 BOM（BOM 在首行 --- 前会破坏 frontmatter 解析），保持 LF
        [System.IO.File]::WriteAllText($deployedSkill, (($outLines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))
        Write-Ok "SKILL.md 安装副本已置 disable: true"
    }
}

# ════════════════════════════════════════
# Step 2.5: 部署 .ps1 运行时脚本（供 {OPENCLAW_SCRIPTS} 在部署后解析）
# ════════════════════════════════════════
Write-Info "部署运行时脚本 → $TARGET\scripts\"
$scriptsDst = Join-Path $TARGET "scripts"
$libDst = Join-Path $scriptsDst "lib"
New-Item -ItemType Directory -Force -Path $libDst | Out-Null
$psCount = 0
Get-ChildItem -Path $SCRIPT_DIR -Filter *.ps1 -File | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $scriptsDst $_.Name) -Force; $psCount++
}
$libSrc = Join-Path $SCRIPT_DIR "lib"
if (Test-Path $libSrc) {
    Get-ChildItem -Path $libSrc -Filter *.ps1 -File | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $libDst $_.Name) -Force; $psCount++
    }
}
Write-Ok "$psCount 个 .ps1 脚本已部署到 $scriptsDst"

# ════════════════════════════════════════
# Step 3: 部署 rules.md
# ════════════════════════════════════════
Write-Info "Step 3/4 · 部署宪法文件 → $TARGET\rules.md"

# v0.73 起 rules.md 扁平化到 sofagent/rules.md；旧布局 fallback 到 constitution/rules.md
$rulesSrc = Join-Path $SKILL_SRC_DIR "rules.md"
if (-not (Test-Path $rulesSrc)) {
    $rulesSrc = Join-Path $SKILL_SRC_DIR "constitution\rules.md"
}
$rulesDst = Join-Path $TARGET "rules.md"

if (Test-Path $rulesSrc) {
    $needCopy = $true
    if (Test-Path $rulesDst) {
        $srcHash = (Get-FileHash $rulesSrc -Algorithm SHA256).Hash
        $dstHash = (Get-FileHash $rulesDst -Algorithm SHA256).Hash
        if ($srcHash -eq $dstHash) { $needCopy = $false }
    }
    if ($needCopy) {
        Copy-Item $rulesSrc $rulesDst -Force
        Write-Ok "rules.md 已安装"
    } else {
        Write-Ok "rules.md 已存在且内容相同，跳过"
    }
} else {
    Write-Err "rules.md 源文件不存在: $rulesSrc"
}

# ════════════════════════════════════════
# Step 4: 创建 .sofagent/ 数据目录
# ════════════════════════════════════════
Write-Info "Step 4/4 · 初始化数据目录 → $SOFAGENT_DATA"

if (-not (Test-Path $SOFAGENT_DATA)) {
    New-Item -ItemType Directory -Path (Join-Path $SOFAGENT_DATA "task\logs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $SOFAGENT_DATA "orchestrator\workflows") -Force | Out-Null
    Write-Ok "数据目录已创建: $SOFAGENT_DATA"
} else {
    Write-Ok "数据目录已存在: $SOFAGENT_DATA"
    # 确保子目录存在
    if (-not (Test-Path (Join-Path $SOFAGENT_DATA "task\logs"))) {
        New-Item -ItemType Directory -Path (Join-Path $SOFAGENT_DATA "task\logs") -Force | Out-Null
    }
    if (-not (Test-Path (Join-Path $SOFAGENT_DATA "orchestrator\workflows"))) {
        New-Item -ItemType Directory -Path (Join-Path $SOFAGENT_DATA "orchestrator\workflows") -Force | Out-Null
    }
}

# ════════════════════════════════════════
# Step 5（仅 OpenClaw）：部署加载链 Hook + 注入断路器（对齐 install.sh Step 6/7）
# ════════════════════════════════════════
if ($Platform -eq "openclaw") {
    $utf8b = New-Object System.Text.UTF8Encoding $false
    # ── Hook 部署 ──
    Write-Info "OpenClaw · 部署加载链 Hook..."
    $hookSrc = Join-Path $SKILL_SRC_DIR "hooks\sofagent-load-chain"
    $hookDst = Join-Path $TARGET "hooks\sofagent-load-chain"
    if ((Test-Path (Join-Path $hookSrc "HOOK.md")) -and (Test-Path (Join-Path $hookSrc "handler.ts"))) {
        New-Item -ItemType Directory -Force -Path $hookDst | Out-Null
        Copy-Item (Join-Path $hookSrc "HOOK.md") (Join-Path $hookDst "HOOK.md") -Force
        Copy-Item (Join-Path $hookSrc "handler.ts") (Join-Path $hookDst "handler.ts") -Force
        Write-Ok "加载链 Hook 已部署: $hookDst"
        # 注册 openclaw.json: hooks.internal.entries.sofagent-load-chain = {enabled:true}
        $ocCfg = if ($env:OPENCLAW_CONFIG_PATH) { $env:OPENCLAW_CONFIG_PATH } else { Join-Path $TARGET "openclaw.json" }
        try {
            $j = if (Test-Path $ocCfg) { Get-Content $ocCfg -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
            if (-not $j.PSObject.Properties['hooks']) { $j | Add-Member hooks ([pscustomobject]@{}) }
            if (-not $j.hooks.PSObject.Properties['internal']) { $j.hooks | Add-Member internal ([pscustomobject]@{}) }
            $j.hooks.internal | Add-Member enabled $true -Force
            if (-not $j.hooks.internal.PSObject.Properties['entries']) { $j.hooks.internal | Add-Member entries ([pscustomobject]@{}) }
            $j.hooks.internal.entries | Add-Member "sofagent-load-chain" ([pscustomobject]@{ enabled = $true }) -Force
            if (Test-Path $ocCfg) { Copy-Item $ocCfg "$ocCfg.bak" -Force }
            [System.IO.File]::WriteAllText($ocCfg, ($j | ConvertTo-Json -Depth 10), $utf8b)
            Write-Ok "Hook 已注册: $ocCfg"
        } catch { Write-Warn "openclaw.json 注册失败（含注释/格式问题？）：$($_.Exception.Message)。手动加 hooks.internal.entries.sofagent-load-chain" }
    } else { Write-Warn "找不到 hook 源文件（$hookSrc），跳过" }

    # ── 断路器 loopDetection（受 -NoConfigInject 控）──
    if (-not $NoConfigInject) {
        Write-Info "OpenClaw · 注入断路器 loopDetection..."
        $cfgFile = if ($env:OPENCLAW_CONFIG_PATH) { $env:OPENCLAW_CONFIG_PATH } else { Join-Path $TARGET "config.json" }
        try {
            $cf = if (Test-Path $cfgFile) { Get-Content $cfgFile -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
            if ($cf.PSObject.Properties['tools'] -and $cf.tools.PSObject.Properties['loopDetection']) {
                Write-Ok "loopDetection 已存在，跳过"
            } else {
                $loop = [pscustomobject]@{ enabled = $true; historySize = 30; warningThreshold = 10; criticalThreshold = 20; globalCircuitBreakerThreshold = 30; detectors = [pscustomobject]@{ genericRepeat = $true; knownPollNoProgress = $true; pingPong = $true } }
                if (-not $cf.PSObject.Properties['tools']) { $cf | Add-Member tools ([pscustomobject]@{}) }
                $cf.tools | Add-Member loopDetection $loop -Force
                if (Test-Path $cfgFile) { Copy-Item $cfgFile "$cfgFile.bak" -Force }
                [System.IO.File]::WriteAllText($cfgFile, ($cf | ConvertTo-Json -Depth 10), $utf8b)
                Write-Ok "loopDetection 断路器已注入: $cfgFile"
            }
        } catch { Write-Warn "config.json 注入失败：$($_.Exception.Message)" }
    } else { Write-Info "(-NoConfigInject) 跳过断路器注入" }
}

# ════════════════════════════════════════
# 安装完成
# ════════════════════════════════════════
Write-Host ""
Write-Host "  +====================================+"
Write-Host "  |  sofagent · 安装完成！             |"
Write-Host "  +====================================+"
Write-Host ""
Write-Host "  已部署文件："
Write-Host "    Skill 文件:  $SKILL_DST"
Write-Host "    宪法文件:    $rulesDst"
Write-Host "    数据目录:    $SOFAGENT_DATA"
Write-Host ""
Write-Host "  下一步："
Write-Host "    1. 在 WorkBuddy 中打开项目: $ProjectDir"
Write-Host "    2. 开始新对话，sofagent Skill 应自动加载"
Write-Host "    3. 回复 'sofagent' 验证是否加载成功"
Write-Host ""
