# Windows Setup

Windows uses the same phone shortcuts and router wake API as Linux. The only
new piece is a Windows implementation of the PC API for `/status`, `/suspend`,
and `/shutdown`.

The Windows installer does not require Python. It installs the PowerShell API
under `%ProgramData%\phone-wol-power`, creates a startup task that runs as the
built-in `SYSTEM` account, and adds a narrowly scoped inbound firewall rule.

## Requirements

- Windows 10 or Windows 11 on the target PC
- Windows PowerShell 5.1, included with supported Windows installations
- an Administrator account for installation and removal
- wired Ethernet with firmware and NIC-driver Wake-on-LAN support
- a private route from the phone to the PC, or a router that can relay the
  requests; do not expose ports 8080 or 8081 to the public internet

No Python module, PowerShell Gallery module, package manager, or third-party
Windows service wrapper is required. The installer uses only Windows PowerShell
and built-in Windows components.

There are two supported network modes:

- **Direct Tailscale:** bind to the Windows Tailscale IP and allow the
  Tailscale IPv4 range.
- **Router relay:** bind to the Windows LAN IP and allow only the router LAN
  IP. The phone calls the router dispatcher, so Windows does not need
  Tailscale. This is useful when the router already provides the VPN path.

## Important For A Dual-Boot PC

Windows and Linux normally appear as separate Tailscale devices and can have
different Tailscale IP addresses. The router `/wake` shortcut remains the same.
A shortcut hard-coded to the Linux PC address cannot reach Windows.

Options are:

