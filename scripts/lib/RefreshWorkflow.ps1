# RefreshWorkflow.ps1
# Shared sequential build, verify, install, and installed-verification orchestration.
# Requires Common.ps1 and Configuration.ps1.

Set-StrictMode -Version Latest

function Invoke-AgentChildScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )

    & $ScriptPath @Parameters
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    if ($code -ne 0) {
        throw "Child script failed with exit code ${code}: $ScriptPath"
    }
}

function Invoke-AgentSystemRefresh {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$RuntimeRecords,
        [ValidateSet('Setup','Sync')][string]$Mode = 'Setup',
        [switch]$Force,
        [switch]$WhatIf,
        [hashtable]$TargetMap = @{}
    )

    $detected = @($RuntimeRecords | Where-Object { $_.Detected })
    if ($detected.Count -eq 0) {
        return [pscustomobject]@{
            Mode = $Mode
            Results = @()
            RestartRuntimes = @()
            Succeeded = $false
            ExitCode = 2
        }
    }

    if ($WhatIf) {
        Write-Section "$Mode preview"
        foreach ($runtime in $detected) {
            Write-Info ("Would build, verify, preview, install, and verify {0} -> {1}" -f $runtime.DisplayName, $runtime.InstallPath)
        }
        return [pscustomobject]@{
            Mode = $Mode
            Results = @($detected | ForEach-Object {
                [pscustomobject]@{ RuntimeId=$_.RuntimeId; DisplayName=$_.DisplayName; Action='WhatIf'; Target=$_.InstallPath }
            })
            RestartRuntimes = @()
            Succeeded = $true
            ExitCode = 0
        }
    }

    $scripts = Join-Path $RepoRoot 'scripts'
    $buildScript = Join-Path $scripts 'build-agent.ps1'
    $verifyScript = Join-Path $scripts 'verify-agent.ps1'
    $installScript = Join-Path $scripts 'install-agent.ps1'
    $results = @()
    $restart = @()

    foreach ($runtime in $detected) {
        $id = [string]$runtime.RuntimeId
        Write-Section ("Refresh {0}" -f $runtime.DisplayName)

        $beforeHash = $null
        if ($runtime.InstallPath -and (Test-Path -LiteralPath $runtime.InstallPath -PathType Leaf)) {
            $beforeHash = Get-Sha256OfFile -Path $runtime.InstallPath
        }

        try {
            Invoke-AgentChildScript -ScriptPath $buildScript -Parameters @{ Runtime = $id }
            Invoke-AgentChildScript -ScriptPath $verifyScript -Parameters @{ Scope = 'Generated'; Runtime = $id; Strict = $true }

            $previewParams = @{ Runtime = $id; WhatIf = $true; Confirm = $false }
            if ($TargetMap.ContainsKey($id)) { $previewParams.TargetMap = $TargetMap }
            Invoke-AgentChildScript -ScriptPath $installScript -Parameters $previewParams

            $installParams = @{ Runtime = $id; Confirm = $false }
            if ($Force) { $installParams.Force = $true }
            if ($TargetMap.ContainsKey($id)) { $installParams.TargetMap = $TargetMap }
            Invoke-AgentChildScript -ScriptPath $installScript -Parameters $installParams

            $verifyParams = @{ Scope = 'Installed'; Runtime = $id; Strict = $true }
            if ($TargetMap.ContainsKey($id)) {
                # Installed verification does not support TargetMap; compare hashes directly in tests/overrides.
                $generatedHash = Get-Sha256OfFile -Path $runtime.GeneratedPath
                $installedHash = Get-Sha256OfFile -Path ([string]$TargetMap[$id])
                if ($generatedHash -ne $installedHash) { throw "Installed verification failed for '$id'." }
            } else {
                Invoke-AgentChildScript -ScriptPath $verifyScript -Parameters $verifyParams
            }

            $targetPath = if ($TargetMap.ContainsKey($id)) { [string]$TargetMap[$id] } else { [string]$runtime.InstallPath }
            $afterHash = if (Test-Path -LiteralPath $targetPath -PathType Leaf) { Get-Sha256OfFile -Path $targetPath } else { $null }
            $changed = ($beforeHash -ne $afterHash)
            $action = if ($changed) { 'Updated' } else { 'AlreadyCurrent' }
            if ($changed) { $restart += $runtime.DisplayName }

            $results += [pscustomobject]@{
                RuntimeId = $id
                DisplayName = $runtime.DisplayName
                Action = $action
                Target = $targetPath
                Error = $null
            }
        }
        catch {
            $results += [pscustomobject]@{
                RuntimeId = $id
                DisplayName = $runtime.DisplayName
                Action = 'Failed'
                Target = $runtime.InstallPath
                Error = $_.Exception.Message
            }
            return [pscustomobject]@{
                Mode = $Mode
                Results = $results
                RestartRuntimes = $restart
                Succeeded = $false
                ExitCode = 1
            }
        }
    }

    return [pscustomobject]@{
        Mode = $Mode
        Results = $results
        RestartRuntimes = $restart
        Succeeded = $true
        ExitCode = 0
    }
}

function Show-AgentRefreshSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$RefreshResult,
        [Parameter(Mandatory)][array]$DetectionResults
    )

    Write-Section 'Summary'
    $rows = @()
    foreach ($d in $DetectionResults) {
        $match = @($RefreshResult.Results | Where-Object { $_.RuntimeId -eq $d.RuntimeId }) | Select-Object -First 1
        $status = if ($match) { $match.Action } elseif (-not $d.Detected) { 'NotDetected' } else { 'NotProcessed' }
        $rows += [pscustomobject]@{ Runtime=$d.DisplayName; Status=$status }
    }
    $rows | Format-Table -AutoSize | Out-String | Write-Host

    if ($RefreshResult.RestartRuntimes.Count -gt 0) {
        Write-Host ("Restart: {0}" -f ($RefreshResult.RestartRuntimes -join ', ')) -ForegroundColor Yellow
    } else {
        Write-Host 'No runtime restart is required because no installed instruction file changed.' -ForegroundColor Green
    }
}
