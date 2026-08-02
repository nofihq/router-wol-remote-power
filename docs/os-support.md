# OS Support

This repository ships Linux and Windows implementations of a broader
architecture:

```text
phone -> private network -> router wake API -> WOL target
phone -> private network -> awake target -> suspend/shutdown API
phone -> private network -> optional router dispatcher -> active OS API
```

## Linux

Best-supported target.

The included PC API and helper scripts assume:

- systemd
- Python 3
- `sudo`
- `ethtool`
- a wired Ethernet interface
- a suspend path that works through `systemctl suspend`

Ubuntu and other GNOME/systemd distributions are the easiest fit. Other
systemd distributions should work with path and package changes. Non-GNOME
desktops need different idle-suspend configuration. Non-systemd distributions
need different service and suspend commands.

## Windows

The included `pc/windows` implementation provides the same `/status`,
`/suspend`, and `/shutdown` routes as Linux without requiring Python. Its
installer:

- stores the API and token under `%ProgramData%\phone-wol-power`
- runs the API at boot as `SYSTEM` through Windows Task Scheduler
- binds the API to a chosen Windows Tailscale or LAN IPv4 address
- limits the inbound firewall rule to Tailscale peers or only the router relay
- uses the native Windows suspend API and `shutdown.exe /s /t 0`

Sleep support still depends on power policy, Modern Standby/S3 support,
firmware, and drivers. WOL must also be enabled in the wired NIC's Windows
driver settings. See [Windows Setup](windows-setup.md).

On a dual-boot PC, Linux and Windows normally have separate Tailscale device
identities and IPs. The router wake URL remains the same, but a phone shortcut
cannot know which direct OS address is active. Use the optional router
dispatcher for one automatic shortcut set, or maintain clearly named direct
shortcut sets for each OS.

## macOS

The architecture can work for some Macs, but wake behavior is more
model-dependent than a wired desktop PC.

What still applies:

- Tailscale private reachability while awake
- iOS Shortcuts calling private HTTP endpoints
- RustDesk unattended access

What must change:

- install the PC API with `launchd`
- replace Linux helpers with macOS commands such as `pmset sleepnow` and
  `shutdown -h now`
- configure macOS power settings, firewall rules, and wake support

Wake-on-LAN support on Macs varies by model, network adapter, power state, and
"Wake for network access" behavior. Test before relying on it while traveling.

## Router Side

The router wake API is mostly target-OS independent. It only needs to send a
valid WOL magic packet to the target machine's wired NIC on the LAN.

ASUSWRT-Merlin with Entware is the documented router path. OpenWrt, DD-WRT,
and pfSense/OPNsense can provide the same router role if they can run a small
private service and send WOL packets.

NAS, Home Assistant, Raspberry Pi, mini PC, and Linux servers are fallback
relay options when the router cannot run the wake API.
