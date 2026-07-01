# Start Here

This guide is for someone who does not already know Wake-on-LAN, router
scripting, Tailscale, or Linux services.

## Goal

Build phone buttons for a home Linux PC:

- **PC ON** wakes the PC from sleep or shutdown.
- **PC SUSPEND** puts the PC to sleep without losing the desktop session.
- **PC OFF** shuts the PC down cleanly.
- RustDesk reconnects after the PC wakes.

The practical point is power savings and convenience. The PC can sleep or stay
off when unused, while a router or another device that was already powered on
sends the wake packet.

## Safety Model

The power buttons should only be reachable through Tailscale or another private
VPN/network path.

Use this shape:

```text
iPhone -> Tailscale/private VPN -> router or relay -> WOL packet to PC
iPhone -> Tailscale/private VPN -> PC -> suspend/shutdown/status
```

Do not use this shape:

```text
iPhone -> public internet -> home router port forward -> power API
```

Before continuing:

- Do not create WAN port forwards for this project.
- Do not put tokens in URLs.
- Do not commit real tokens, IPs, MAC addresses, or RustDesk passwords.
- Use strong random tokens.
- Test suspend and wake while physically near the PC before relying on travel
  access.

## What You Need

### PC

Best fit:

- Desktop Linux PC.
- Wired Ethernet cable connected to the router/LAN.
- Motherboard firmware supports Wake-on-LAN or PCIe wake.
- Linux can suspend with `systemctl suspend`.
- RustDesk unattended access is already working or can be configured.

Poor fit:

- Wi-Fi-only PC.
- Laptop that moves between networks.
- PC that cannot wake from shutdown/suspend.
- PC that freezes when suspending locally.

### Router Or Relay

You need one always-on device on the same LAN as the PC. It can be:

- router
- NAS
- Home Assistant box
- Raspberry Pi
- mini PC
- other Linux server

It must be able to:

- stay on while the PC is off
- send Wake-on-LAN packets to the PC's wired MAC address
- run a small private service or equivalent command
- persist files after reboot
- be reachable through Tailscale/private VPN

If your router is locked down, use another already-on LAN device instead.

### Phone

- iPhone with Shortcuts.
- Tailscale installed and connected.
- RustDesk installed if you want remote desktop access.

See [Tailscale Setup](tailscale.md) and [RustDesk Notes](rustdesk.md) for the
app-specific setup steps.

## PC Firmware Settings

These settings are changed in BIOS/UEFI, not inside Linux.

General path:

1. Reboot the PC.
2. Press the firmware key during boot. Common keys: `Delete`, `F2`, `F10`,
   `F12`, or `Esc`.
3. Look under menus named `Advanced`, `Power`, `APM`, `Onboard Devices`,
   `PCIe`, `Network`, or `Boot`.
4. Enable wake settings.
5. Disable deep power-saving settings if they block wake.
6. Save and exit.

Common setting names to enable:

- `Wake-on-LAN`
- `Resume by LAN`
- `Power On By PCI-E`
- `PCIe Wake`
- `Wake by PCI-E Device`
- `PME Event Wake Up`

Common setting names to disable if wake does not work:

- `ErP`
- `ErP Ready`
- `Deep Sleep`
- `EuP`

Boot setting:

- Set the Linux drive first in boot order if this PC dual-boots.

Separate setting:

- `Restore after AC Power Loss` controls what happens after a power outage. It
  is not the same as Wake-on-LAN.

## Linux Checks

Run these on the PC.

Find the wired Ethernet interface:

```bash
ip link show
```

Common wired interface names look like:

```text
eno1
enp3s0
eth0
```

Check Wake-on-LAN support:

```bash
sudo ethtool <PC_WIRED_INTERFACE> | grep -E 'Supports Wake-on|Wake-on'
```

Good sign:

```text
Supports Wake-on: ... g ...
Wake-on: g
```

If `Wake-on` is not `g`, enable it:

```bash
sudo ethtool -s <PC_WIRED_INTERFACE> wol g
```

Test suspend locally:

```bash
systemctl suspend
```

The PC should actually sleep and wake by keyboard, mouse, power button, or WOL.
If it freezes or only blanks the screen, fix suspend before installing remote
sleep controls.

## Router Or Relay Checks

If using a router, log into the router web UI and look for:

- firmware name/version
- SSH access
- custom scripts/startup scripts
- package manager support
- Wake-on-LAN tool or command support
- VPN/Tailscale support

Good signs:

- ASUSWRT-Merlin with JFFS scripts and Entware.
- OpenWrt with packages.
- DD-WRT with persistent startup scripts.
- pfSense/OPNsense with service/firewall controls.
- Router shell has a command like `ether-wake`, `etherwake`, or `wakeonlan`.

Poor signs:

- ISP router with no SSH.
- Mesh router with no custom scripts.
- No way to install packages.
- No way to run startup scripts.
- Only way to access it remotely is WAN port forwarding.

If the router is not a fit, use another always-on LAN device as the relay.

USB storage on a router is not always required. It is commonly needed on
ASUSWRT-Merlin/Entware because `/opt` and installed packages usually live on
USB-backed persistent storage. It is not needed when the relay is a NAS,
Raspberry Pi, mini PC, Home Assistant box, or router firmware with enough normal
persistent storage.

## Values To Collect

Before editing service files, collect everything in
[Configuration Values](configuration-values.md).

Most important:

- PC Tailscale IP
- router/relay Tailscale IP
- PC wired Ethernet interface
- PC wired Ethernet MAC address
- router/relay LAN interface for WOL
- strong bearer tokens

Tailscale values come from `tailscale ip -4` on each device or from the
Tailscale admin/device UI.

## Build Order

Use this order:

1. Confirm PC firmware WOL settings.
2. Confirm Linux can suspend locally.
3. Confirm wired WOL can wake the PC locally.
4. Confirm the router/relay can send a WOL packet.
5. Install the PC API.
6. Install the router/relay wake API.
7. Add iOS Shortcuts.
8. Add RustDesk unattended access.
9. Add idle suspend only after manual suspend/wake works.

Then follow [End-To-End Setup](setup.md).
