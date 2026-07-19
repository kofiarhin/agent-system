#requires -Version 5.1
<#
.SYNOPSIS
    Compile shared instruction modules into runtime-specific instruction files.

.DESCRIPTION
    Deterministically builds generated/<runtime>/<file> from the shared modules
    declared in config/agent.json, applying each runtime adapter. The build never
    installs files into runtime directories.

.PARAMETER Runtime
    A registered runtime id, or 'All' (default) to build every enabled runtime.

.PARAMETER Clean
    Remove the generated output files known to the configuration for the selected
    runtimes, then exit without building.

.PARAMETER Check
    Compile in memory and fail (non-zero exit) if any checked-in generated file is
    missing or stale. Does not write files.

.EXAMPLE
    .\scripts\build-agent.ps1 -Runtime All

.EXAMPLE
    .\scripts\build-agent.ps1 -Runtime codex -Verbose
#>
[CmdletBinding()]
param(
    [string]$Runtime = 'All',
    [switch]$Clean,
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Configuration.ps1')
. (Join-Path $PSScriptRoot 'lib/Compilation.ps1')
. (Join-Path $PSScriptRoot 'lib/Validation.ps1')

function Show-Results {
    param([array]$Results)
    foreach ($r in $Results) {
        switch ($r.Result) {
            'Pass' { Write-Ok   ("{0} [{1}] {2}" -f $r.Check, $r.Runtime, $r.Details) }
            'Fail' { Write-Fail ("{0} [{1}] {2}" -f $r.Check, $r.Runtime, $r.Details) }
            'Warn' { Write-Warn ("{0} [{1}] {2}" -f $r.Check, $r.Runtime, $r.Details) }
            'Skip' { Write-Info ("{0} [{1}] {2}" -f $r.Check, $r.Runtime, $r.Details) }
        }
    }
}

try {
    $repoRoot = Resolve-RepoRoot -StartPath $PSScriptRoot
    Write-Section "Build ($repoRoot)"
    $cfg = Import-AgentConfig -RepoRoot $repoRoot

    $manifestResults = Test-AgentConfig -AgentConfig $cfg -RepoRoot $repoRoot
    Show-Results $manifestResults
    if ($manifestResults | Where-Object { $_.Result -eq 'Fail' }) { throw 'Manifest validation failed.' }

    $runtimes = @(Resolve-RuntimeSelection -AgentConfig $cfg -RepoRoot $repoRoot -Runtime $Runtime)
    if ($runtimes.Count -eq 0) { throw "No enabled runtimes selected for '$Runtime'." }
    Write-Info ("Runtimes: {0}" -f ($runtimes -join ', '))

    $adapterResults = Test-AdapterConfig -AgentConfig $cfg -RepoRoot $repoRoot -RuntimeIds $runtimes
    Show-Results $adapterResults
    if ($adapterResults | Where-Object { $_.Result -eq 'Fail' }) { throw 'Adapter validation failed.' }

    $sourceResults = Test-SourceModules -AgentConfig $cfg -RepoRoot $repoRoot
    if ($sourceResults | Where-Object { $_.Result -eq 'Fail' }) {
        Show-Results ($sourceResults | Where-Object { $_.Result -eq 'Fail' })
        throw 'Source module validation failed.'
    }
    Write-Ok ("Source modules valid ({0})" -f (@($cfg.modules).Count))

    # -Clean: remove known generated files and exit.
    if ($Clean) {
        Write-Section 'Clean'
        foreach ($id in $runtimes) {
            $adapter = Import-AdapterConfig -RepoRoot $repoRoot -RuntimeId $id
            $out = Resolve-AdapterOutputPath -RepoRoot $repoRoot -Adapter $adapter
            if (Test-PathWithinRoot -Candidate $out -Root (Join-Path $repoRoot 'generated')) {
                if (Test-Path -LiteralPath $out) {
                    Remove-Item -LiteralPath $out -Force
                    Write-Ok "Removed $($out.Substring($repoRoot.Length + 1))"
                } else {
                    Write-Info "Nothing to remove for $id"
                }
            }
        }
        Write-Host ""
        Write-Host 'Clean complete.' -ForegroundColor Green
        exit 0
    }

    Write-Section ($(if ($Check) { 'Check (no write)' } else { 'Compile' }))
    $summary = @()
    $stale = $false
    foreach ($id in $runtimes) {
        $adapter = Import-AdapterConfig -RepoRoot $repoRoot -RuntimeId $id
        $out = Resolve-AdapterOutputPath -RepoRoot $repoRoot -Adapter $adapter

        $doc = Build-RuntimeDocument -AgentConfig $cfg -Adapter $adapter -RepoRoot $repoRoot
        if ([string]::IsNullOrWhiteSpace($doc)) { throw "Compiled content is empty for '$id'." }
        $vars = @(Get-UnresolvedVariables -Text $doc)
        if ($vars.Count -gt 0) { throw "Unresolved variables in '$id': $($vars -join ', ')" }

        $bytes = ConvertTo-AgentBytes -Content $doc -LineEnding $cfg.compilation.lineEnding -Encoding $cfg.compilation.encoding
        $newHash = Get-Sha256FromBytes -Bytes $bytes
        $relOut = $out.Substring($repoRoot.Length + 1)

        $existingHash = $null
        if (Test-Path -LiteralPath $out) { $existingHash = Get-Sha256OfFile -Path $out }

        if ($Check) {
            if ($null -eq $existingHash) {
                Write-Fail "$relOut missing"
                $stale = $true
                $summary += [pscustomobject]@{ Runtime=$id; Action='Missing'; File=$relOut }
            } elseif ($existingHash -ne $newHash) {
                Write-Fail "$relOut stale"
                $stale = $true
                $summary += [pscustomobject]@{ Runtime=$id; Action='Stale'; File=$relOut }
            } else {
                Write-Ok "$relOut up to date"
                $summary += [pscustomobject]@{ Runtime=$id; Action='UpToDate'; File=$relOut }
            }
            continue
        }

        if ($existingHash -eq $newHash) {
            Write-Ok "$relOut unchanged"
            $summary += [pscustomobject]@{ Runtime=$id; Action='Unchanged'; File=$relOut }
        } else {
            Write-BytesAtomic -Path $out -Bytes $bytes
            $verify = Get-Sha256OfFile -Path $out
            if ($verify -ne $newHash) { throw "Post-write hash verification failed for '$id'." }
            Write-Ok "$relOut written ($($bytes.Length) bytes)"
            $summary += [pscustomobject]@{ Runtime=$id; Action='Written'; File=$relOut }
        }
    }

    Write-Section 'Summary'
    $summary | Format-Table -AutoSize | Out-String | Write-Host

    if ($Check -and $stale) {
        Write-Host 'Generated files are stale. Run build-agent.ps1 to refresh.' -ForegroundColor Red
        exit 2
    }
    Write-Host 'Build complete. No files were installed.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Fail $_.Exception.Message
    exit 1
}
