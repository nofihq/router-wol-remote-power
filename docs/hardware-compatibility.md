# Hardware Compatibility

Wake and suspend are hardware-dependent. Test locally before depending on this
while traveling.

## Wake Requirements

- Wired Ethernet is strongly preferred.
- Motherboard/UEFI must support Wake-on-LAN for the desired power state.
- The NIC must keep enough standby power to receive magic packets.
- The router must send the packet on the same LAN broadcast domain.

Firmware settings to check:

- Wake-on-LAN / PCIe wake enabled.
- ErP or deep power saving disabled if it blocks wake from shutdown.
- Boot order configured so the machine returns to the desired OS.

## PC Fit

Best fit:

- Desktop PC with built-in wired Ethernet.
- UEFI/BIOS exposes wake settings such as WOL, PCIe wake, or power on by PCI-E.
- The OS can suspend cleanly through `systemctl suspend`.
- The PC stays connected to the same wired LAN as the router.

Usually workable with extra testing:

- Custom-built desktops with Realtek, Intel, or similar onboard Ethernet.
- Small form factor PCs with wired Ethernet and configurable firmware.
- Linux distributions that use systemd but have different package paths.

Poor fit:

- Wi-Fi-only desktops.
- Laptops that move between networks or dock/undock often.
- USB Ethernet adapters that lose standby power during suspend/off.
- PCs whose firmware cannot wake from the power state you want.
- Systems where suspend is already unreliable locally.

## Phone Network

The phone can be on Wi-Fi or cellular. The requirement is not the radio type;
the requirement is that the phone's Tailscale client can reach:

- the router's tailnet IP for wake
- the PC's tailnet IP for status/suspend/shutdown while the PC is awake

When the PC is asleep or off, only the router API can answer.

## Suspend Requirements

Linux suspend can fail because of:

- GPU driver behavior, especially NVIDIA.
- Wi-Fi drivers and ACPI interactions.
- USB devices.
- NVMe/storage firmware.
- Motherboard firmware bugs.

Use `systemctl suspend` for real suspend. Avoid direct `/sys/power/state` unless
you know your GPU driver supports that path.

## Router Compatibility

Works best with routers that provide:

- persistent storage or scripts
- a package system or Python runtime
- a WOL sender such as `ether-wake`
- Tailscale or another private overlay/private access method

Good fits:

- ASUSWRT-Merlin routers that support user scripts, USB-backed persistent
  storage, Entware, Python, and Tailscale or private-only access.
- OpenWrt routers with packages for Python/Tailscale and a WOL tool.
- DD-WRT routers if they can run a persistent private service and send WOL.
- pfSense/OPNsense boxes if the wake service is implemented with their service
  model and kept private.
- A NAS, home server, or small Linux box can replace the router relay, but that
  loses the "no extra always-on relay" advantage if it was not already on.

Poor fits:

- Stock ISP routers with no custom scripts or package support.
- Routers that cannot run Tailscale or cannot expose a private-only service.
- Routers on a different VLAN/broadcast domain from the target PC.
- Routers where WOL packets cannot be sent on the LAN bridge/interface.

## Operating Systems

The checked-in PC API and helper scripts target Linux with systemd. The router
side is OS-agnostic for the target PC because Wake-on-LAN is handled by the NIC
and firmware, not the running OS.

See [OS Support](os-support.md) for Windows, macOS, and other Linux distro
notes.
