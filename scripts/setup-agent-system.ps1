#requires -Version 5.1
<#
.SYNOPSIS
    Install Agent System instructions into detected Codex, Claude Code, and Gemini CLI runtimes.
.DESCRIPTION
    Detects supported runtime directories from adapter metadata, then sequentially builds,
    verifies, previews, installs, and verifies each detected runtime. It does not clone or pull.
.PARAMETER Force
    Reinstall even when an installed runtime file already matches the generated artifact.
.EXAMPLE
    .\scripts\setup-agent-system.ps1
.EXAMPLE
    .\scripts\setup-agent-system.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param([switch]$Force)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Configuration.ps1')
. (Join-Path $PSScriptRoot 'lib/Compilation.ps1')
. (Join-Path $PSScriptRoot 'lib/Validation.ps1')
. (Join-Path $PSScriptRoot 'lib/RuntimeDetection.ps1')
. (Join-Path $PSScriptRoot 'lib/RefreshWorkflow.ps1')

try {
    $repoRoot = Resolve-RepoRoot -StartPath $PSScriptRoot
    Write-Section 'Agent System first-time setup'
    Write-Info "Repository: $repoRoot"

    $cfg = Import-AgentConfig -RepoRoot $repoRoot
    $manifestResults = Test-AgentConfig -AgentConfig $cfg -RepoRoot $repoRoot
    if ($manifestResults | Where-Object { $_.Result -eq 'Fail' }) {
        Show-ResultFailures $manifestResults
        throw 'Manifest validation failed.'
    }

    $runtimeIds = @('codex', 'claude', 'gemini')
    $adapterResults = Test-AdapterConfig -AgentConfig $cfg -RepoRoot $repoRoot -RuntimeIds $runtimeIds
    if ($adapterResults | Where-Object { $_.Result -eq 'Fail' }) {
        Show-ResultFailures $adapterResults
        throw 'Supported runtime adapter validation failed.'
    }

    $detection = @(Get-DetectedAgentRuntimes -RepoRoot $repoRoot -RuntimeIds $runtimeIds)
    Show-AgentRuntimeDetection -Results $detection

    $detectedNames = @($detection | Where-Object { $_.Detected } | ForEach-Object { $_.DisplayName })
    if ($detectedNames.Count -eq 0) {
        Write-Fail 'No supported runtime directories were detected.'
        Write-Host 'Install and launch Codex, Claude Code, or Gemini CLI first. No runtime folders were created.' -ForegroundColor Yellow
        exit 2
    }

    if (-not $WhatIfPreference) {
        $target = $detectedNames -join ', '
        if (-not $PSCmdlet.ShouldProcess($target, 'Build, verify, install, and verify Agent System instructions')) {
            Write-Info 'Setup cancelled.'
            exit 0
        }
    }

    $refresh = Invoke-AgentSystemRefresh -RepoRoot $repoRoot -RuntimeRecords $detection -Mode Setup -Force:$Force -WhatIf:$WhatIfPreference
    Show-AgentRefreshSummary -RefreshResult $refresh -DetectionResults $detection
    exit $refresh.ExitCode
}
catch {
    Write-Host ''
    Write-Fail $_.Exception.Message
    exit 1
}
