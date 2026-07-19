# Configuration.ps1
# Load and resolve agent manifest and runtime adapter configuration.
# Requires Common.ps1 to be dot-sourced first.

Set-StrictMode -Version Latest

function Import-AgentConfig {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $path = Join-Path $RepoRoot 'config/agent.json'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Agent manifest not found: $path"
    }
    try {
        $raw = Read-TextFileRaw -Path $path
        $cfg = $raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse config/agent.json: $($_.Exception.Message)"
    }
    return $cfg
}

function Import-AdapterConfig {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RuntimeId
    )
    $path = Join-Path $RepoRoot ("adapters/{0}.json" -f $RuntimeId)
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Adapter not found for runtime '$RuntimeId': $path"
    }
    try {
        $raw = Read-TextFileRaw -Path $path
        $adapter = $raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse adapter '$RuntimeId': $($_.Exception.Message)"
    }
    return $adapter
}

function Resolve-RuntimeSelection {
    <#
        Given -Runtime (a single id or 'All'), return the list of enabled runtime
        ids declared in the manifest. Validates that a named runtime exists.
    #>
    param(
        [Parameter(Mandatory)]$AgentConfig,
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$Runtime = 'All'
    )
    $declared = @($AgentConfig.runtimes)
    if ($Runtime -and $Runtime -ne 'All') {
        $match = $declared | Where-Object { $_ -eq $Runtime }
        if (-not $match) {
            throw "Runtime '$Runtime' is not registered in config/agent.json. Registered: $($declared -join ', ')"
        }
        return @($Runtime)
    }
    # All: only enabled adapters.
    $result = @()
    foreach ($id in $declared) {
        $adapter = Import-AdapterConfig -RepoRoot $RepoRoot -RuntimeId $id
        if ($adapter.enabled) { $result += $id }
    }
    return $result
}

function Get-ModulePathList {
    <# Return absolute paths of configured modules, in order. #>
    param(
        [Parameter(Mandatory)]$AgentConfig,
        [Parameter(Mandatory)][string]$RepoRoot
    )
    $list = @()
    foreach ($rel in $AgentConfig.modules) {
        $list += [pscustomobject]@{
            Relative = $rel
            Absolute = (Join-Path $RepoRoot ($rel -replace '/','\'))
        }
    }
    return $list
}

function Resolve-AdapterOutputPath {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)]$Adapter
    )
    return (Join-Path $RepoRoot ((Join-Path $Adapter.output.directory $Adapter.output.filename) -replace '/','\'))
}

function Resolve-AdapterInstallPath {
    <# Expand environment variables in the adapter install path. Returns $null when unsupported. #>
    param([Parameter(Mandatory)]$Adapter)
    if (-not $Adapter.installation.supported) { return $null }
    if (-not ($Adapter.installation.PSObject.Properties.Name -contains 'path')) { return $null }
    if ([string]::IsNullOrWhiteSpace($Adapter.installation.path)) { return $null }
    return (Expand-EnvironmentPath $Adapter.installation.path)
}

function Get-AdapterApprovedRoots {
    param([Parameter(Mandatory)]$Adapter)
    $roots = @()
    $inst = $Adapter.installation
    if ($inst.PSObject.Properties.Name -contains 'approvedRoots' -and $inst.approvedRoots) {
        foreach ($r in $inst.approvedRoots) { $roots += (Expand-EnvironmentPath $r) }
    }
    return $roots
}
