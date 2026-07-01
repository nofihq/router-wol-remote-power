# Router Support

This project is router-first. The normal design is to use the home router,
which is already powered on, as the Wake-on-LAN relay. That is the main
difference from setups that add a Raspberry Pi, NAS, mini PC, or smart plug
only for remote power control.

It does not require one exact router brand. It requires router capabilities:
the router must be on the PC's LAN, send WOL, receive a private request from
your phone, and keep the wake service running after reboot.

If you do not know whether your router is a fit, check the router web UI first.
Look for SSH access, custom/startup scripts, package support, Wake-on-LAN, and
VPN/Tailscale support. If those do not exist, the router is probably not the
right fit for the router-first setup.

## Required Capabilities

The router must be able to:

- stay powered on while the PC is off or suspended
- reach the PC's wired Ethernet LAN/VLAN
- send a Wake-on-LAN magic packet to the PC's wired MAC address
- run a small private service or equivalent command endpoint
- keep files after reboot
- start the wake service automatically after reboot
- be reachable from the phone through Tailscale, another VPN, or a private-only
  network path
- avoid public WAN port forwarding

If any of those are missing, the documented router setup will not work as
written. Use a fallback relay only if the router is locked down.

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

USB storage is usually part of this path because Entware and `/opt` are commonly
stored on USB-backed persistent storage on ASUSWRT-Merlin. USB is not a
project-wide requirement; it is a Merlin/Entware persistence detail.

Some Merlin/Tailscale installs should not bind the API directly to the
Tailscale IP. If testing shows that bind mode is unreliable, use
`ROUTER_LISTEN_IP=0.0.0.0`, keep the iPhone Shortcut pointed at
`<ROUTER_TAILSCALE_IP>:8080`, and add firewall rules that allow loopback and
the Tailscale/private interface before dropping other sources for port `8080`.

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

## Fallback Relays

NAS, Home Assistant, Raspberry Pi, mini PC, and Linux servers can all send WOL
if they are already on and on the same LAN as the PC. Treat these as fallback
relays when the router cannot run the wake API.

This fallback is practical if the device already runs 24/7 for another reason.
It is less energy-efficient if you buy or power another device only for WOL,
because it loses the router-as-already-on advantage.

## Poor Fits

- Stock ISP routers with no SSH, no packages, and no startup scripts.
- Locked-down mesh systems that cannot run custom services.
- Routers that cannot send WOL packets.
- Routers isolated from the PC by VLAN/firewall rules.
- Routers that can only expose the service through public WAN forwarding.

In those cases, keep the router as-is and use another already-on LAN device as
a fallback relay.

## Quick Decision

Use the router if it can run a private persistent service and send WOL. That is
the intended setup.

Use another already-on LAN device only if the router is locked down or cannot
send WOL.

Do not use this design with public port forwarding.

## Examples

| Device type | Likely outcome | Notes |
| --- | --- | --- |
| ASUSWRT-Merlin router with Entware | Good fit | This repo includes an Entware-style init example. |
| OpenWrt router | Good fit with adaptation | Use OpenWrt packages and service management. |
| DD-WRT router | Possible | Depends heavily on model storage, startup scripts, and WOL tools. |
| pfSense/OPNsense box | Possible | Implement service using platform tooling and firewall rules. |
| NAS already on 24/7 | Fallback relay | Use Linux/service equivalent if the router cannot run the wake API. |
| Home Assistant box already on 24/7 | Fallback relay | Use an equivalent private endpoint or automation. |
| Raspberry Pi/mini PC already on | Fallback relay | Works, but less ideal if bought only for this. |
| Stock ISP router | Usually poor fit | Often lacks SSH, packages, scripts, and persistent services. |
| Locked-down mesh router | Usually poor fit | Often cannot run custom services or send WOL. |
| Router on another VLAN from PC | Poor fit until network is changed | WOL broadcast must reach the wired NIC. |
