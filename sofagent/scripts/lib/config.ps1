# ============================================================
# sofagent lib/config.ps1 · 企业合规共享配置加载器 (PowerShell)
# ============================================================
# config.sh 的原生 Windows 移植。从 rules.md 提取合规配置，设为 $env:SOFA_*。
# 用法（在其他 .ps1 顶部 dot-source）：
#   $cfg = Join-Path $PSScriptRoot "lib\config.ps1"; if (Test-Path $cfg) { . $cfg }
#
# 行为对齐 config.sh：总是从 rules.md/默认值设置（覆盖已有 env），保持与 .sh 一致。
# ============================================================

# ── 定位 rules.md（候选路径，对齐 config.sh）──
function Find-SofaRulesFile {
    $sofagentRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)  # scripts/lib -> scripts -> sofagent
    $candidates = @(
        (Join-Path (Get-Location).Path "rules.md"),
        (Join-Path $sofagentRoot "rules.md"),
        "$env:USERPROFILE\.openclaw\skills\sofagent\rules.md",
        "$env:USERPROFILE\.openclaw\rules.md",
        "$env:USERPROFILE\.openclaw\skills\sofagent\constitution\rules.md",
        "$env:USERPROFILE\.workbuddy\rules.md"
    )
    foreach ($c in $candidates) {
        if (-not [string]::IsNullOrEmpty($c) -and (Test-Path $c)) { return $c }
    }
    return $null
}

$script:SofaRulesFile = Find-SofaRulesFile

# ── 从 rules.md 提取 key: value（仅非注释行，即已启用项）──
function Get-SofaConf($key, $default) {
    if ([string]::IsNullOrEmpty($script:SofaRulesFile)) { return $default }
    $m = Select-String -Path $script:SofaRulesFile -Pattern "^${key}:" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($m) {
        return ($m.Line -replace "^[^:]+:\s*", "" -replace "\s+$", "")
    }
    return $default
}

# ── 导出配置到 $env:（进程内可见，dot-source 后供调用脚本读取）──
$env:SOFA_SANITIZE         = Get-SofaConf "log_sanitize"               ""
$env:SOFA_SANITIZE_IPS     = Get-SofaConf "log_sanitize_ips"           ""
$env:SOFA_RETENTION_DAYS   = Get-SofaConf "data_retention_days"        "90"
$env:SOFA_RETENTION_MAX    = Get-SofaConf "data_retention_max_entries" "500"
$env:SOFA_CLEANUP_ON_RECORD = Get-SofaConf "data_cleanup_on_record"    ""
$env:SOFA_CLEANUP_FREQUENCY = Get-SofaConf "data_cleanup_frequency"    "10"
$env:SOFA_AUDIT_ENABLED    = Get-SofaConf "audit_enabled"              ""
