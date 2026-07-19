# restore-backup.Tests.ps1
# Restore tests. All targets are temporary directories via -TargetMap.
# These tests never touch real .codex / .claude / .gemini paths.

. (Join-Path $PSScriptRoot '_harness.ps1')

function New-BackupViaInstall {
    <# Install into a temp target to produce a real backup of prior content. Returns context. #>
    param([string]$Repo, [string]$PriorContent = 'PRIOR-CONTENT')
    Invoke-Script -RepoRoot $Repo -ScriptRelPath 'scripts/build-agent.ps1' -Arguments @('-Runtime','codex') | Out-Null
    $tmp = New-TempDir
    $target = Join-Path $tmp 'AGENTS.md'
    Set-Content -LiteralPath $target -Value $PriorContent -NoNewline
    Invoke-Script -RepoRoot $Repo -ScriptRelPath 'scripts/install-agent.ps1' -Params @{ Runtime='codex'; TargetMap=@{ codex=$target }; Confirm=$false } | Out-Null
    $backupDir = Get-ChildItem (Join-Path $Repo 'backups') -Directory | Sort-Object Name -Descending | Select-Object -First 1
    return [pscustomobject]@{ Target=$target; BackupId=$backupDir.Name; BackupDir=$backupDir.FullName; PriorContent=$PriorContent }
}

function Invoke-RestoreBackupTests {
    Write-Host "== restore-backup tests ==" -ForegroundColor Cyan

    Test-Case 'list shows created backups' {
        $repo = New-SandboxRepo
        $ctx = New-BackupViaInstall -Repo $repo
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/restore-backup.ps1' -Params @{ List=$true }
        Assert-Equal 0 $r.ExitCode
        Assert-Contains $r.Output $ctx.BackupId
    }

    Test-Case 'restore by BackupId restores prior content' {
        $repo = New-SandboxRepo
        $ctx = New-BackupViaInstall -Repo $repo -PriorContent 'ORIGINAL-XYZ'
        # Target currently holds the generated artifact; restore should return prior content.
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/restore-backup.ps1' -Params @{ BackupId=$ctx.BackupId; Runtime='codex'; TargetMap=@{ codex=$ctx.Target }; Confirm=$false }
        Assert-Equal 0 $r.ExitCode 'restore should succeed'
        Assert-Equal 'ORIGINAL-XYZ' (Get-Content -Raw -LiteralPath $ctx.Target) 'prior content not restored'
    }

    Test-Case 'restore -Latest selects the newest matching backup' {
        $repo = New-SandboxRepo
        $ctx = New-BackupViaInstall -Repo $repo -PriorContent 'LATEST-CONTENT'
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/restore-backup.ps1' -Params @{ Latest=$true; Runtime='codex'; TargetMap=@{ codex=$ctx.Target }; Confirm=$false }
        Assert-Equal 0 $r.ExitCode
        Assert-Equal 'LATEST-CONTENT' (Get-Content -Raw -LiteralPath $ctx.Target)
    }

    Test-Case 'restore -WhatIf performs no write' {
        $repo = New-SandboxRepo
        $ctx = New-BackupViaInstall -Repo $repo -PriorContent 'ORIG'
        $before = Get-Content -Raw -LiteralPath $ctx.Target
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/restore-backup.ps1' -Params @{ BackupId=$ctx.BackupId; Runtime='codex'; TargetMap=@{ codex=$ctx.Target }; WhatIf=$true } | Out-Null
        $after = Get-Content -Raw -LiteralPath $ctx.Target
        Assert-Equal $before $after 'WhatIf must not modify target'
    }

    Test-Case 'restore backs up the current target before restoring' {
        $repo = New-SandboxRepo
        $ctx = New-BackupViaInstall -Repo $repo -PriorContent 'ORIG'
        $countBefore = @(Get-ChildItem (Join-Path $repo 'backups') -Directory).Count
        Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/restore-backup.ps1' -Params @{ BackupId=$ctx.BackupId; Runtime='codex'; TargetMap=@{ codex=$ctx.Target }; Confirm=$false } | Out-Null
        $countAfter = @(Get-ChildItem (Join-Path $repo 'backups') -Directory).Count
        Assert-True ($countAfter -gt $countBefore) 'a pre-restore backup should be created'
    }

    Test-Case 'corrupted backup is rejected (hash mismatch)' {
        $repo = New-SandboxRepo
        $ctx = New-BackupViaInstall -Repo $repo -PriorContent 'ORIG'
        # Corrupt the backed-up file so its hash no longer matches the manifest.
        $entry = (Get-Content -Raw -LiteralPath (Join-Path $ctx.BackupDir 'manifest.json') | ConvertFrom-Json).files | Select-Object -First 1
        Add-Content -LiteralPath $entry.backupPath -Value 'corruption'
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/restore-backup.ps1' -Params @{ BackupId=$ctx.BackupId; Runtime='codex'; TargetMap=@{ codex=$ctx.Target }; Confirm=$false }
        Assert-Equal 1 $r.ExitCode 'corrupted backup must be rejected'
        Assert-Contains $r.Output 'integrity'
    }

    Test-Case 'restore target outside approved root is rejected' {
        $repo = New-SandboxRepo
        $ctx = New-BackupViaInstall -Repo $repo -PriorContent 'ORIG'
        # No TargetMap: restore resolves the adapter path (real). Retarget adapter to a temp
        # file but set approvedRoots to a different dir to force rejection safely.
        $tmp = New-TempDir
        $other = New-TempDir
        $rt = Join-Path $tmp 'AGENTS.md'
        Set-Content -LiteralPath $rt -Value 'KEEP' -NoNewline
        $ap = Join-Path $repo 'adapters/codex.json'
        $a = Get-Content -Raw -LiteralPath $ap | ConvertFrom-Json
        $a.installation.path = $rt
        $a.installation.approvedRoots = @($other)
        $a | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ap
        $r = Invoke-Script -RepoRoot $repo -ScriptRelPath 'scripts/restore-backup.ps1' -Params @{ BackupId=$ctx.BackupId; Runtime='codex'; Confirm=$false }
        Assert-Equal 1 $r.ExitCode 'restore outside approved root must fail'
        Assert-Equal 'KEEP' (Get-Content -Raw -LiteralPath $rt) 'target must be untouched'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-TestHarness -RepoRoot (Split-Path $PSScriptRoot -Parent)
    Invoke-RestoreBackupTests
    exit (Complete-Tests)
}
