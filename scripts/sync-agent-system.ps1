#requires -Version 5.1
<#
.SYNOPSIS
    Pull the latest Agent System changes and refresh detected local runtimes.
.DESCRIPTION
    By default validates a clean main branch, runs git pull --rebase origin main, then
    detects Codex, Claude Code, and Gemini CLI and refreshes each detected runtime.
.PARAMETER SkipPull
    Use the current local checkout without invoking Git.
.PARAMETER Force
    Reinstall even when an installed runtime file already matches the generated artifact.
.EXAMPLE
    .\scripts\sync-agent-system.ps1
.EXAMPLE
    .\scripts\sync-agent-system.ps1 -SkipPull
.EXAMPLE
    .\scripts\sync-agent-system.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$SkipPull,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Configuration.ps1')
. (Join-Path $PSScriptRoot 'lib/Compilation.ps1')
. (Join-Path $PSScriptRoot 'lib/Validation.ps1')
. (Join-Path $PSScriptRoot 'lib/RuntimeDetection.ps1')
. (Join-Path $PSScriptRoot 'lib/RefreshWorkflow.ps1')

function Invoke-GitChecked {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = & git -C $RepoRoot @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw ("git {0} failed (exit {1}): {2}" -f ($Arguments -join ' '), $code, ($output -join [Environment]::NewLine))
    }
    return @($output)
}

function Test-RepositoryReadyForPull {
    param([Parameter(Mandatory)][string]$RepoRoot)

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is not available on PATH.'
    }

    [void](Invoke-GitChecked -RepoRoot $RepoRoot -Arguments @('rev-parse','--is-inside-work-tree'))
    $branch = ((Invoke-GitChecked -RepoRoot $RepoRoot -Arguments @('rev-parse','--abbrev-ref','HEAD')) -join '').Trim()
    if ($branch -ne 'main') {
        throw "Synchronization requires branch 'main'; current branch is '$branch'. Use -SkipPull only when intentionally testing another checkout."
    }

    $status = (Invoke-GitChecked -RepoRoot $RepoRoot -Arguments @('status','--porcelain','--untracked-files=all')) -join [Environment]::NewLine
    if (-not [string]::IsNullOrWhiteSpace($status)) {
        throw 'The working tree is not clean. Commit, stash, or remove local changes before syncing; this command will not modify them.'
    }
}

try {
    $repoRoot = Resolve-RepoRoot -StartPath $PSScriptRoot
    Write-Section 'Agent System synchronization'
    Write-Info "Repository: $repoRoot"

    if (-not $WhatIfPreference) {
        $action = if ($SkipPull) { 'Refresh detected runtimes from the current checkout' } else { 'Pull origin/main and refresh detected runtimes' }
        if (-not $PSCmdlet.ShouldProcess($repoRoot, $action)) {
            Write-Info 'Synchronization cancelled.'
            exit 0
        }
    }

    if (-not $SkipPull) {
        Write-Section 'Pull latest Agent System changes'
        if ($WhatIfPreference) {
            Write-Info 'Would validate Git state and run: git pull --rebase origin main'
        } else {
            Test-RepositoryReadyForPull -RepoRoot $repoRoot
            $pullOutput = Invoke-GitChecked -RepoRoot $repoRoot -Arguments @('pull','--rebase','origin','main')
            $pullOutput | ForEach-Object { if ($_ -ne $null) { Write-Info ([string]$_) } }
            Write-Ok 'Repository synchronized with origin/main.'
        }
    } else {
        Write-Info 'Git pull skipped; using the current local checkout.'
    }

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

    if (@($detection | Where-Object { $_.Detected }).Count -eq 0) {
        Write-Fail 'No supported runtime directories were detected.'
        Write-Host 'Install and launch Codex, Claude Code, or Gemini CLI first. No runtime folders were created.' -ForegroundColor Yellow
        exit 2
    }

    $refresh = Invoke-AgentSystemRefresh -RepoRoot $repoRoot -RuntimeRecords $detection -Mode Sync -Force:$Force -WhatIf:$WhatIfPreference
    Show-AgentRefreshSummary -RefreshResult $refresh -DetectionResults $detection
    exit $refresh.ExitCode
}
catch {
    Write-Host ''
    Write-Fail $_.Exception.Message
    if ($_.Exception.Message -match 'Git|git |working tree|branch') { exit 3 }
    exit 1
}
