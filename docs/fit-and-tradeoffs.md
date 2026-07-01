# Fit And Tradeoffs

This setup is meant for a home Linux desktop that stays on wired Ethernet and
has a router capable of running a small private wake service.

## Good Fit

- Linux desktop or workstation at home.
- Wired Ethernet connected to the same LAN as the router.
- Router already stays powered on.
- Router can run ASUSWRT-Merlin/Entware, OpenWrt, DD-WRT, pfSense/OPNsense, or
  another persistent private service.
- The PC wakes reliably from Ethernet WOL after shutdown and suspend.
- The PC suspends cleanly with `systemctl suspend`.
- The user wants phone shortcuts for wake, suspend, and shutdown.
- RustDesk unattended access is acceptable for the remote desktop layer.

## Poor Fit

- Wi-Fi-only desktop.
- Laptop that often changes networks or docking state.
- Router cannot run scripts/packages and cannot send WOL packets.
- PC firmware cannot wake from the desired sleep/off state.
- Local suspend is already unreliable.
- You need a managed enterprise solution with audit logs, roles, and central
  policy.

## Efficiency

The main efficiency win is using an always-on router as the WOL relay instead
of adding a Raspberry Pi, NAS, mini PC, or smart plug just to wake the
workstation. The workstation can remain suspended or fully shut down when it is
not being used.

## Safety

This is safer than exposing a power API to the public internet because the API
is designed to bind to Tailscale/private addresses only. It still depends on:

- strong bearer tokens
- Tailscale device and ACL hygiene
- a strong RustDesk unattended password
- root-owned helper scripts
- no WAN port forwarding

Suspend and shutdown are normal OS actions. They are safer for data integrity
than cutting power with a smart plug, but they do not replace backups, disk
encryption, or careful remote-access credential handling.

## Sources

- Tailscale documents WireGuard-based encrypted device connectivity:
  <https://tailscale.com/docs/concepts/tailscale-encryption>
- Tailscale describes private tailnet connectivity:
  <https://tailscale.com/docs/concepts/what-is-tailscale>
- Asuswrt-Merlin supports user scripts and Entware on supported models:
  <https://www.asuswrt-merlin.net/features>
- RustDesk documents unattended/permanent password behavior in the client docs:
  <https://rustdesk.com/docs/en/client/>
