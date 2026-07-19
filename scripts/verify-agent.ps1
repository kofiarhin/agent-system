#requires -Version 5.1
<#
.SYNOPSIS
    Verify source modules, generated artifacts, and installed runtime files.

.PARAMETER Scope
    Source    - validate the manifest, adapters, and source modules.
    Generated - validate compiled artifacts (warning, title, header, order, anchors, freshness).
    Installed - compare installed runtime files against generated artifacts.
    All       - Source and Generated (default). Installed is checked only when requested.

.PARAMETER Runtime
    Restrict Generated/Installed checks to a single registered runtime.

.PARAMETER Strict
    Treat warnings as failures.

.EXAMPLE
    .\scripts\verify-agent.ps1

.EXAMPLE
    .\scripts\verify-agent.ps1 -Scope Installed -Runtime codex
#>
[CmdletBinding()]
param(
    [ValidateSet('Source','Generated','Installed','All')]
    [string]$Scope = 'All',
    [string]$Runtime = 'All',
    [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Configuration.ps1')
. (Join-Path $PSScriptRoot 'lib/Compilation.ps1')
. (Join-Path $PSScriptRoot 'lib/Validation.ps1')

try {
    $repoRoot = Resolve-RepoRoot -StartPath $PSScriptRoot
    Write-Section "Verify (scope=$Scope, runtime=$Runtime)"
    $cfg = Import-AgentConfig -RepoRoot $repoRoot
    $all = @()

    # Manifest always validated.
    $all += Test-AgentConfig -AgentConfig $cfg -RepoRoot $repoRoot
    $runtimes = @(Resolve-RuntimeSelection -AgentConfig $cfg -RepoRoot $repoRoot -Runtime $Runtime)
    $all += Test-AdapterConfig -AgentConfig $cfg -RepoRoot $repoRoot -RuntimeIds $runtimes

    if ($Scope -in @('Source','All')) {
        $all += Test-SourceModules -AgentConfig $cfg -RepoRoot $repoRoot
    }
    if ($Scope -in @('Generated','All')) {
        foreach ($id in $runtimes) {
            $all += Test-GeneratedOutput -AgentConfig $cfg -RepoRoot $repoRoot -RuntimeId $id -Strict:$Strict
        }
    }
    if ($Scope -eq 'Installed') {
        foreach ($id in $runtimes) {
            $all += Test-InstalledOutput -AgentConfig $cfg -RepoRoot $repoRoot -RuntimeId $id
        }
    }

    Write-Section 'Results'
    $all | Select-Object Check, Runtime, Result, Details | Format-Table -AutoSize | Out-String | Write-Host

    $fails = @($all | Where-Object { $_.Result -eq 'Fail' })
    $warns = @($all | Where-Object { $_.Result -eq 'Warn' })
    $pass  = @($all | Where-Object { $_.Result -eq 'Pass' })
    $skip  = @($all | Where-Object { $_.Result -eq 'Skip' })

    Write-Host ("Pass: {0}  Fail: {1}  Warn: {2}  Skip: {3}" -f $pass.Count, $fails.Count, $warns.Count, $skip.Count)

    if ($fails.Count -gt 0) { Write-Host 'Verification FAILED.' -ForegroundColor Red; exit 1 }
    if ($Strict -and $warns.Count -gt 0) { Write-Host 'Verification FAILED (strict warnings).' -ForegroundColor Red; exit 1 }
    Write-Host 'Verification passed.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Fail $_.Exception.Message
    exit 1
}
