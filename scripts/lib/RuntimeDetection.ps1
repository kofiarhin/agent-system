# RuntimeDetection.ps1
# Read-only detection of supported local agent runtimes.
# Requires Common.ps1 and Configuration.ps1.

Set-StrictMode -Version Latest

function Get-DetectedAgentRuntimes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string[]]$RuntimeIds = @('codex', 'claude', 'gemini'),
        [hashtable]$InstallPathMap = @{}
    )

    $results = @()

    foreach ($id in $RuntimeIds) {
        $adapterPath = Join-Path $RepoRoot ("adapters/{0}.json" -f $id)
        $record = [ordered]@{
            RuntimeId          = $id
            DisplayName        = $id
            AdapterPath        = $adapterPath
            GeneratedPath      = $null
            InstallPath        = $null
            DetectionDirectory = $null
            Detected           = $false
            Reason             = 'InvalidInstallPath'
        }

        try {
            $adapter = Import-AdapterConfig -RepoRoot $RepoRoot -RuntimeId $id
            $record.DisplayName = [string]$adapter.displayName
            $record.GeneratedPath = Resolve-AdapterOutputPath -RepoRoot $RepoRoot -Adapter $adapter

            if (-not $adapter.enabled) {
                $record.Reason = 'AdapterDisabled'
                $results += [pscustomobject]$record
                continue
            }

            if (-not $adapter.installation.supported) {
                $record.Reason = 'InstallationUnsupported'
                $results += [pscustomobject]$record
                continue
            }

            if ($InstallPathMap.ContainsKey($id)) {
                $installPath = ConvertTo-NormalizedPath ([string]$InstallPathMap[$id])
                $approvedRoots = @((Split-Path -Parent $installPath))
            } else {
                $installPath = Resolve-AdapterInstallPath -Adapter $adapter
                $approvedRoots = @(Get-AdapterApprovedRoots -Adapter $adapter)
            }

            if ([string]::IsNullOrWhiteSpace($installPath) -or $approvedRoots.Count -eq 0) {
                $results += [pscustomobject]$record
                continue
            }

            $installPath = ConvertTo-NormalizedPath $installPath
            $withinApprovedRoot = $false
            foreach ($root in $approvedRoots) {
                if (-not [string]::IsNullOrWhiteSpace([string]$root) -and (Test-PathWithinRoot -Candidate $installPath -Root $root)) {
                    $withinApprovedRoot = $true
                    break
                }
            }

            if (-not $withinApprovedRoot) {
                $results += [pscustomobject]$record
                continue
            }

            $runtimeDirectory = Split-Path -Parent $installPath
            $record.InstallPath = $installPath
            $record.DetectionDirectory = $runtimeDirectory

            if (Test-Path -LiteralPath $runtimeDirectory -PathType Container) {
                $record.Detected = $true
                $record.Reason = 'Detected'
            } else {
                $record.Reason = 'RuntimeDirectoryMissing'
            }
        }
        catch {
            $record.Reason = 'InvalidInstallPath'
        }

        $results += [pscustomobject]$record
    }

    return $results
}

function Show-AgentRuntimeDetection {
    [CmdletBinding()]
    param([Parameter(Mandatory)][array]$Results)

    Write-Section 'Detect supported runtimes'
    $Results |
        Select-Object @{Name='Runtime';Expression={$_.DisplayName}},
                      @{Name='Directory';Expression={$_.DetectionDirectory}},
                      @{Name='Status';Expression={if ($_.Detected) { 'Detected' } else { $_.Reason }}} |
        Format-Table -AutoSize |
        Out-String |
        Write-Host
}
