# Router And Relay Support

This project does not require one exact router brand. It requires one
always-on device on the home LAN that can send a Wake-on-LAN packet and receive
a private request from your phone.

If you do not know whether your router is a fit, check the router web UI first.
Look for SSH access, custom/startup scripts, package support, Wake-on-LAN, and
VPN/Tailscale support. If those do not exist, the router is probably not the
right relay.

## Required Capabilities

The router or relay device must be able to:

- stay powered on while the PC is off or suspended
- reach the PC's wired Ethernet LAN/VLAN
- send a Wake-on-LAN magic packet to the PC's wired MAC address
- run a small private service or equivalent command endpoint
- keep files after reboot
- start the wake service automatically after reboot
- be reachable from the phone through Tailscale, another VPN, or a private-only
  network path
- avoid public WAN port forwarding

If any of those are missing, this repo can still be adapted, but the documented
setup will not work as written.

## Good Fits

### ASUSWRT-Merlin

Good fit when the model supports:

- SSH access
- JFFS custom scripts
- USB-backed persistent `/opt` storage
- Entware packages
- Python or another way to run the wake API
- `ether-wake` or another WOL sender
- Tailscale or another private path to the router

The included `router/S99wake-api.example` is written for this style of setup.

### OpenWrt

Good fit when packages are available for:

- Python 3
- Tailscale or another VPN/private access method
- a WOL sender such as `etherwake` or `wakeonlan`

Use OpenWrt's service/procd system instead of the included Entware init script.
The Python wake API can stay the same.

### DD-WRT

Can work when the router has:

- persistent startup scripts
- SSH/shell access
- a WOL command
- private VPN/Tailscale-style reachability

DD-WRT device capabilities vary. Treat this as an adaptation target, not a
copy/paste target.

### pfSense / OPNsense

Can work when you implement the wake endpoint with the platform's service model
and keep it private. These platforms often have strong firewall controls, so
only allow the API from the VPN/private interface.

### NAS, Home Assistant, Raspberry Pi, Mini PC, Or Linux Server

These can all act as the relay if they are already on and on the same LAN as
the PC. This is practical if the device is already running. It is less
energy-efficient if you add a new always-on device only for WOL.

## Poor Fits

- Stock ISP routers with no SSH, no packages, and no startup scripts.
- Locked-down mesh systems that cannot run custom services.
- Routers that cannot send WOL packets.
- Routers isolated from the PC by VLAN/firewall rules.
- Routers that can only expose the service through public WAN forwarding.

In those cases, keep the router as-is and use another already-on LAN device as
the relay.

## Quick Decision

Use the router if it can run a private persistent service and send WOL.

Use another already-on LAN device if the router is locked down.

Do not use this design with public port forwarding.

## Examples

| Device type | Likely outcome | Notes |
| --- | --- | --- |
| ASUSWRT-Merlin router with Entware | Good fit | This repo includes an Entware-style init example. |
| OpenWrt router | Good fit with adaptation | Use OpenWrt packages and service management. |
| DD-WRT router | Possible | Depends heavily on model storage, startup scripts, and WOL tools. |
| pfSense/OPNsense box | Possible | Implement service using platform tooling and firewall rules. |
| NAS already on 24/7 | Good relay | Use Linux/service equivalent if it can send WOL. |
| Home Assistant box already on 24/7 | Good relay | Use an equivalent private endpoint or automation. |
| Raspberry Pi/mini PC already on | Good relay | Works, but less ideal if bought only for this. |
| Stock ISP router | Usually poor fit | Often lacks SSH, packages, scripts, and persistent services. |
| Locked-down mesh router | Usually poor fit | Often cannot run custom services or send WOL. |
| Router on another VLAN from PC | Poor fit until network is changed | WOL broadcast must reach the wired NIC. |
