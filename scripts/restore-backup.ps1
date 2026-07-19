#requires -Version 5.1
<#
.SYNOPSIS
    Restore runtime instruction files from a verified backup.

.DESCRIPTION
    Lists backups, or restores a specific/latest backup for one or all runtimes.
    Validates backup hashes, backs up the current target before restoring, restores
    atomically, verifies restored hashes, and rejects targets outside approved
    runtime roots.

.PARAMETER List
    List available backups and exit.

.PARAMETER Latest
    Use the most recent backup that contains the requested runtime(s).

.PARAMETER BackupId
    Restore from a specific backup id (directory name under backups/).

.PARAMETER Runtime
    A registered runtime id, or 'All' (default).

.PARAMETER TargetMap
    Test/override hashtable mapping runtime id -> absolute target path, keeping
    restoration inside temporary directories during tests.

.EXAMPLE
    .\scripts\restore-backup.ps1 -List

.EXAMPLE
    .\scripts\restore-backup.ps1 -Latest -Runtime codex -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$List,
    [switch]$Latest,
    [string]$BackupId,
    [string]$Runtime = 'All',
    [hashtable]$TargetMap = @{}
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/Common.ps1')
. (Join-Path $PSScriptRoot 'lib/Configuration.ps1')
. (Join-Path $PSScriptRoot 'lib/Backup.ps1')

function Resolve-RestoreTarget {
    param($Adapter, [hashtable]$Map, [string]$RuntimeId, [string]$ManifestOriginal)
    if ($Map -and $Map.ContainsKey($RuntimeId)) {
        $p = $Map[$RuntimeId]
        return [pscustomobject]@{ Path = $p; ApprovedRoots = @((Split-Path -Parent $p)) }
    }
    $p = Resolve-AdapterInstallPath -Adapter $Adapter
    return [pscustomobject]@{ Path = $p; ApprovedRoots = (Get-AdapterApprovedRoots -Adapter $Adapter) }
}

try {
    $repoRoot = Resolve-RepoRoot -StartPath $PSScriptRoot
    $cfg = Import-AgentConfig -RepoRoot $repoRoot

    if ($List) {
        Write-Section 'Available backups'
        $backups = @(Get-BackupList -RepoRoot $repoRoot)
        if ($backups.Count -eq 0) { Write-Info 'No backups found.'; exit 0 }
        foreach ($b in $backups) {
            $m = Import-BackupManifest -BackupDir $b.FullName
            $rts = (@($m.files) | ForEach-Object { $_.runtime } | Select-Object -Unique) -join ', '
            Write-Info ("{0}  op={1}  files={2}  runtimes=[{3}]" -f $b.Name, $m.operation, $m.fileCount, $rts)
        }
        exit 0
    }

    if (-not $BackupId -and -not $Latest) {
        throw 'Specify -List, -Latest, or -BackupId.'
    }

    $requestedRuntimes = @(Resolve-RuntimeSelection -AgentConfig $cfg -RepoRoot $repoRoot -Runtime $Runtime)

    # Resolve backup directory.
    if ($Latest) {
        $rtForLatest = if ($Runtime -eq 'All') { $null } else { $Runtime }
        $b = Get-LatestBackup -RepoRoot $repoRoot -RuntimeId $rtForLatest
        if (-not $b) { throw 'No matching backup found.' }
        $backupDir = $b.FullName
        $BackupId = $b.Name
    } else {
        $backupDir = Join-Path (Join-Path $repoRoot 'backups') $BackupId
        if (-not (Test-Path -LiteralPath $backupDir)) { throw "Backup not found: $BackupId" }
    }

    Write-Section "Restore from $BackupId (runtime=$Runtime)"

    # Validate backup integrity before touching any target.
    $check = Test-BackupManifest -BackupDir $backupDir
    if (-not $check.Ok) { throw "Backup integrity check failed: $($check.Details)" }
    Write-Ok 'Backup hashes verified.'
    $manifest = $check.Manifest

    $preBackupId = Get-UtcTimestamp
    $preBackupInfo = $null
    $preEntries = @()
    $restored = @()

    foreach ($id in $requestedRuntimes) {
        $entry = @($manifest.files) | Where-Object { $_.runtime -eq $id } | Select-Object -First 1
        if (-not $entry) {
            Write-Info "Runtime '$id' not present in backup; skipping."
            continue
        }
        $adapter = Import-AdapterConfig -RepoRoot $repoRoot -RuntimeId $id
        $target = Resolve-RestoreTarget -Adapter $adapter -Map $TargetMap -RuntimeId $id -ManifestOriginal $entry.originalPath
        if (-not $target.Path) { throw "No restore target for '$id'." }

        $within = $false
        foreach ($r in $target.ApprovedRoots) { if (Test-PathWithinRoot -Candidate $target.Path -Root $r) { $within = $true; break } }
        if (-not $within) { throw "Refusing to restore '$id': target outside approved runtime roots." }

        Write-Section "Plan: $id"
        Write-Info "Backup file  : $($entry.backupName)"
        Write-Info "Restore to   : $($target.Path)"
        Write-Info "Target exists: $(Test-Path -LiteralPath $target.Path)"

        if (-not $PSCmdlet.ShouldProcess($target.Path, "Restore $id from backup $BackupId")) {
            $restored += [pscustomobject]@{ Runtime=$id; Action='WhatIf'; Target=$target.Path }
            continue
        }

        # Back up current target before restoring.
        if (Test-Path -LiteralPath $target.Path) {
            if (-not $preBackupInfo) { $preBackupInfo = New-BackupDirectory -RepoRoot $repoRoot -BackupId $preBackupId }
            $preEntries += Copy-FileWithHash -SourcePath $target.Path -BackupDir $preBackupInfo.Path -RuntimeId $id -BackupId $preBackupId
            Write-Ok 'Current target backed up before restore.'
        }

        # Restore atomically via temp file.
        $targetDir = Split-Path -Parent $target.Path
        if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        $tmp = Join-Path $targetDir ((Split-Path -Leaf $target.Path) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
        try {
            Copy-Item -LiteralPath $entry.backupPath -Destination $tmp -Force
            if ((Get-Sha256OfFile -Path $tmp) -ne $entry.sha256) { throw 'Restored temp file failed hash validation.' }
            Move-Item -LiteralPath $tmp -Destination $target.Path -Force
            if ((Get-Sha256OfFile -Path $target.Path) -ne $entry.sha256) { throw 'Restored file hash mismatch.' }
            Write-Ok "$id restored and verified."
            $restored += [pscustomobject]@{ Runtime=$id; Action='Restored'; Target=$target.Path }
        }
        finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        }
    }

    if ($preBackupInfo -and $preEntries.Count -gt 0) {
        $mp = Write-BackupManifest -BackupDir $preBackupInfo.Path -BackupId $preBackupId -Entries $preEntries -Operation 'pre-restore'
        Write-Info "Pre-restore backup manifest: $mp"
    }

    Write-Section 'Summary'
    $restored | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host 'Restore complete.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Fail $_.Exception.Message
    exit 1
}
