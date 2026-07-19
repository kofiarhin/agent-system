#requires -Version 5.1
<#
.SYNOPSIS
    Build, verify, preview, install, and verify the Claude Code agent instructions.

.DESCRIPTION
    Runs the supported Claude Code update workflow by delegating to the existing build,
    verification, and installation scripts. The workflow stops immediately when any
    step fails.

.EXAMPLE
    .\scripts\update-claude-agent.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-AgentStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan

    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

try {
    $buildScript = Join-Path $PSScriptRoot 'build-agent.ps1'
    $verifyScript = Join-Path $PSScriptRoot 'verify-agent.ps1'
    $installScript = Join-Path $PSScriptRoot 'install-agent.ps1'

    Invoke-AgentStep -Name 'Build Claude Code artifact' -Action {
        & $buildScript -Runtime claude
    }

    Invoke-AgentStep -Name 'Verify generated Claude Code artifact' -Action {
        & $verifyScript -Scope Generated -Runtime claude
    }

    Invoke-AgentStep -Name 'Preview Claude Code installation' -Action {
        & $installScript -Runtime claude -WhatIf
    }

    Invoke-AgentStep -Name 'Install Claude Code artifact' -Action {
        & $installScript -Runtime claude
    }

    Invoke-AgentStep -Name 'Verify installed Claude Code artifact' -Action {
        & $verifyScript -Scope Installed -Runtime claude
    }

    Write-Host ""
    Write-Host 'Claude Code agent update completed successfully.' -ForegroundColor Green
    Write-Host 'Restart Claude Code so new sessions load the updated instructions.' -ForegroundColor Yellow
    exit 0
}
catch {
    Write-Host ""
    Write-Host ("Claude Code agent update failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
