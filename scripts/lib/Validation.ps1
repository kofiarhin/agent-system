# Validation.ps1
# Source, generated, and installed validation, plus behavioral anchor checks.
# Requires Common.ps1, Configuration.ps1, and Compilation.ps1 to be dot-sourced first.

Set-StrictMode -Version Latest

# Prohibited runtime coupling in SHARED modules (adapters and generated files are exempt).
$script:ProhibitedRuntimePatterns = @(
    '\.codex\b',
    '\.claude\b',
    '\.gemini\b',
    '\.cursor\b'
)

# Unresolved template variables of the form {{ ... }}.
$script:UnresolvedVariablePattern = '\{\{[^}]+\}\}'

# Behavioral anchors that must survive into every compiled runtime document.
$script:BehavioralAnchors = @(
    @{ Name = 'Instruction precedence';      Pattern = 'instruction precedence' },
    @{ Name = 'Project-changing request';    Pattern = 'project-changing request' },
    @{ Name = 'Explicit discovery bypass';   Pattern = 'explicit discovery bypass' },
    @{ Name = 'Shared Understanding Handoff';Pattern = 'shared understanding handoff' },
    @{ Name = 'Approval requirement';        Pattern = 'wait for explicit approval' },
    @{ Name = 'Implementation protocol';     Pattern = 'implementation protocol' },
    @{ Name = 'Testing and verification';    Pattern = 'testing and verification' },
    @{ Name = 'Security and safety';         Pattern = 'security and safety' },
    @{ Name = 'Global learnings';            Pattern = 'global learnings' },
    @{ Name = 'Failure and fallback';        Pattern = 'failure and fallback' },
    @{ Name = 'Global invariants';           Pattern = 'global invariants' }
)

function New-CheckResult {
    param(
        [Parameter(Mandatory)][string]$Check,
        [string]$Runtime = 'All',
        [Parameter(Mandatory)][ValidateSet('Pass','Fail','Warn','Skip')][string]$Result,
        [string]$Details = ''
    )
    return [pscustomobject]@{ Check = $Check; Runtime = $Runtime; Result = $Result; Details = $Details }
}

function Get-ProhibitedPathMatches {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $found = @()
    foreach ($pat in $script:ProhibitedRuntimePatterns) {
        if ([System.Text.RegularExpressions.Regex]::IsMatch($Text, $pat, 'IgnoreCase')) {
            $found += $pat
        }
    }
    return $found
}

function Get-UnresolvedVariables {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $m = [System.Text.RegularExpressions.Regex]::Matches($Text, $script:UnresolvedVariablePattern)
    return @($m | ForEach-Object { $_.Value } | Select-Object -Unique)
}

# ---------------------------------------------------------------------------
# Manifest validation
# ---------------------------------------------------------------------------

