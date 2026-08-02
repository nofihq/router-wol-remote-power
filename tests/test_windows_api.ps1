$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$apiScript = Join-Path $repositoryRoot 'pc\windows\pc_power_api.ps1'
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ("phone-wol-power-test-" + [Guid]::NewGuid())
$tokenFile = Join-Path $testDirectory 'token'
$token = 'test-token-that-is-at-least-twenty-characters'
$serverProcess = $null

function Get-FreeLoopbackPort {
    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $probe.Start()
    try {
        return ([Net.IPEndPoint]$probe.LocalEndpoint).Port
    }
    finally {
        $probe.Stop()
    }
}

function Invoke-ExpectedResponse {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [int]$StatusCode,

        [hashtable]$Headers = @{},

        [string]$Method = 'GET',

        [string]$ExpectedBody
    )

    try {
        $response = Invoke-WebRequest `
            -UseBasicParsing `
            -Uri $Uri `
            -Method $Method `
            -Headers $Headers `
            -TimeoutSec 3
        $actualStatus = [int]$response.StatusCode
        $actualBody = $response.Content
    }
    catch {
        if ($null -eq $_.Exception.Response) {
            throw
        }
        $actualStatus = [int]$_.Exception.Response.StatusCode
        $actualBody = $null
    }

    if ($actualStatus -ne $StatusCode) {
        throw "Expected HTTP $StatusCode from $Uri, got $actualStatus."
    }

    if ($PSBoundParameters.ContainsKey('ExpectedBody') -and $actualBody -ne $ExpectedBody) {
        throw "Expected '$ExpectedBody' from $Uri, got '$actualBody'."
    }
}

try {
    New-Item -ItemType Directory -Path $testDirectory | Out-Null
    [IO.File]::WriteAllText($tokenFile, $token, [Text.UTF8Encoding]::new($false))
    $port = Get-FreeLoopbackPort
    $baseUri = "http://127.0.0.1:$port"
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = @(
        '-NoProfile'
        '-NonInteractive'
        '-ExecutionPolicy Bypass'
        "-File `"$apiScript`""
        '-ListenIp 127.0.0.1'
        "-Port $port"
        "-TokenFile `"$tokenFile`""
        '-TestMode'
    ) -join ' '

    $serverProcess = Start-Process `
        -FilePath $powershell `
        -ArgumentList $arguments `
        -WindowStyle Hidden `
        -PassThru

    $started = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 250
        try {
            Invoke-ExpectedResponse -Uri "$baseUri/status" -StatusCode 403
            $started = $true
            break
        }
        catch {
            if ($serverProcess.HasExited) {
                throw "Test API exited early with code $($serverProcess.ExitCode)."
            }
        }
    }

    if (-not $started) {
        throw 'Test API did not start within five seconds.'
    }

    $headers = @{ Authorization = "Bearer $token" }
    Invoke-ExpectedResponse -Uri "$baseUri/status" -StatusCode 200 -Headers $headers -ExpectedBody 'ON'
    Invoke-ExpectedResponse -Uri "$baseUri/missing" -StatusCode 404 -Headers $headers
    Invoke-ExpectedResponse -Uri "$baseUri/status" -StatusCode 405 -Headers $headers -Method 'POST'
    Invoke-ExpectedResponse -Uri "$baseUri/suspend" -StatusCode 200 -Headers $headers -ExpectedBody 'Suspending...'
    Invoke-ExpectedResponse -Uri "$baseUri/shutdown" -StatusCode 200 -Headers $headers -ExpectedBody 'Shutting down...'

    Write-Host 'Windows API smoke tests passed. TestMode suppressed all power actions.'
}
finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force
        $serverProcess.WaitForExit()
    }
    if (Test-Path -LiteralPath $testDirectory) {
        Remove-Item -LiteralPath $testDirectory -Recurse -Force
    }
}
