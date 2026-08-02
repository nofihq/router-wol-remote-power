[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ListenIp,

    [ValidateRange(1, 65535)]
    [int]$Port = 8081,

    [Parameter(Mandatory = $true)]
    [string]$TokenFile,

    [switch]$TestMode
)

$ErrorActionPreference = 'Stop'

function Test-FixedTimeEquals {
    param(
        [AllowEmptyString()]
        [string]$Actual,

        [AllowEmptyString()]
        [string]$Expected
    )

    $actualBytes = [Text.Encoding]::UTF8.GetBytes($Actual)
    $expectedBytes = [Text.Encoding]::UTF8.GetBytes($Expected)
    $difference = $actualBytes.Length -bxor $expectedBytes.Length
    $length = [Math]::Max($actualBytes.Length, $expectedBytes.Length)

    for ($index = 0; $index -lt $length; $index++) {
        $actualByte = if ($index -lt $actualBytes.Length) { $actualBytes[$index] } else { 0 }
        $expectedByte = if ($index -lt $expectedBytes.Length) { $expectedBytes[$index] } else { 0 }
        $difference = $difference -bor ($actualByte -bxor $expectedByte)
    }

    return $difference -eq 0
}

function Send-TextResponse {
    param(
        [Parameter(Mandatory = $true)]
        [Net.HttpListenerContext]$Context,

        [Parameter(Mandatory = $true)]
        [int]$StatusCode,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $body = [Text.Encoding]::UTF8.GetBytes($Message)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = 'text/plain; charset=utf-8'
    $Context.Response.ContentLength64 = $body.Length
    $Context.Response.KeepAlive = $false
    $Context.Response.OutputStream.Write($body, 0, $body.Length)
    $Context.Response.Close()
}

if (-not ('PhoneWolPower.NativePower' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace PhoneWolPower
{
    public static class NativePower
    {
        private const UInt32 TOKEN_ADJUST_PRIVILEGES = 0x0020;
        private const UInt32 TOKEN_QUERY = 0x0008;
        private const UInt32 SE_PRIVILEGE_ENABLED = 0x00000002;
        private const string SE_SHUTDOWN_NAME = "SeShutdownPrivilege";

        [StructLayout(LayoutKind.Sequential)]
        private struct LUID
        {
            public UInt32 LowPart;
            public Int32 HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct TOKEN_PRIVILEGES
        {
            public UInt32 PrivilegeCount;
            public LUID Luid;
            public UInt32 Attributes;
        }

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool OpenProcessToken(
            IntPtr ProcessHandle,
            UInt32 DesiredAccess,
            out IntPtr TokenHandle
        );

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool LookupPrivilegeValue(
            string lpSystemName,
            string lpName,
            out LUID lpLuid
        );

        [DllImport("advapi32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool AdjustTokenPrivileges(
            IntPtr TokenHandle,
            [MarshalAs(UnmanagedType.Bool)] bool DisableAllPrivileges,
            ref TOKEN_PRIVILEGES NewState,
            UInt32 BufferLength,
            IntPtr PreviousState,
            IntPtr ReturnLength
        );

        [DllImport("kernel32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr handle);

        [DllImport("powrprof.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetSuspendState(
            [MarshalAs(UnmanagedType.Bool)] bool hibernate,
            [MarshalAs(UnmanagedType.Bool)] bool forceCritical,
            [MarshalAs(UnmanagedType.Bool)] bool disableWakeEvent
        );

        private static void EnableShutdownPrivilege()
        {
            IntPtr tokenHandle;
            if (!OpenProcessToken(
                Process.GetCurrentProcess().Handle,
                TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                out tokenHandle))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            try
            {
                LUID luid;
                if (!LookupPrivilegeValue(null, SE_SHUTDOWN_NAME, out luid))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                TOKEN_PRIVILEGES privileges = new TOKEN_PRIVILEGES();
                privileges.PrivilegeCount = 1;
                privileges.Luid = luid;
                privileges.Attributes = SE_PRIVILEGE_ENABLED;

                if (!AdjustTokenPrivileges(
                    tokenHandle,
                    false,
                    ref privileges,
                    0,
                    IntPtr.Zero,
                    IntPtr.Zero))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                int error = Marshal.GetLastWin32Error();
                if (error != 0)
                {
                    throw new Win32Exception(error);
                }
            }
            finally
            {
                CloseHandle(tokenHandle);
            }
        }

        public static void Suspend()
        {
            EnableShutdownPrivilege();
            if (!SetSuspendState(false, false, false))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
        }
    }
}
'@
}

$parsedIp = $null
if (-not [Net.IPAddress]::TryParse($ListenIp, [ref]$parsedIp)) {
    throw "ListenIp is not a valid IP address: $ListenIp"
}

if ($parsedIp.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
    throw 'ListenIp must be an IPv4 address.'
}

if ($TestMode -and -not [Net.IPAddress]::IsLoopback($parsedIp)) {
    throw 'TestMode is restricted to a loopback listen address.'
}

if (-not (Test-Path -LiteralPath $TokenFile -PathType Leaf)) {
    throw "Token file does not exist: $TokenFile"
}

$token = (Get-Content -Raw -LiteralPath $TokenFile).Trim()
if ($token.Length -lt 20) {
    throw 'Refusing to start with a short bearer token.'
}

$listener = [Net.HttpListener]::new()
$prefix = "http://${ListenIp}:$Port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
    Write-Host "PC power API listening on $prefix"

    while ($listener.IsListening) {
        $context = $listener.GetContext()

        try {
            if ($context.Request.HttpMethod -ne 'GET') {
                Send-TextResponse -Context $context -StatusCode 405 -Message 'Method Not Allowed'
                continue
            }

            $authorization = $context.Request.Headers['Authorization']
            if (-not (Test-FixedTimeEquals -Actual $authorization -Expected "Bearer $token")) {
                Send-TextResponse -Context $context -StatusCode 403 -Message 'Forbidden'
                continue
            }

            switch ($context.Request.Url.AbsolutePath) {
                '/status' {
                    Send-TextResponse -Context $context -StatusCode 200 -Message 'ON'
                }
                '/shutdown' {
                    Write-Host 'Shutdown authorized'
                    Send-TextResponse -Context $context -StatusCode 200 -Message 'Shutting down...'
                    if ($TestMode) {
                        Write-Host 'TestMode: shutdown command suppressed'
                    }
                    else {
                        $shutdown = Join-Path $env:SystemRoot 'System32\shutdown.exe'
                        Start-Process -FilePath $shutdown -ArgumentList '/s', '/t', '0' -WindowStyle Hidden
                    }
                }
                '/suspend' {
                    Write-Host 'Suspend authorized'
                    Send-TextResponse -Context $context -StatusCode 200 -Message 'Suspending...'
                    if ($TestMode) {
                        Write-Host 'TestMode: suspend command suppressed'
                    }
                    else {
                        [PhoneWolPower.NativePower]::Suspend()
                    }
                }
                default {
                    Send-TextResponse -Context $context -StatusCode 404 -Message 'Not Found'
                }
            }
        }
        catch {
            Write-Warning $_.Exception.Message
            try {
                if ($context.Response.OutputStream.CanWrite) {
                    Send-TextResponse -Context $context -StatusCode 500 -Message 'Power action failed'
                }
            }
            catch {
                # The success response may already be closed before a power action fails.
            }
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