function Test-AgentConfig {
    param(
        [Parameter(Mandatory)]$AgentConfig,
        [Parameter(Mandatory)][string]$RepoRoot
    )
    $results = @()

    foreach ($field in @('agent','compilation','modules','runtimes')) {
        if (-not ($AgentConfig.PSObject.Properties.Name -contains $field)) {
            $results += New-CheckResult -Check "Manifest field '$field'" -Result Fail -Details 'Missing required field'
        }
    }
    if (($results | Where-Object { $_.Result -eq 'Fail' })) { return $results }

    # Compilation values.
    if ($AgentConfig.compilation.lineEnding -notin @('crlf','lf')) {
        $results += New-CheckResult -Check 'Compilation lineEnding' -Result Fail -Details "Invalid: $($AgentConfig.compilation.lineEnding)"
    }
    if ($AgentConfig.compilation.encoding -notin @('utf8NoBom','utf8')) {
        $results += New-CheckResult -Check 'Compilation encoding' -Result Fail -Details "Invalid: $($AgentConfig.compilation.encoding)"
    }

    # Modules: non-empty, unique, exist, relative, inside repo.
    $mods = @($AgentConfig.modules)
    if ($mods.Count -eq 0) {
        $results += New-CheckResult -Check 'Modules' -Result Fail -Details 'No modules configured'
    }
    $dupes = $mods | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
    if ($dupes) {
        $results += New-CheckResult -Check 'Module uniqueness' -Result Fail -Details "Duplicate modules: $($dupes -join ', ')"
    }
    foreach ($rel in $mods) {
        $abs = ConvertTo-NormalizedPath (Join-Path $RepoRoot ($rel -replace '/','\'))
        if (-not (Test-PathWithinRoot -Candidate $abs -Root $RepoRoot)) {
            $results += New-CheckResult -Check "Module path '$rel'" -Result Fail -Details 'Module path escapes repository root'
        } elseif (-not (Test-Path -LiteralPath $abs)) {
            $results += New-CheckResult -Check "Module path '$rel'" -Result Fail -Details 'Module file not found'
        }
    }

    # Runtimes: non-empty, unique.
    $rts = @($AgentConfig.runtimes)
    if ($rts.Count -eq 0) {
        $results += New-CheckResult -Check 'Runtimes' -Result Fail -Details 'No runtimes registered'
    }
    $rdupes = $rts | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
    if ($rdupes) {
        $results += New-CheckResult -Check 'Runtime uniqueness' -Result Fail -Details "Duplicate runtime ids: $($rdupes -join ', ')"
    }

    if (-not ($results | Where-Object { $_.Result -eq 'Fail' })) {
        $results += New-CheckResult -Check 'Manifest validation' -Result Pass -Details "$($mods.Count) modules, $($rts.Count) runtimes"
    }
    return $results
}

function Test-AdapterConfig {
    param(
        [Parameter(Mandatory)]$AgentConfig,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$RuntimeIds
    )
    $results = @()
    $seenOutputs = @{}
    foreach ($id in $RuntimeIds) {
        try {
            $adapter = Import-AdapterConfig -RepoRoot $RepoRoot -RuntimeId $id
        } catch {
            $results += New-CheckResult -Check "Adapter '$id'" -Runtime $id -Result Fail -Details $_.Exception.Message
            continue
        }

        $missing = @()
        foreach ($f in @('id','displayName','enabled','output','document','compatibility','installation')) {
            if (-not ($adapter.PSObject.Properties.Name -contains $f)) { $missing += $f }
        }
        if ($missing) {
            $results += New-CheckResult -Check "Adapter '$id' fields" -Runtime $id -Result Fail -Details "Missing: $($missing -join ', ')"
            continue
        }
        if ($adapter.id -ne $id) {
            $results += New-CheckResult -Check "Adapter '$id' id" -Runtime $id -Result Fail -Details "Adapter id '$($adapter.id)' does not match filename"
        }
        if ($adapter.compatibility.mode -ne 'full') {
            $results += New-CheckResult -Check "Adapter '$id' compatibility" -Runtime $id -Result Fail -Details "Unsupported mode: $($adapter.compatibility.mode)"
        }

        # Output path uniqueness and containment.
        $outAbs = ConvertTo-NormalizedPath (Resolve-AdapterOutputPath -RepoRoot $RepoRoot -Adapter $adapter)
        $genRoot = Join-Path $RepoRoot 'generated'
        if (-not (Test-PathWithinRoot -Candidate $outAbs -Root $genRoot)) {
            $results += New-CheckResult -Check "Adapter '$id' output" -Runtime $id -Result Fail -Details 'Output path escapes generated/'
        }
        $key = $outAbs.ToLowerInvariant()
        if ($seenOutputs.ContainsKey($key)) {
            $results += New-CheckResult -Check "Adapter '$id' output" -Runtime $id -Result Fail -Details "Duplicate output path shared with '$($seenOutputs[$key])'"
        } else {
            $seenOutputs[$key] = $id
        }

        if (-not ($results | Where-Object { $_.Runtime -eq $id -and $_.Result -eq 'Fail' })) {
            $results += New-CheckResult -Check "Adapter validation" -Runtime $id -Result Pass -Details "$($adapter.displayName)"
        }
    }
    return $results
}

# ---------------------------------------------------------------------------
# Source module validation
# ---------------------------------------------------------------------------

function Test-SourceModules {
    param(
        [Parameter(Mandatory)]$AgentConfig,
        [Parameter(Mandatory)][string]$RepoRoot
    )
    $results = @()
    $modules = Get-ModulePathList -AgentConfig $AgentConfig -RepoRoot $RepoRoot
    foreach ($m in $modules) {
        if (-not (Test-Path -LiteralPath $m.Absolute)) {
            $results += New-CheckResult -Check "Source '$($m.Relative)'" -Result Fail -Details 'File not found'
            continue
        }
        $content = Get-ModuleContent -Path $m.Absolute
        if ([string]::IsNullOrWhiteSpace($content)) {
            $results += New-CheckResult -Check "Source '$($m.Relative)'" -Result Fail -Details 'Module is empty'
            continue
        }
        # The module must begin with its single top-level title heading.
        # (Additional '#' lines are allowed: modules legitimately embed output
        #  templates and fenced examples that use level-1 headings.)
        $firstLine = ($content -split "`n", 2)[0]
        if ($firstLine -notmatch '^#\s+\S') {
            $results += New-CheckResult -Check "Source '$($m.Relative)'" -Result Fail -Details 'Module must start with a top-level title heading'
            continue
        }
        # Prohibited runtime coupling.
        $bad = @(Get-ProhibitedPathMatches -Text $content)
        if ($bad.Count -gt 0) {
            $results += New-CheckResult -Check "Source '$($m.Relative)'" -Result Fail -Details "Prohibited runtime path pattern(s): $($bad -join ', ')"
            continue
        }
        # Unresolved variables.
        $vars = @(Get-UnresolvedVariables -Text $content)
        if ($vars.Count -gt 0) {
            $results += New-CheckResult -Check "Source '$($m.Relative)'" -Result Fail -Details "Unresolved variables: $($vars -join ', ')"
            continue
        }
        $results += New-CheckResult -Check "Source '$($m.Relative)'" -Result Pass -Details 'Valid'
    }
    return $results
}

# ---------------------------------------------------------------------------
# Generated output validation
# ---------------------------------------------------------------------------

function Test-GeneratedOutput {
    param(
        [Parameter(Mandatory)]$AgentConfig,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RuntimeId,
        [switch]$Strict
    )
    $results = @()
    $adapter = Import-AdapterConfig -RepoRoot $RepoRoot -RuntimeId $RuntimeId
    $outPath = Resolve-AdapterOutputPath -RepoRoot $RepoRoot -Adapter $adapter

    if (-not (Test-Path -LiteralPath $outPath)) {
        $results += New-CheckResult -Check 'Generated file exists' -Runtime $RuntimeId -Result Fail -Details "Missing: $outPath"
        return $results
    }

    $onDisk = Read-TextFileRaw -Path $outPath
    if ([string]::IsNullOrWhiteSpace($onDisk)) {
        $results += New-CheckResult -Check 'Generated non-empty' -Runtime $RuntimeId -Result Fail -Details 'Empty file'
        return $results
    }

    # Generated warning.
    if ($AgentConfig.compilation.includeGeneratedWarning -and ($onDisk -notmatch 'Generated from the Universal Agent System')) {
        $results += New-CheckResult -Check 'Generated warning' -Runtime $RuntimeId -Result Fail -Details 'Warning missing'
    }

    # Runtime title.
    $expectedTitle = "# " + $adapter.document.title
    if ($onDisk -notmatch [regex]::Escape($expectedTitle)) {
        $results += New-CheckResult -Check 'Runtime title' -Runtime $RuntimeId -Result Fail -Details "Expected '$expectedTitle'"
    }

    # Runtime header first line.
    $firstHeaderLine = @($adapter.document.runtimeHeader)[0]
    if ($firstHeaderLine -and ($onDisk -notmatch [regex]::Escape($firstHeaderLine))) {
        $results += New-CheckResult -Check 'Runtime header' -Runtime $RuntimeId -Result Fail -Details 'Runtime header missing'
    }

    # Source markers present, exactly once each, in configured order.
    if ($AgentConfig.compilation.includeSourceMarkers) {
        $lastIndex = -1
        $orderOk = $true
        foreach ($rel in $AgentConfig.modules) {
            $marker = Format-SourceMarker -RelativePath $rel
            $count = ([regex]::Matches($onDisk, [regex]::Escape($marker))).Count
            if ($count -ne 1) {
                $results += New-CheckResult -Check 'Module presence' -Runtime $RuntimeId -Result Fail -Details "Marker for '$rel' appears $count time(s)"
                $orderOk = $false
                continue
            }
            $idx = $onDisk.IndexOf($marker)
            if ($idx -lt $lastIndex) {
                $results += New-CheckResult -Check 'Module order' -Runtime $RuntimeId -Result Fail -Details "'$rel' out of configured order"
                $orderOk = $false
            }
            $lastIndex = $idx
        }
        if ($orderOk) {
            $results += New-CheckResult -Check 'Module order' -Runtime $RuntimeId -Result Pass -Details "$(@($AgentConfig.modules).Count) markers in order"
        }
    }

    # Unresolved variables.
    $vars = @(Get-UnresolvedVariables -Text $onDisk)
    if ($vars.Count -gt 0) {
        $results += New-CheckResult -Check 'Unresolved variables' -Runtime $RuntimeId -Result Fail -Details ($vars -join ', ')
    }

    # Behavioral anchors.
    $missingAnchors = @()
    foreach ($a in $script:BehavioralAnchors) {
        if (-not [System.Text.RegularExpressions.Regex]::IsMatch($onDisk, [regex]::Escape($a.Pattern), 'IgnoreCase')) {
            $missingAnchors += $a.Name
        }
    }
    if ($missingAnchors.Count -gt 0) {
        $results += New-CheckResult -Check 'Behavioral anchors' -Runtime $RuntimeId -Result Fail -Details "Missing: $($missingAnchors -join ', ')"
    } else {
        $results += New-CheckResult -Check 'Behavioral anchors' -Runtime $RuntimeId -Result Pass -Details "$($script:BehavioralAnchors.Count) anchors present"
    }

    # Clean rebuild comparison (freshness).
    $doc = Build-RuntimeDocument -AgentConfig $AgentConfig -Adapter $adapter -RepoRoot $RepoRoot
    $bytes = ConvertTo-AgentBytes -Content $doc -LineEnding $AgentConfig.compilation.lineEnding -Encoding $AgentConfig.compilation.encoding
    $rebuildHash = Get-Sha256FromBytes -Bytes $bytes
    $diskHash = Get-Sha256OfFile -Path $outPath
    if ($rebuildHash -ne $diskHash) {
        $results += New-CheckResult -Check 'Clean rebuild' -Runtime $RuntimeId -Result Fail -Details 'Generated file is stale; rebuild required'
    } else {
        $results += New-CheckResult -Check 'Clean rebuild' -Runtime $RuntimeId -Result Pass -Details 'Hash matches'
    }

    return $results
}

# ---------------------------------------------------------------------------
# Installed output validation
# ---------------------------------------------------------------------------

function Test-InstalledOutput {
    param(
        [Parameter(Mandatory)]$AgentConfig,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RuntimeId
    )
    $results = @()
    $adapter = Import-AdapterConfig -RepoRoot $RepoRoot -RuntimeId $RuntimeId
    if (-not $adapter.installation.supported) {
        $results += New-CheckResult -Check 'Installed artifact' -Runtime $RuntimeId -Result Skip -Details 'Runtime does not support installation'
        return $results
    }
    $installPath = Resolve-AdapterInstallPath -Adapter $adapter
    if (-not $installPath -or -not (Test-Path -LiteralPath $installPath)) {
        $results += New-CheckResult -Check 'Installed artifact' -Runtime $RuntimeId -Result Skip -Details 'Not installed'
        return $results
    }
    # Containment: installed file must be within an approved root.
    $roots = Get-AdapterApprovedRoots -Adapter $adapter
    $within = $false
    foreach ($r in $roots) { if (Test-PathWithinRoot -Candidate $installPath -Root $r) { $within = $true; break } }
    if (-not $within) {
        $results += New-CheckResult -Check 'Installed location' -Runtime $RuntimeId -Result Fail -Details 'Installed path outside approved runtime root'
    }
    $outPath = Resolve-AdapterOutputPath -RepoRoot $RepoRoot -Adapter $adapter
    if (-not (Test-Path -LiteralPath $outPath)) {
        $results += New-CheckResult -Check 'Installed artifact' -Runtime $RuntimeId -Result Fail -Details 'Generated artifact missing for comparison'
        return $results
    }
    $genHash = Get-Sha256OfFile -Path $outPath
    $insHash = Get-Sha256OfFile -Path $installPath
    if ($genHash -eq $insHash) {
        $results += New-CheckResult -Check 'Installed artifact' -Runtime $RuntimeId -Result Pass -Details 'Installed hash matches generated'
    } else {
        $results += New-CheckResult -Check 'Installed artifact' -Runtime $RuntimeId -Result Fail -Details 'Installed hash differs from generated'
    }
    return $results
}
