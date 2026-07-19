# _harness.ps1
# Minimal, Pester-independent test harness for the Universal Agent System.
# Provides Test/assert helpers and sandbox-repo construction. Dot-source it.

Set-StrictMode -Version Latest

if (-not (Get-Variable -Name AgentTestState -Scope Global -ErrorAction SilentlyContinue)) {
    $global:AgentTestState = [pscustomobject]@{ Pass = 0; Fail = 0; Failures = @(); RepoRoot = $null; TempRoots = @() }
}

function Initialize-TestHarness {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $global:AgentTestState.RepoRoot = $RepoRoot
}

function Test-Case {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Body
    )
    try {
        & $Body
        $global:AgentTestState.Pass++
        Write-Host ("  [PASS] {0}" -f $Name) -ForegroundColor Green
    }
    catch {
        $global:AgentTestState.Fail++
        $global:AgentTestState.Failures += ("{0} :: {1}" -f $Name, $_.Exception.Message)
        Write-Host ("  [FAIL] {0}" -f $Name) -ForegroundColor Red
        Write-Host ("         {0}" -f $_.Exception.Message) -ForegroundColor DarkRed
    }
}

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [string]$Message = 'Expected condition to be true')
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message = '')
    if ($Expected -ne $Actual) {
        throw ("Expected '{0}' but got '{1}'. {2}" -f $Expected, $Actual, $Message)
    }
}

function Assert-Contains {
    param([string]$Haystack, [string]$Needle, [string]$Message = '')
    if ($Haystack -notmatch [regex]::Escape($Needle)) {
        throw ("Expected text to contain '{0}'. {1}" -f $Needle, $Message)
    }
}

function New-TempDir {
    $p = Join-Path $env:TEMP ("agenttest_" + [Guid]::NewGuid().ToString('N').Substring(0,10))
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    $global:AgentTestState.TempRoots += $p
    return $p
}

function New-SandboxRepo {
    <#
        Build an isolated copy of the repository containing only the pieces the
        tooling needs (source modules, config, adapters, scripts). Negative-case
        tests mutate the sandbox, never the real repository.
    #>
    $repo = $global:AgentTestState.RepoRoot
    $dest = New-TempDir
    foreach ($d in @('core','workflows','capabilities','memory','config','adapters','scripts')) {
        Copy-Item -LiteralPath (Join-Path $repo $d) -Destination (Join-Path $dest $d) -Recurse -Force
    }
    New-Item -ItemType Directory -Path (Join-Path $dest 'generated') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dest 'backups') -Force | Out-Null
    return $dest
}

function Invoke-Script {
    <#
        Run a repo script by path and return @{ ExitCode; Output }.
        Use -Arguments for positional/switch tokens, or -Params to splat named
        parameters (required for passing hashtables and $false switch values).
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ScriptRelPath,
        [object[]]$Arguments = @(),
        [hashtable]$Params
    )
    $script = Join-Path $RepoRoot $ScriptRelPath
    if (-not $PSBoundParameters.ContainsKey('Params')) {
        # Parse a flat token array (-Name value / -Switch) into a named-parameter splat.
        $Params = @{}
        for ($i = 0; $i -lt $Arguments.Count; $i++) {
            $tok = [string]$Arguments[$i]
            if ($tok -match '^-(.+)$') {
                $name = $Matches[1]
                if (($i + 1) -lt $Arguments.Count -and ([string]$Arguments[$i + 1]) -notmatch '^-') {
                    $Params[$name] = $Arguments[$i + 1]
                    $i++
                } else {
                    $Params[$name] = $true
                }
            }
        }
    }
    $output = & $script @Params *>&1 | Out-String
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Complete-Tests {
    $s = $global:AgentTestState
    Write-Host ""
    Write-Host ("Totals: PASS={0} FAIL={1}" -f $s.Pass, $s.Fail) -ForegroundColor Cyan
    if ($s.Fail -gt 0) {
        Write-Host "Failures:" -ForegroundColor Red
        $s.Failures | ForEach-Object { Write-Host ("  - {0}" -f $_) -ForegroundColor Red }
    }
    # Cleanup temp roots.
    foreach ($t in $s.TempRoots) {
        if ($t -and (Test-Path -LiteralPath $t) -and $t.StartsWith($env:TEMP, [System.StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    return $s.Fail
}
