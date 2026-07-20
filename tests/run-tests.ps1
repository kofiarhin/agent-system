#requires -Version 5.1
<#
.SYNOPSIS
    Run the full Universal Agent System test suite.
.DESCRIPTION
    Pester-independent smoke/integration tests for build, verification, installation,
    restore, runtime detection, and streamlined setup/sync orchestration. Tests use
    temporary directories and never touch real runtime instruction files.
.EXAMPLE
    .\tests\run-tests.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '_harness.ps1')
Initialize-TestHarness -RepoRoot (Split-Path $PSScriptRoot -Parent)

. (Join-Path $PSScriptRoot 'build-agent.Tests.ps1')
. (Join-Path $PSScriptRoot 'verify-agent.Tests.ps1')
. (Join-Path $PSScriptRoot 'install-agent.Tests.ps1')
. (Join-Path $PSScriptRoot 'restore-backup.Tests.ps1')
. (Join-Path $PSScriptRoot 'setup-sync.Tests.ps1')

Invoke-BuildAgentTests
Invoke-VerifyAgentTests
Invoke-InstallAgentTests
Invoke-RestoreBackupTests
Invoke-SetupSyncTests

$failCount = Complete-Tests
if ($failCount -gt 0) { exit 1 }
Write-Host 'ALL TESTS PASSED' -ForegroundColor Green
exit 0