- use the optional router dispatcher described under
  [Dual-Boot Automatic Routing](ios-shortcuts.md#dual-boot-automatic-routing)
- create Windows and Linux versions of the two PC power shortcuts

Do not copy Tailscale state files between the two operating systems merely to
force them to share an identity.

The router dispatcher is the reliable one-shortcut approach: the always-on
router tries the Linux and Windows PC APIs and uses whichever answers. Wake
from a full shutdown still follows your bootloader default. If Linux is first
without a boot-menu selection, a full-off WOL boot enters Linux; the router
cannot silently choose Windows.

## 1. Check Firmware And Windows WOL

Keep the same UEFI/BIOS settings used by Linux:

- enable Wake-on-LAN, PCIe wake, or power-on-by-PCIe
- disable ErP/deep sleep if it removes standby power from the NIC
- use the wired Ethernet MAC address in the router wake API

In Windows Device Manager, open the wired adapter and check the driver-specific
settings. Typical names are:

- **Advanced**: `Wake on Magic Packet` = enabled
- **Advanced**: `Shutdown Wake-On-Lan` = enabled, if present
- **Power Management**: allow this device to wake the computer
- **Power Management**: only allow a magic packet to wake the computer

Driver names vary, and some adapters do not expose every option. Update the NIC
driver from the PC or motherboard vendor if these settings are missing.

Fast Startup uses a hybrid shutdown path and can make wake-from-shutdown
driver-dependent. If WOL works from sleep but not after Windows shutdown,
disable **Turn on fast startup** in Windows Power Options and test again. The
command `powercfg /hibernate off` also disables Fast Startup, but it disables
hibernation too.

Check which sleep states Windows exposes:

```powershell
powercfg /a
```

If Windows itself freezes, only blanks the display, or cannot resume during a
local test, do not rely on remote suspend yet. That is a firmware/driver/power-
state problem rather than an HTTP shortcut problem.

## 2. Install The PC API

For direct mode, install Tailscale in Windows, sign in, and get this Windows
installation's Tailscale IPv4 address:

```powershell
tailscale ip -4
```

Open **Windows PowerShell as Administrator** in the repository directory.

For a new single-OS setup, generate a strong PC token:

```powershell
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$token = [Convert]::ToBase64String($bytes)
$token
```

For a dual-boot PC using the router dispatcher, do **not** generate an
independent Windows token. Set `$token` to the same `<PC_TOKEN>` already used
by the Linux API and the router's `PC_AUTH_TOKEN_FILE`. Keep the router wake
token separate.

Save the PC token somewhere private, then install:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\pc\windows\install_windows.ps1 `
  -PcListenIp <WINDOWS_PC_TAILSCALE_IP> `
  -Token $token
```

For router-relay mode, give the wired NIC a DHCP reservation, then use its LAN
IP and allow only the router LAN address:

```powershell
.\pc\windows\install_windows.ps1 `
  -PcListenIp <WINDOWS_PC_LAN_IP> `
  -AllowedRemoteAddress <ROUTER_LAN_IP> `
  -Token $token
```

Add the Windows LAN target to the router dispatcher:

```text
PC_API_TARGETS=http://<LINUX_PC_REACHABLE_IP>:8081,http://<WINDOWS_PC_LAN_IP>:8081
```

The installer starts the API immediately and also at every Windows boot. It
does not suspend or shut down the PC during installation.

## 3. Safe Status Test

This request is read-only and does not change the PC power state:

```powershell
$headers = @{ Authorization = "Bearer $token" }
Invoke-RestMethod -Headers $headers -Uri http://<PC_LISTEN_IP>:8081/status
```

Expected response:

```text
ON
```

In direct mode, try the same request from the phone while Tailscale is
connected. In relay mode, test `/status` through the router dispatcher. Do not
test the suspend or shutdown endpoints until you are physically near the PC
and have confirmed local Windows sleep/resume and router WOL independently.

## 4. Use The Existing Shortcuts

In direct single-OS mode, call Windows at its configured listener:

```text
PC SUSPEND: GET http://<PC_LISTEN_IP>:8081/suspend
PC OFF:     GET http://<PC_LISTEN_IP>:8081/shutdown
Header:     Authorization: Bearer <PC_TOKEN>
```

For a dual-boot PC using the router dispatcher, use the same router URLs for
Windows and Linux. Do not use `<PC_LISTEN_IP>` in the phone shortcuts:

```text
PC SUSPEND: GET http://<ROUTER_TAILSCALE_IP>:8080/suspend
PC OFF:     GET http://<ROUTER_TAILSCALE_IP>:8080/shutdown
Header:     Authorization: Bearer <PC_TOKEN>
```

`PC ON` still calls the router:

```text
GET http://<ROUTER_TAILSCALE_IP>:8080/wake
Authorization: Bearer <ROUTER_TOKEN>
```

The Windows API uses the native Windows suspend API for sleep and
`shutdown.exe /s /t 0` for a clean shutdown.

## Optional: Automatic Windows Sign-In

Automatic sign-in is **not required** for this project's status, suspend, or
shutdown routes. The scheduled task starts the API as `SYSTEM` during Windows
startup, before an interactive user signs in.

Auto-login can still be useful when an unattended desktop application needs a
signed-in user session. It also leaves the Windows desktop accessible to anyone
with physical access to the PC, so enable it only when that tradeoff is
acceptable.

Use Microsoft's signed
[Sysinternals Autologon](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon)
utility rather than adding a plaintext password to a script or this repository.
Download the version appropriate for the PC and run it as Administrator.

For a Microsoft-account-backed Windows user:

1. Run Autologon as Administrator.
2. Enter the full Microsoft account email as the username, enter
   `MicrosoftAccount` as the domain, and type the password directly into the
   Autologon window.
3. Select **Enable**. Do not pass the password on the command line, place it in
   a PowerShell script, or commit it to Git.

Run Autologon again and select **Disable** to turn automatic sign-in off.
Holding Shift during startup bypasses automatic sign-in for that boot. Microsoft
stores the password as an LSA secret, but an administrator can still retrieve
it; treat the PC as unlocked whenever automatic sign-in is enabled.

## Troubleshooting

Inspect the startup task without performing a power action:

```powershell
Get-ScheduledTask -TaskName 'Phone WOL Power API'
Get-ScheduledTaskInfo -TaskName 'Phone WOL Power API'
Get-NetTCPConnection -LocalPort 8081 -State Listen
Get-NetFirewallRule -Name 'PhoneWolPowerApi-Tailscale'
```

If `/status` works locally but not through the intended path:

- in direct mode, confirm the phone and Windows are connected to the same
  tailnet and the shortcut uses the Windows Tailscale IP
- in relay mode, confirm the router can reach the Windows LAN IP and the
  firewall rule's allowed remote address is the router LAN IP
- confirm no broader Windows security product is blocking port 8081
- confirm no WAN port forward was created; none is needed

If suspend returns success but Windows only blanks or freezes, stop remote
testing. Update BIOS/UEFI, chipset, GPU, and NIC drivers, then test Windows sleep
locally. `powercfg /a`, `powercfg /requests`, and `powercfg /systemsleepdiagnostics`
can help identify power-state support and blockers.

## Update Or Remove

After pulling a newer repository version, rerun `install_windows.ps1` with the
same IP and token. It replaces the installed API and refreshes the task and
firewall rule.

To remove the task, firewall rule, installed API, and stored token, run as
Administrator:

```powershell
.\pc\windows\uninstall_windows.ps1
```

Use `-KeepConfiguration` to remove only the task and firewall rule while
leaving `%ProgramData%\phone-wol-power` in place.
