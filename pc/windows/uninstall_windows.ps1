[CmdletBinding()]
param(
    [switch]$KeepConfiguration
)

$ErrorActionPreference = 'Stop'
$taskName = 'Phone WOL Power API'
$firewallRuleName = 'PhoneWolPowerApi-Tailscale'
$installDirectory = Join-Path $env:ProgramData 'phone-wol-power'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this uninstaller from PowerShell as Administrator.'
}

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

if (Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -Name $firewallRuleName
}

if (-not $KeepConfiguration -and (Test-Path -LiteralPath $installDirectory)) {
    $resolvedInstallDirectory = (Resolve-Path -LiteralPath $installDirectory).Path
    $expectedInstallDirectory = [IO.Path]::GetFullPath(
        (Join-Path $env:ProgramData 'phone-wol-power')
    ).TrimEnd('\')

    if ($resolvedInstallDirectory.TrimEnd('\') -ne $expectedInstallDirectory) {
        throw "Refusing to remove unexpected directory: $resolvedInstallDirectory"
    }

    Remove-Item -LiteralPath $resolvedInstallDirectory -Recurse -Force
    Write-Host "Removed task, firewall rule, API files, and token from $resolvedInstallDirectory."
}
else {
    Write-Host 'Removed the task and firewall rule. Configuration files were kept.'
}
