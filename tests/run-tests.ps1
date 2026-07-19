#requires -Version 5.1
<#
.SYNOPSIS
    Run the full Universal Agent System test suite.

.DESCRIPTION
    Pester-independent smoke/integration tests. If Pester 5+ is available it is not
    required; these tests run directly under Windows PowerShell 5.1 and PowerShell 7.
    All installation/restore tests operate exclusively in temporary directories and
    never touch real runtime instruction files.

.EXAMPLE
    .\tests\run-tests.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '_harness.ps1')
Initialize-TestHarness -RepoRoot (Split-Path $PSScriptRoot -Parent)

# Dot-source suites (defines Invoke-*Tests without self-running).
. (Join-Path $PSScriptRoot 'build-agent.Tests.ps1')
. (Join-Path $PSScriptRoot 'verify-agent.Tests.ps1')
. (Join-Path $PSScriptRoot 'install-agent.Tests.ps1')
. (Join-Path $PSScriptRoot 'restore-backup.Tests.ps1')

Invoke-BuildAgentTests
Invoke-VerifyAgentTests
Invoke-InstallAgentTests
Invoke-RestoreBackupTests

$failCount = Complete-Tests
if ($failCount -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
