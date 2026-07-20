# setup-sync.Tests.ps1
# Tests for streamlined runtime detection and refresh orchestration.

function Invoke-SetupSyncTests {
    Write-Host ''
    Write-Host 'Setup and sync workflow tests' -ForegroundColor Cyan

    . (Join-Path $global:AgentTestState.RepoRoot 'scripts/lib/Common.ps1')
    . (Join-Path $global:AgentTestState.RepoRoot 'scripts/lib/Configuration.ps1')
    . (Join-Path $global:AgentTestState.RepoRoot 'scripts/lib/RuntimeDetection.ps1')
    . (Join-Path $global:AgentTestState.RepoRoot 'scripts/lib/RefreshWorkflow.ps1')

    Test-Case 'Detection returns Codex, Claude, Gemini in deterministic order' {
        $sandbox = New-SandboxRepo
        $runtimeRoot = New-TempDir
        $map = @{}
        foreach ($id in @('codex','claude','gemini')) {
            $dir = Join-Path $runtimeRoot $id
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $name = switch ($id) { 'codex' { 'AGENTS.md' } 'claude' { 'CLAUDE.md' } 'gemini' { 'GEMINI.md' } }
            $map[$id] = Join-Path $dir $name
        }
        $results = @(Get-DetectedAgentRuntimes -RepoRoot $sandbox -RuntimeIds @('codex','claude','gemini') -InstallPathMap $map)
        Assert-Equal 3 $results.Count
        Assert-Equal 'codex' $results[0].RuntimeId
        Assert-Equal 'claude' $results[1].RuntimeId
        Assert-Equal 'gemini' $results[2].RuntimeId
        Assert-Equal 0 @($results | Where-Object { -not $_.Detected }).Count
    }

    Test-Case 'Existing runtime directory is detected when instruction file is absent' {
        $sandbox = New-SandboxRepo
        $dir = New-TempDir
        $target = Join-Path $dir 'AGENTS.md'
        $results = @(Get-DetectedAgentRuntimes -RepoRoot $sandbox -RuntimeIds @('codex') -InstallPathMap @{ codex=$target })
        Assert-True $results[0].Detected
        Assert-Equal 'Detected' $results[0].Reason
        Assert-True (-not (Test-Path -LiteralPath $target))
    }

    Test-Case 'Missing runtime directory is not created or detected' {
        $sandbox = New-SandboxRepo
        $root = New-TempDir
        $dir = Join-Path $root 'missing-runtime'
        $target = Join-Path $dir 'AGENTS.md'
        $results = @(Get-DetectedAgentRuntimes -RepoRoot $sandbox -RuntimeIds @('codex') -InstallPathMap @{ codex=$target })
        Assert-True (-not $results[0].Detected)
        Assert-Equal 'RuntimeDirectoryMissing' $results[0].Reason
        Assert-True (-not (Test-Path -LiteralPath $dir))
    }

    Test-Case 'Disabled adapter is reported and not detected' {
        $sandbox = New-SandboxRepo
        $adapterPath = Join-Path $sandbox 'adapters/codex.json'
        $adapter = (Get-Content -LiteralPath $adapterPath -Raw | ConvertFrom-Json)
        $adapter.enabled = $false
        $adapter | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $adapterPath -Encoding UTF8
        $dir = New-TempDir
        $results = @(Get-DetectedAgentRuntimes -RepoRoot $sandbox -RuntimeIds @('codex') -InstallPathMap @{ codex=(Join-Path $dir 'AGENTS.md') })
        Assert-True (-not $results[0].Detected)
        Assert-Equal 'AdapterDisabled' $results[0].Reason
    }

    Test-Case 'Refresh installs and verifies only detected runtime targets' {
        $sandbox = New-SandboxRepo
        $codexDir = New-TempDir
        $claudeRoot = New-TempDir
        $claudeDir = Join-Path $claudeRoot 'missing'
        $map = @{ codex=(Join-Path $codexDir 'AGENTS.md'); claude=(Join-Path $claudeDir 'CLAUDE.md') }
        $detection = @(Get-DetectedAgentRuntimes -RepoRoot $sandbox -RuntimeIds @('codex','claude') -InstallPathMap $map)
        $result = Invoke-AgentSystemRefresh -RepoRoot $sandbox -RuntimeRecords $detection -Mode Setup -TargetMap $map
        Assert-True $result.Succeeded
        Assert-Equal 1 $result.Results.Count
        Assert-Equal 'codex' $result.Results[0].RuntimeId
        Assert-True (Test-Path -LiteralPath $map.codex -PathType Leaf)
        Assert-True (-not (Test-Path -LiteralPath $claudeDir))
        $generated = Join-Path $sandbox 'generated/codex/AGENTS.md'
        Assert-Equal (Get-Sha256OfFile -Path $generated) (Get-Sha256OfFile -Path $map.codex)
    }

    Test-Case 'Refresh is idempotent and reports already current' {
        $sandbox = New-SandboxRepo
        $dir = New-TempDir
        $map = @{ codex=(Join-Path $dir 'AGENTS.md') }
        $detection = @(Get-DetectedAgentRuntimes -RepoRoot $sandbox -RuntimeIds @('codex') -InstallPathMap $map)
        $first = Invoke-AgentSystemRefresh -RepoRoot $sandbox -RuntimeRecords $detection -Mode Setup -TargetMap $map
        $second = Invoke-AgentSystemRefresh -RepoRoot $sandbox -RuntimeRecords $detection -Mode Sync -TargetMap $map
        Assert-True $first.Succeeded
        Assert-True $second.Succeeded
        Assert-Equal 'AlreadyCurrent' $second.Results[0].Action
        Assert-Equal 0 $second.RestartRuntimes.Count
    }

    Test-Case 'WhatIf performs no build or install writes' {
        $sandbox = New-SandboxRepo
        $dir = New-TempDir
        $map = @{ gemini=(Join-Path $dir 'GEMINI.md') }
        $detection = @(Get-DetectedAgentRuntimes -RepoRoot $sandbox -RuntimeIds @('gemini') -InstallPathMap $map)
        $result = Invoke-AgentSystemRefresh -RepoRoot $sandbox -RuntimeRecords $detection -Mode Setup -TargetMap $map -WhatIf
        Assert-True $result.Succeeded
        Assert-Equal 'WhatIf' $result.Results[0].Action
        Assert-True (-not (Test-Path -LiteralPath $map.gemini))
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $sandbox 'generated/gemini/GEMINI.md')))
    }

    Test-Case 'No detected runtimes returns exit code 2 with an empty structured result' {
        $result = Invoke-AgentSystemRefresh -RepoRoot $global:AgentTestState.RepoRoot -RuntimeRecords @() -Mode Setup
        Assert-True (-not $result.Succeeded)
        Assert-Equal 2 $result.ExitCode
        Assert-Equal 0 @($result.Results).Count
        Assert-Equal 0 @($result.RestartRuntimes).Count
    }

    Test-Case 'Child-script failure surfaces a formatted message without a parser error' {
        $failing = Join-Path (New-TempDir) 'fail.ps1'
        Set-Content -LiteralPath $failing -Value 'exit 7' -Encoding UTF8
        $threw = $false
        $message = $null
        try {
            Invoke-AgentChildScript -ScriptPath $failing
        }
        catch {
            $threw = $true
            $message = $_.Exception.Message
        }
        Assert-True $threw 'Expected Invoke-AgentChildScript to throw on a non-zero exit code'
        Assert-Contains $message 'exit code 7'
        Assert-Contains $message $failing
    }

    Test-Case 'Test harness state factory returns fresh, independent counters' {
        $first = New-AgentTestState
        $first.Pass = 5
        $first.Fail = 3
        $first.Failures += 'stale failure'
        $first.TempRoots += 'stale-root'
        $second = New-AgentTestState
        Assert-Equal 0 $second.Pass
        Assert-Equal 0 $second.Fail
        Assert-Equal 0 @($second.Failures).Count
        Assert-Equal 0 @($second.TempRoots).Count
    }
}
