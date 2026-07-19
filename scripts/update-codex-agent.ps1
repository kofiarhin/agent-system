#requires -Version 5.1
<#
.SYNOPSIS
    Build, verify, preview, install, and verify the Codex agent instructions.

.DESCRIPTION
    Runs the supported Codex update workflow by delegating to the existing build,
    verification, and installation scripts. The workflow stops immediately when any
    step fails.

.EXAMPLE
    .\scripts\update-codex-agent.ps1
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

    Invoke-AgentStep -Name 'Build Codex artifact' -Action {
        & $buildScript -Runtime codex
    }

    Invoke-AgentStep -Name 'Verify generated Codex artifact' -Action {
        & $verifyScript -Scope Generated -Runtime codex
    }

    Invoke-AgentStep -Name 'Preview Codex installation' -Action {
        & $installScript -Runtime codex -WhatIf
    }

    Invoke-AgentStep -Name 'Install Codex artifact' -Action {
        & $installScript -Runtime codex
    }

    Invoke-AgentStep -Name 'Verify installed Codex artifact' -Action {
        & $verifyScript -Scope Installed -Runtime codex
    }

    Write-Host ""
    Write-Host 'Codex agent update completed successfully.' -ForegroundColor Green
    Write-Host 'Restart Codex so new sessions load the updated instructions.' -ForegroundColor Yellow
    exit 0
}
catch {
    Write-Host ""
    Write-Host ("Codex agent update failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
