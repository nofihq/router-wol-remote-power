# OS Support

This repository ships a Linux implementation of a broader architecture:

```text
phone -> private network -> always-on LAN relay -> WOL target
phone -> private network -> awake target -> suspend/shutdown API
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

The architecture can work, but the included PC-side scripts do not directly
apply.

What still applies:

- router-side WOL
- Tailscale private reachability
- iOS Shortcuts calling private HTTP endpoints
- RustDesk unattended access

What must change:

- install the PC API as a Windows service
- replace Linux helpers with Windows sleep/shutdown commands
- configure Windows power settings and NIC WOL settings
- allow only the tailnet/private interface through Windows Firewall

Windows shutdown can be handled with commands such as `shutdown /s /t 0`.
Sleep support depends on power policy, Modern Standby/S3 support, drivers, and
the service account used to trigger sleep.

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

ASUSWRT-Merlin with Entware is the documented path. OpenWrt, DD-WRT, pfSense,
OPNsense, a NAS, or another always-on LAN device can provide the same role if
it can run a small private service and send WOL packets.
