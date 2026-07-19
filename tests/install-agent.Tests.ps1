# install-agent.Tests.ps1
# Installer tests. All installation targets are temporary directories via -TargetMap.
# These tests never touch real .codex / .claude / .gemini paths.

. (Join-Path $PSScriptRoot '_harness.ps1')

function Invoke-InstallAgentTests {
    Write-Host "== install-agent tests ==" -ForegroundColor Cyan

    Test-Case 'fresh install writes verified artifact to temp target' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $tmp = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/install-agent.ps1' -Params @{ Runtime='codex'; TargetMap=@{ codex=$target }; Confirm=$false }
        Assert-Equal 0 $r.ExitCode 'fresh install should succeed'
        Assert-True (Test-Path -LiteralPath $target) 'target not created'
        $gen = (Get-FileHash -LiteralPath (Join-Path $repo 'generated/codex/AGENTS.md') -Algorithm SHA256).Hash
        $ins = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        Assert-Equal $gen $ins 'installed hash must match generated'
    }

    Test-Case 'replacing an existing target creates a verified backup' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $tmp = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        Set-Content -LiteralPath $target -Value 'PRIOR' -NoNewline
        $priorHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/install-agent.ps1' -Params @{ Runtime='codex'; TargetMap=@{ codex=$target }; Confirm=$false }
        Assert-Equal 0 $r.ExitCode
        $backupDir = Get-ChildItem (Join-Path $repo 'backups') -Directory | Sort-Object Name -Descending | Select-Object -First 1
        Assert-True ($null -ne $backupDir) 'no backup created'
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $backupDir.FullName 'manifest.json') | ConvertFrom-Json
        $entry = @($manifest.files) | Where-Object { $_.runtime -eq 'codex' } | Select-Object -First 1
        Assert-Equal $priorHash $entry.sha256 'backup hash must match prior content'
        Assert-True (Test-Path -LiteralPath $entry.backupPath) 'backup file missing'
    }

    Test-Case '-WhatIf performs no write' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $tmp = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/install-agent.ps1' -Params @{ Runtime='codex'; TargetMap=@{ codex=$target }; WhatIf=$true }
        Assert-True (-not (Test-Path -LiteralPath $target)) 'WhatIf must not create target'
    }

    Test-Case 'repeated install is idempotent (skips when up to date)' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        $tmp = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/install-agent.ps1' -Params @{ Runtime='codex'; TargetMap=@{ codex=$target }; Confirm=$false } | Out-Null
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/install-agent.ps1' -Params @{ Runtime='codex'; TargetMap=@{ codex=$target }; Confirm=$false }
        Assert-Contains $r.Output 'already up to date'
    }

    Test-Case 'target outside approved root is rejected without writing' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        # Retarget adapter to a temp file but set approvedRoots to a DIFFERENT temp dir.
        $tmp = New-TempDir
        $other = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        Set-Content -LiteralPath $target -Value 'UNTOUCHED' -NoNewline
        $ap = Join-Path $repo 'adapters/codex.json'
        $a = Get-Content -Raw -LiteralPath $ap | ConvertFrom-Json
        $a.installation.path = $target
        $a.installation.approvedRoots = @($other)
        $a | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ap
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/install-agent.ps1' -Params @{ Runtime='codex'; Confirm=$false }
        Assert-Equal 1 $r.ExitCode 'install outside approved root must fail'
        Assert-Equal 'UNTOUCHED' (Get-Content -Raw -LiteralPath $target) 'target must be untouched'
    }

    Test-Case 'install fails when generated artifact is stale' {
        $repo = New-SandboxRepo
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
        Add-Content -LiteralPath (Join-Path $repo 'generated/codex/AGENTS.md') -Value 'stale'
        $tmp = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/install-agent.ps1' -Params @{ Runtime='codex'; TargetMap=@{ codex=$target }; Confirm=$false }
        Assert-Equal 1 $r.ExitCode 'stale artifact must block install'
        Assert-True (-not (Test-Path -LiteralPath $target)) 'no target should be written'
    }

    Test-Case 'rollback restores the verified backup after a botched write (primitive)' {
        # Exercises the exact recovery machinery used by the installer catch block.
        $repo = New-SandboxRepo
        . (Join-Path $repo 'scripts/lib/Common.ps1')
        . (Join-Path $repo 'scripts/lib/Backup.ps1')
        $tmp = New-TempDir
        $target = Join-Path $tmp 'AGENTS.md'
        Set-Content -LiteralPath $target -Value 'GOOD-V1' -NoNewline
        $backupInfo = New-BackupDirectory -RepoRoot $repo
        $entry = Copy-FileWithHash -SourcePath $target -BackupDir $backupInfo.Path -RuntimeId 'codex' -BackupId $backupInfo.BackupId
        # Simulate a botched write leaving corrupt content.
        Set-Content -LiteralPath $target -Value 'CORRUPT' -NoNewline
        # Recovery: copy backup back and verify hash (installer catch logic).
        Copy-Item -LiteralPath $entry.backupPath -Destination $target -Force
        $restoredHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        Assert-Equal $entry.sha256 $restoredHash 'rollback must restore verified backup content'
        Assert-Equal 'GOOD-V1' (Get-Content -Raw -LiteralPath $target)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-TestHarness -RepoRoot (Split-Path $PSScriptRoot -Parent)
    Invoke-InstallAgentTests
    exit (Complete-Tests)
}
