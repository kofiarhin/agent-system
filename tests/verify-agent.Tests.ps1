# verify-agent.Tests.ps1
# Verification tests. Runnable standalone or via tests/run-tests.ps1.

. (Join-Path $PSScriptRoot '_harness.ps1')

function Invoke-VerifyAgentTests {
    Write-Host "== verify-agent tests ==" -ForegroundColor Cyan

    Test-Case 'valid source and generated pass verification' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All') | Out-Null
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/verify-agent.ps1' -Arguments @()
        Assert-Equal 0 $r.ExitCode 'verification should pass'
        Assert-Contains $r.Output 'Verification passed'
    }

    Test-Case 'behavioral anchors are present in generated output' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All') | Out-Null
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/verify-agent.ps1' -Arguments @('-Scope','Generated')
        Assert-Contains $r.Output 'Behavioral anchors'
        Assert-Equal 0 $r.ExitCode
    }

    Test-Case 'stale generated file fails verification' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All') | Out-Null
        Add-Content -LiteralPath (Join-Path $repo 'generated/claude/CLAUDE.md') -Value 'stale-marker'
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/verify-agent.ps1' -Arguments @('-Scope','Generated')
        Assert-Equal 1 $r.ExitCode 'stale output should fail'
        Assert-Contains $r.Output 'stale'
    }

    Test-Case 'missing behavioral anchor fails verification' {
        $repo = New-SandboxRepo
        # Remove the global-invariants module content that carries an anchor, then rebuild bypassing source checks is not possible;
        # instead tamper the generated file to drop an anchor and desync from source.
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $p = Join-Path $repo 'generated/codex/AGENTS.md'
        $doc = Get-Content -Raw -LiteralPath $p
        $doc = $doc -replace 'Global Invariants','Removed Section'
        Set-Content -LiteralPath $p -Value $doc -NoNewline
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/verify-agent.ps1' -Arguments @('-Scope','Generated','-Runtime','codex')
        Assert-Equal 1 $r.ExitCode 'missing anchor should fail'
    }

    Test-Case 'missing generated file fails verification' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All') | Out-Null
        Remove-Item -LiteralPath (Join-Path $repo 'generated/gemini/GEMINI.md') -Force
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/verify-agent.ps1' -Arguments @('-Scope','Generated','-Runtime','gemini')
        Assert-Equal 1 $r.ExitCode 'missing generated file should fail'
    }

    Test-Case 'installed scope passes when installed file matches generated (temp target)' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $tmp = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        $ap = Join-Path $repo 'adapters/codex.json'
        $a = Get-Content -Raw -LiteralPath $ap | ConvertFrom-Json
        $a.installation.path = $target
        $a.installation.approvedRoots = @($tmp)
        $a | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ap
        Copy-Item -LiteralPath (Join-Path $repo 'generated/codex/AGENTS.md') -Destination $target -Force
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/verify-agent.ps1' -Arguments @('-Scope','Installed','-Runtime','codex')
        Assert-Equal 0 $r.ExitCode 'matching installed file should pass'
        Assert-Contains $r.Output 'Verification passed'
    }

    Test-Case 'installed scope fails on hash mismatch (temp target)' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $tmp = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        $ap = Join-Path $repo 'adapters/codex.json'
        $a = Get-Content -Raw -LiteralPath $ap | ConvertFrom-Json
        $a.installation.path = $target
        $a.installation.approvedRoots = @($tmp)
        $a | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ap
        Copy-Item -LiteralPath (Join-Path $repo 'generated/codex/AGENTS.md') -Destination $target -Force
        Add-Content -LiteralPath $target -Value 'drift'
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/verify-agent.ps1' -Arguments @('-Scope','Installed','-Runtime','codex')
        Assert-Equal 1 $r.ExitCode 'installed hash mismatch should fail'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-TestHarness -RepoRoot (Split-Path $PSScriptRoot -Parent)
    Invoke-VerifyAgentTests
    exit (Complete-Tests)
}
