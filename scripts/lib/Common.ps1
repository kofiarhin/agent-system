# Common.ps1
# Shared low-level helpers for the Universal Agent System tooling.
# Dot-source this file. PowerShell 7 compatible; also runs under Windows PowerShell 5.1.

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Console output
# ---------------------------------------------------------------------------

function Write-Section {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ""
    Write-Host ("== {0} ==" -f $Text) -ForegroundColor Cyan
}

function Write-Info {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ("   {0}" -f $Text)
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ("   [ OK ] {0}" -f $Text) -ForegroundColor Green
}

function Write-Warn {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ("   [WARN] {0}" -f $Text) -ForegroundColor Yellow
}

function Write-Fail {
    param([Parameter(Mandatory)][string]$Text)
    Write-Host ("   [FAIL] {0}" -f $Text) -ForegroundColor Red
}

function Show-ResultFailures {
    <# Print only the failing check results from a result collection. #>
    param([array]$Results)
    foreach ($r in ($Results | Where-Object { $_.Result -eq 'Fail' })) {
        Write-Fail ("{0} [{1}] {2}" -f $r.Check, $r.Runtime, $r.Details)
    }
}

# ---------------------------------------------------------------------------
# Repository root resolution
# ---------------------------------------------------------------------------

function Resolve-RepoRoot {
    <#
        Walk upward from a starting directory until config/agent.json is found.
        Returns the normalized absolute repository root.
    #>
    param([string]$StartPath = $PSScriptRoot)

    $dir = (Resolve-Path -LiteralPath $StartPath).Path
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $dir 'config/agent.json')) {
            return (ConvertTo-NormalizedPath $dir)
        }
        $parent = [System.IO.Path]::GetDirectoryName($dir)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $dir) {
            throw "Could not locate repository root (config/agent.json) from '$StartPath'."
        }
        $dir = $parent
    }
}

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

function ConvertTo-NormalizedPath {
    <# Return an absolute, canonical path string without a trailing separator. #>
    param([Parameter(Mandatory)][string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -gt 3 -and ($full.EndsWith('\') -or $full.EndsWith('/'))) {
        $full = $full.TrimEnd('\','/')
    }
    return $full
}

function Test-PathWithinRoot {
    <# True when Candidate is equal to or inside Root (case-insensitive, normalized). #>
    param(
        [Parameter(Mandatory)][string]$Candidate,
        [Parameter(Mandatory)][string]$Root
    )
    $c = (ConvertTo-NormalizedPath $Candidate)
    $r = (ConvertTo-NormalizedPath $Root)
    $rWithSep = $r.TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
    if ($c.Equals($r, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $c.StartsWith($rWithSep, [System.StringComparison]::OrdinalIgnoreCase)
}

function Expand-EnvironmentPath {
    <# Expand %VAR% style environment variables in a path string. #>
    param([Parameter(Mandatory)][string]$Path)
    return [System.Environment]::ExpandEnvironmentVariables($Path)
}

# ---------------------------------------------------------------------------
# Text encoding, line endings, hashing
# ---------------------------------------------------------------------------

function Read-TextFileRaw {
    <# Read a text file as a string, auto-detecting BOM, defaulting to UTF-8. #>
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function ConvertTo-LineEnding {
    param(
        [Parameter(Mandatory)][string]$Text,
        [ValidateSet('crlf','lf')][string]$LineEnding = 'crlf'
    )
    # Normalize everything to LF first, then apply the requested ending.
    $lf = $Text -replace "`r`n", "`n" -replace "`r", "`n"
    if ($LineEnding -eq 'crlf') {
        return ($lf -replace "`n", "`r`n")
    }
    return $lf
}

function ConvertTo-AgentBytes {
    <# Normalize line endings and encode content to a byte array for deterministic output. #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [ValidateSet('crlf','lf')][string]$LineEnding = 'crlf',
        [ValidateSet('utf8NoBom','utf8')][string]$Encoding = 'utf8NoBom'
    )
    $normalized = ConvertTo-LineEnding -Text $Content -LineEnding $LineEnding
    $emitBom = ($Encoding -eq 'utf8')
    $enc = [System.Text.UTF8Encoding]::new($emitBom)
    $preamble = $enc.GetPreamble()
    $body = $enc.GetBytes($normalized)
    if ($preamble.Length -gt 0) {
        $all = New-Object byte[] ($preamble.Length + $body.Length)
        [System.Array]::Copy($preamble, 0, $all, 0, $preamble.Length)
        [System.Array]::Copy($body, 0, $all, $preamble.Length, $body.Length)
        return $all
    }
    return $body
}

function Get-Sha256FromBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Bytes)
    } finally {
        $sha.Dispose()
    }
    return (($hash | ForEach-Object { $_.ToString('X2') }) -join '')
}

function Get-Sha256OfFile {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Write-BytesAtomic {
    <#
        Write bytes to Path via a temporary file in the same directory, then
        atomically replace the destination. Cleans up the temp file on failure.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][byte[]]$Bytes
    )
    $dir = [System.IO.Path]::GetDirectoryName($Path)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $tmp = Join-Path $dir ((Split-Path -Leaf $Path) + '.' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllBytes($tmp, $Bytes)
        Move-Item -LiteralPath $tmp -Destination $Path -Force
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

function Get-UtcTimestamp {
    <# UTC timestamp in the format yyyyMMdd-HHmmssZ. #>
    return ((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + 'Z')
}

function Test-ItemIsReparsePoint {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}
