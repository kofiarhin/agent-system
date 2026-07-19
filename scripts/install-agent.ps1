#requires -Version 5.1
<#
.SYNOPSIS
    Install generated runtime instruction files into their runtime directories,
    with verified backups, atomic replacement, and automatic rollback.

.DESCRIPTION
    For each selected runtime the installer verifies the generated artifact,
    confirms the target is an approved adapter path, backs up any existing target,
    installs through a temporary file, replaces atomically, and verifies the
    installed hash. A failed replacement is rolled back from the verified backup.

    Supports -WhatIf and -Confirm via SupportsShouldProcess.

.PARAMETER Runtime
    A registered runtime id, or 'All' (default) for every enabled, installable runtime.

.PARAMETER Force
    Reinstall even when the target already matches the generated artifact.

.PARAMETER TargetMap
    Test/override hashtable mapping runtime id -> absolute target path. When a
    runtime is present here, that path (and its parent directory) is treated as the
    approved target, bypassing the real runtime directory. Used by the test suite to
    keep installation inside temporary directories.

.EXAMPLE
    .\scripts\install-agent.ps1 -Runtime All -WhatIf

.EXAMPLE
    .\scripts\install-agent.ps1 -Runtime codex
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$Runtime = 'All',
    [switch]$Force,
    [hashtable]$TargetMap = @{}
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Configuration.ps1')
. (Join-Path $PSScriptRoot 'lib/Compilation.ps1')
. (Join-Path $PSScriptRoot 'lib/Validation.ps1')
. (Join-Path $PSScriptRoot 'lib/Backup.ps1')

function Resolve-Target {
    param($Adapter, [hashtable]$Map)
    if ($Map -and $Map.ContainsKey($Adapter.id)) {
        $p = $Map[$Adapter.id]
        return [pscustomobject]@{ Path = $p; ApprovedRoots = @((Split-Path -Parent $p)) }
    }
    $p = Resolve-AdapterInstallPath -Adapter $Adapter
    return [pscustomobject]@{ Path = $p; ApprovedRoots = (Get-AdapterApprovedRoots -Adapter $Adapter) }
}

try {
    $repoRoot = Resolve-RepoRoot -StartPath $PSScriptRoot
    Write-Section "Install (runtime=$Runtime)"
    $cfg = Import-AgentConfig -RepoRoot $repoRoot

    $manifestResults = Test-AgentConfig -AgentConfig $cfg -RepoRoot $repoRoot
    if ($manifestResults | Where-Object { $_.Result -eq 'Fail' }) { throw 'Manifest validation failed.' }

    $runtimes = @(Resolve-RuntimeSelection -AgentConfig $cfg -RepoRoot $repoRoot -Runtime $Runtime)
    $backupId = Get-UtcTimestamp
    $backupInfo = $null
    $manifestEntries = @()
    $installed = @()

    foreach ($id in $runtimes) {
        $adapter = Import-AdapterConfig -RepoRoot $repoRoot -RuntimeId $id
        if (-not $adapter.installation.supported) {
            Write-Info "$id does not support installation; skipping."
            continue
        }

        # 1. Verify the generated artifact.
        $genResults = Test-GeneratedOutput -AgentConfig $cfg -RepoRoot $repoRoot -RuntimeId $id
        if ($genResults | Where-Object { $_.Result -eq 'Fail' }) {
            Show-ResultFailures $genResults
            throw "Generated artifact for '$id' failed verification. Build before installing."
        }
        $genPath = Resolve-AdapterOutputPath -RepoRoot $repoRoot -Adapter $adapter
        $genHash = Get-Sha256OfFile -Path $genPath

        # 2. Resolve and validate the target.
        $target = Resolve-Target -Adapter $adapter -Map $TargetMap
        if (-not $target.Path) { throw "No install path configured for '$id'." }
        $within = $false
        foreach ($r in $target.ApprovedRoots) { if (Test-PathWithinRoot -Candidate $target.Path -Root $r) { $within = $true; break } }
        if (-not $within) { throw "Refusing to install '$id': target '$($target.Path)' is outside approved runtime roots." }

        $exists = Test-Path -LiteralPath $target.Path
        if ($exists -and (Test-ItemIsReparsePoint -Path $target.Path)) {
            throw "Refusing to install '$id': target is a reparse point."
        }

        $upToDate = $false
        if ($exists) { $upToDate = ((Get-Sha256OfFile -Path $target.Path) -eq $genHash) }

        Write-Section "Plan: $id"
        Write-Info "Source artifact : $genPath"
        Write-Info "Target path     : $($target.Path)"
        Write-Info "Target exists   : $exists"
        Write-Info "Backup planned  : $exists"
        Write-Info "Already current : $upToDate"

        if ($upToDate -and -not $Force) {
            Write-Ok "$id already up to date; skipping (use -Force to reinstall)."
            $installed += [pscustomobject]@{ Runtime=$id; Action='Skipped'; Target=$target.Path }
            continue
        }

        if (-not $PSCmdlet.ShouldProcess($target.Path, "Install $id instruction file")) {
            $installed += [pscustomobject]@{ Runtime=$id; Action='WhatIf'; Target=$target.Path }
            continue
        }

        # 3. Back up existing target.
        $backupEntry = $null
        if ($exists) {
            if (-not $backupInfo) { $backupInfo = New-BackupDirectory -RepoRoot $repoRoot -BackupId $backupId }
            $backupEntry = Copy-FileWithHash -SourcePath $target.Path -BackupDir $backupInfo.Path -RuntimeId $id -BackupId $backupId
            $manifestEntries += $backupEntry
            Write-Ok "Backed up existing target -> $($backupEntry.backupName)"
        }

        # 4. Install through a temp file, then atomically replace.
        $targetDir = Split-Path -Parent $target.Path
        if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        $tmp = Join-Path $targetDir ((Split-Path -Leaf $target.Path) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
        try {
            Copy-Item -LiteralPath $genPath -Destination $tmp -Force
            if ((Get-Sha256OfFile -Path $tmp) -ne $genHash) { throw 'Temporary installed file failed hash validation.' }
            Move-Item -LiteralPath $tmp -Destination $target.Path -Force
            $insHash = Get-Sha256OfFile -Path $target.Path
            if ($insHash -ne $genHash) { throw 'Installed file hash does not match generated artifact.' }
            Write-Ok "$id installed and verified."
            $installed += [pscustomobject]@{ Runtime=$id; Action='Installed'; Target=$target.Path }
        }
        catch {
            Write-Fail "Installation of '$id' failed: $($_.Exception.Message)"
            if ($backupEntry) {
                Copy-Item -LiteralPath $backupEntry.backupPath -Destination $target.Path -Force
                if ((Get-Sha256OfFile -Path $target.Path) -eq $backupEntry.sha256) {
                    Write-Ok "Rolled back '$id' from verified backup."
                } else {
                    Write-Fail "Rollback verification FAILED for '$id'."
                }
            } elseif (Test-Path -LiteralPath $target.Path) {
                Remove-Item -LiteralPath $target.Path -Force
                Write-Ok "Removed partially installed fresh file for '$id'."
            }
            throw
        }
        finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        }
    }

    if ($backupInfo -and $manifestEntries.Count -gt 0) {
        $mp = Write-BackupManifest -BackupDir $backupInfo.Path -BackupId $backupId -Entries $manifestEntries -Operation 'install'
        Write-Info "Backup manifest: $mp"
    }

    Write-Section 'Summary'
    $installed | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host 'Install complete.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Fail $_.Exception.Message
    exit 1
}
