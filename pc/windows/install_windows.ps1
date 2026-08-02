[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('PcTailscaleIp')]
    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}$')]
    [string]$PcListenIp,

    [Parameter(Mandatory = $true, ParameterSetName = 'TokenValue')]
    [ValidateLength(20, 4096)]
    [string]$Token,

    [Parameter(Mandatory = $true, ParameterSetName = 'TokenFile')]
    [string]$SourceTokenFile,

    [ValidateRange(1, 65535)]
    [int]$Port = 8081,

    [string[]]$AllowedRemoteAddress = @('100.64.0.0/10')
)

$ErrorActionPreference = 'Stop'
$taskName = 'Phone WOL Power API'
$firewallRuleName = 'PhoneWolPowerApi-Tailscale'
$installDirectory = Join-Path $env:ProgramData 'phone-wol-power'
$installedApi = Join-Path $installDirectory 'pc_power_api.ps1'
$tokenFile = Join-Path $installDirectory 'token'
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this installer from PowerShell as Administrator.'
}

$parsedIp = $null
if (-not [Net.IPAddress]::TryParse($PcListenIp, [ref]$parsedIp) -or
    $parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
    throw 'PcListenIp must be an IPv4 address assigned to this PC.'
}

if (-not (Get-NetIPAddress -AddressFamily IPv4 -IPAddress $PcListenIp -ErrorAction SilentlyContinue)) {
    throw "PcListenIp is not currently assigned to this PC: $PcListenIp"
}

if ($AllowedRemoteAddress.Count -eq 0) {
    throw 'Provide at least one private AllowedRemoteAddress.'
}

if ($PSCmdlet.ParameterSetName -eq 'TokenFile') {
    if (-not (Test-Path -LiteralPath $SourceTokenFile -PathType Leaf)) {
        throw "Source token file does not exist: $SourceTokenFile"
    }
    $Token = (Get-Content -Raw -LiteralPath $SourceTokenFile).Trim()
}

if ($Token.Length -lt 20) {
    throw 'Refusing to install with a short bearer token.'
}

$sourceApi = Join-Path $PSScriptRoot 'pc_power_api.ps1'
if (-not (Test-Path -LiteralPath $sourceApi -PathType Leaf)) {
    throw "Missing Windows API script: $sourceApi"
}

New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null

$directoryAcl = [Security.AccessControl.DirectorySecurity]::new()
$directoryAcl.SetAccessRuleProtection($true, $false)
$inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
$propagation = [Security.AccessControl.PropagationFlags]::None
$systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
$administratorsSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$directoryAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $systemSid,
    [Security.AccessControl.FileSystemRights]::FullControl,
    $inheritance,
    $propagation,
    [Security.AccessControl.AccessControlType]::Allow
))
$directoryAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $administratorsSid,
    [Security.AccessControl.FileSystemRights]::FullControl,
    $inheritance,
    $propagation,
    [Security.AccessControl.AccessControlType]::Allow
))
Set-Acl -LiteralPath $installDirectory -AclObject $directoryAcl

Copy-Item -LiteralPath $sourceApi -Destination $installedApi -Force
[IO.File]::WriteAllText($tokenFile, "$($Token.Trim())`r`n", [Text.UTF8Encoding]::new($false))

foreach ($privateFile in @($installedApi, $tokenFile)) {
    $fileAcl = [Security.AccessControl.FileSecurity]::new()
    $fileAcl.SetAccessRuleProtection($true, $false)
    $fileAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $systemSid,
        [Security.AccessControl.FileSystemRights]::FullControl,
        [Security.AccessControl.AccessControlType]::Allow
    ))
    $fileAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        $administratorsSid,
        [Security.AccessControl.FileSystemRights]::FullControl,
        [Security.AccessControl.AccessControlType]::Allow
    ))
    Set-Acl -LiteralPath $privateFile -AclObject $fileAcl
}

$arguments = @(
    '-NoProfile'
    '-NonInteractive'
    '-ExecutionPolicy Bypass'
    "-File `"$installedApi`""
    "-ListenIp $PcListenIp"
    "-Port $Port"
    "-TokenFile `"$tokenFile`""
) -join ' '

$taskAction = New-ScheduledTaskAction -Execute $powershell -Argument $arguments
$taskTrigger = New-ScheduledTaskTrigger -AtStartup
$taskSettings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew
$taskPrincipal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $taskAction `
    -Trigger $taskTrigger `
    -Settings $taskSettings `
    -Principal $taskPrincipal `
    -Description 'Private Tailscale API for PC status, suspend, and shutdown.' `
    -Force | Out-Null

if (Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -Name $firewallRuleName
}

New-NetFirewallRule `
    -Name $firewallRuleName `
    -DisplayName 'Phone WOL Power API (private relay only)' `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalAddress $PcListenIp `
    -LocalPort $Port `
    -RemoteAddress $AllowedRemoteAddress `
    -Profile Any | Out-Null

Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 2

$taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
Write-Host "Installed and started $taskName."
Write-Host "Status URL: http://${PcListenIp}:$Port/status"
Write-Host "Task result: $($taskInfo.LastTaskResult) (0 or 267009 means running successfully)"
Write-Host 'Use the same bearer token in the PC SUSPEND, PC OFF, and PC STATUS shortcuts.'
