#requires -Version 5.1
<#
.SYNOPSIS
    Update the Codex and Claude Code agent instructions in one command.

.DESCRIPTION
    Runs the existing Codex and Claude Code update wrappers sequentially. Codex is
    updated first. The workflow stops immediately if either child script fails.

    This is a sequential convenience wrapper, not a cross-runtime transaction.

.EXAMPLE
    .\scripts\update-all-agents.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-AgentUpdate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    Write-Host ""
    Write-Host "==> Update $Name" -ForegroundColor Cyan

    & $ScriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "$Name update failed with exit code $LASTEXITCODE."
    }
}

try {
    $codexScript = Join-Path $PSScriptRoot 'update-codex-agent.ps1'
    $claudeScript = Join-Path $PSScriptRoot 'update-claude-agent.ps1'

    Invoke-AgentUpdate -Name 'Codex' -ScriptPath $codexScript
    Invoke-AgentUpdate -Name 'Claude Code' -ScriptPath $claudeScript

    Write-Host ""
    Write-Host 'All agent updates completed successfully.' -ForegroundColor Green
    Write-Host 'Restart Codex and Claude Code so new sessions load the updated instructions.' -ForegroundColor Yellow
    exit 0
}
catch {
    Write-Host ""
    Write-Host ("Combined agent update failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
