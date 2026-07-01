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

ASUSWRT-Merlin is a good fit because it supports user scripts and third-party
software through Entware on supported models. OpenWrt and similar firmware can
also work with equivalent services.

## Operating Systems

The checked-in PC API and helper scripts target Linux with systemd. The router
side is OS-agnostic for the target PC because Wake-on-LAN is handled by the NIC
and firmware, not the running OS.

See [OS Support](os-support.md) for Windows, macOS, and other Linux distro
notes.
