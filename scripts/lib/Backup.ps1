# Backup.ps1
# Backup and restore primitives for runtime instruction files.
# Requires Common.ps1 to be dot-sourced first.

Set-StrictMode -Version Latest

function New-BackupDirectory {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$BackupId = (Get-UtcTimestamp)
    )
    $base = Join-Path $RepoRoot 'backups'
    $id = $BackupId
    $dir = Join-Path $base $id
    # Avoid collisions when multiple backups are created within the same second.
    $suffix = 1
    while (Test-Path -LiteralPath $dir) {
        $id = "{0}-{1}" -f $BackupId, $suffix
        $dir = Join-Path $base $id
        $suffix++
    }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return [pscustomobject]@{ BackupId = $id; Path = (ConvertTo-NormalizedPath $dir) }
}

function Copy-FileWithHash {
    <#
        Copy a single file into a backup directory using a flat, safe name.
        Refuses to follow reparse points. Returns a manifest entry object.
    #>
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$BackupDir,
        [Parameter(Mandatory)][string]$RuntimeId,
        [Parameter(Mandatory)][string]$BackupId
    )
    if (Test-ItemIsReparsePoint -Path $SourcePath) {
        throw "Refusing to follow reparse point: $SourcePath"
    }
    $item = Get-Item -LiteralPath $SourcePath -Force
    $leaf = Split-Path -Leaf $SourcePath
    $destName = "{0}__{1}" -f $RuntimeId, $leaf
    $dest = Join-Path $BackupDir $destName
    Copy-Item -LiteralPath $SourcePath -Destination $dest -Force
    $srcHash = Get-Sha256OfFile -Path $SourcePath
    $dstHash = Get-Sha256OfFile -Path $dest
    if ($srcHash -ne $dstHash) {
        throw "Backup hash mismatch for $SourcePath"
    }
    return [ordered]@{
        runtime          = $RuntimeId
        originalPath     = (ConvertTo-NormalizedPath $SourcePath)
        backupPath       = (ConvertTo-NormalizedPath $dest)
        backupName       = $destName
        sha256           = $srcHash
        size             = $item.Length
        lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
        backupTimestamp  = $BackupId
    }
}

function Write-BackupManifest {
    param(
        [Parameter(Mandatory)][string]$BackupDir,
        [Parameter(Mandatory)][string]$BackupId,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Entries,
        [string]$Operation = 'install'
    )
    $obj = [ordered]@{
        backupId   = $BackupId
        createdUtc = (Get-Date).ToUniversalTime().ToString('o')
        operation  = $Operation
        fileCount  = $Entries.Count
        files      = $Entries
    }
    $json = $obj | ConvertTo-Json -Depth 8
    $path = Join-Path $BackupDir 'manifest.json'
    $bytes = ConvertTo-AgentBytes -Content $json -LineEnding 'crlf' -Encoding 'utf8NoBom'
    Write-BytesAtomic -Path $path -Bytes $bytes
    return $path
}

function Import-BackupManifest {
    param([Parameter(Mandatory)][string]$BackupDir)
    $path = Join-Path $BackupDir 'manifest.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Backup manifest not found: $path"
    }
    return (Read-TextFileRaw -Path $path | ConvertFrom-Json)
}

function Test-BackupManifest {
    <# Verify each backed-up file still matches its recorded hash. #>
    param([Parameter(Mandatory)][string]$BackupDir)
    $manifest = Import-BackupManifest -BackupDir $BackupDir
    $ok = $true
    $details = @()
    foreach ($f in @($manifest.files)) {
        if (-not (Test-Path -LiteralPath $f.backupPath)) {
            $ok = $false; $details += "missing: $($f.backupName)"; continue
        }
        $h = Get-Sha256OfFile -Path $f.backupPath
        if ($h -ne $f.sha256) { $ok = $false; $details += "hash mismatch: $($f.backupName)" }
    }
    return [pscustomobject]@{ Ok = $ok; Details = ($details -join '; '); Manifest = $manifest }
}

function Get-BackupList {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $root = Join-Path $RepoRoot 'backups'
    if (-not (Test-Path -LiteralPath $root)) { return @() }
    return Get-ChildItem -LiteralPath $root -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.json') } |
        Sort-Object Name
}

function Get-LatestBackup {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$RuntimeId
    )
    $backups = Get-BackupList -RepoRoot $RepoRoot | Sort-Object Name -Descending
    foreach ($b in $backups) {
        $m = Import-BackupManifest -BackupDir $b.FullName
        if (-not $RuntimeId) { return $b }
        if (@($m.files) | Where-Object { $_.runtime -eq $RuntimeId }) { return $b }
    }
    return $null
}
