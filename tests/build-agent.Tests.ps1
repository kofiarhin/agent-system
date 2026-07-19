# build-agent.Tests.ps1
# Build compiler tests. Runnable standalone or via tests/run-tests.ps1.

. (Join-Path $PSScriptRoot '_harness.ps1')

function Invoke-BuildAgentTests {
    Write-Host "== build-agent tests ==" -ForegroundColor Cyan

    Test-Case 'all-runtime build produces four artifacts' {
        $repo = New-SandboxRepo
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All')
        Assert-Equal 0 $r.ExitCode 'build should succeed'
        foreach ($f in @('generated/codex/AGENTS.md','generated/claude/CLAUDE.md','generated/gemini/GEMINI.md','generated/generic/SYSTEM_PROMPT.md')) {
            Assert-True (Test-Path -LiteralPath (Join-Path $repo $f)) "missing $f"
        }
    }

    Test-Case 'deterministic build: identical hashes across rebuilds' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All') | Out-Null
        $h1 = Get-ChildItem (Join-Path $repo 'generated') -Recurse -Filter *.md | Get-FileHash -Algorithm SHA256 | Sort-Object Path | ForEach-Object { $_.Hash }
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All') | Out-Null
        $h2 = Get-ChildItem (Join-Path $repo 'generated') -Recurse -Filter *.md | Get-FileHash -Algorithm SHA256 | Sort-Object Path | ForEach-Object { $_.Hash }
        Assert-Equal ($h1 -join ',') ($h2 -join ',') 'hashes changed across rebuild'
    }

    Test-Case 'single-runtime build only writes that runtime' {
        $repo = New-SandboxRepo
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex')
        Assert-Equal 0 $r.ExitCode
        Assert-True (Test-Path -LiteralPath (Join-Path $repo 'generated/codex/AGENTS.md')) 'codex missing'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $repo 'generated/claude/CLAUDE.md'))) 'claude should not be built'
    }

    Test-Case 'module ordering preserved in generated output' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $doc = Get-Content -Raw -LiteralPath (Join-Path $repo 'generated/codex/AGENTS.md')
        $iPurpose = $doc.IndexOf('<!-- source: core/purpose-and-scope.md -->')
        $iInvariants = $doc.IndexOf('<!-- source: core/global-invariants.md -->')
        Assert-True ($iPurpose -ge 0 -and $iInvariants -gt $iPurpose) 'purpose must precede invariants'
    }

    Test-Case 'no-change build does not rewrite unchanged files' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $p = Join-Path $repo 'generated/codex/AGENTS.md'
        $t1 = (Get-Item -LiteralPath $p).LastWriteTimeUtc
        Start-Sleep -Milliseconds 50
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex')
        Assert-Contains $r.Output 'unchanged'
        $t2 = (Get-Item -LiteralPath $p).LastWriteTimeUtc
        Assert-Equal $t1.Ticks $t2.Ticks 'unchanged file should not be rewritten'
    }

    Test-Case '-Check detects stale generated output' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All') | Out-Null
        # Corrupt one generated file.
        Add-Content -LiteralPath (Join-Path $repo 'generated/codex/AGENTS.md') -Value 'tampered'
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All','-Check')
        Assert-Equal 2 $r.ExitCode '-Check should exit 2 on stale output'
        Assert-Contains $r.Output 'stale'
    }

    Test-Case 'malformed configuration fails the build' {
        $repo = New-SandboxRepo
        Set-Content -LiteralPath (Join-Path $repo 'config/agent.json') -Value '{ not valid json ' -NoNewline
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All')
        Assert-Equal 1 $r.ExitCode 'malformed config should fail'
    }

    Test-Case 'missing module fails the build' {
        $repo = New-SandboxRepo
        $cfgPath = Join-Path $repo 'config/agent.json'
        $cfg = Get-Content -Raw -LiteralPath $cfgPath | ConvertFrom-Json
        $cfg.modules += 'core/does-not-exist.md'
        $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cfgPath
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All')
        Assert-Equal 1 $r.ExitCode 'missing module should fail'
    }

    Test-Case 'duplicate runtime ids fail validation' {
        $repo = New-SandboxRepo
        $cfgPath = Join-Path $repo 'config/agent.json'
        $cfg = Get-Content -Raw -LiteralPath $cfgPath | ConvertFrom-Json
        $cfg.runtimes = @('codex','codex','claude')
        $cfg | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cfgPath
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','All')
        Assert-Equal 1 $r.ExitCode 'duplicate runtime ids should fail'
    }

    Test-Case 'path traversal in adapter output is rejected' {
        $repo = New-SandboxRepo
        $ap = Join-Path $repo 'adapters/codex.json'
        $a = Get-Content -Raw -LiteralPath $ap | ConvertFrom-Json
        $a.output.directory = 'generated/../evil'
        $a | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ap
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex')
        Assert-Equal 1 $r.ExitCode 'output path escaping generated/ should fail'
    }

    Test-Case 'unresolved template variable in a module fails source validation' {
        $repo = New-SandboxRepo
        Add-Content -LiteralPath (Join-Path $repo 'core/global-invariants.md') -Value "`nInjected {{UNRESOLVED}} token."
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex')
        Assert-Equal 1 $r.ExitCode 'unresolved variable should fail'
    }

    Test-Case 'prohibited runtime path in a module fails source validation' {
        $repo = New-SandboxRepo
        Add-Content -LiteralPath (Join-Path $repo 'core/purpose-and-scope.md') -Value "`nSee ~/.codex/AGENTS.md for details."
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex')
        Assert-Equal 1 $r.ExitCode 'prohibited .codex path should fail'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-TestHarness -RepoRoot (Split-Path $PSScriptRoot -Parent)
    Invoke-BuildAgentTests
    exit (Complete-Tests)
}
