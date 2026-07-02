# Fit And Tradeoffs

This setup is meant for a home Linux desktop that stays on wired Ethernet and
has a router capable of running a small private wake service and sending WOL on
the PC's wired LAN.

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
- You would need to buy or power a new device only to act as the WOL relay.
- PC firmware cannot wake from the desired sleep/off state.
- Local suspend is already unreliable.
- You need a managed enterprise solution with audit logs, roles, and central
  policy.

## Efficiency

The main efficiency win is using the router that is already on as the WOL relay
instead of adding a Raspberry Pi, NAS, mini PC, or smart plug only to wake the
workstation. The workstation can remain suspended or fully shut down when it is
not being used.

If a NAS, Home Assistant box, Raspberry Pi, mini PC, or Linux server is already
running 24/7 for another reason, it can be a fallback relay. It is not the
preferred path because the router-as-relay design is what avoids another
always-on device.

## Safety

This is safer than exposing a power API to the public internet because access
is designed to stay inside Tailscale/private networking. On routers that can
bind directly to the tailnet IP, do that. On ASUSWRT-Merlin/Tailscale userspace
setups that need `ROUTER_LISTEN_IP=0.0.0.0`, pair it with router firewall
rules and app-layer source allowlisting. It still depends on:

- strong bearer tokens
- Tailscale device and ACL hygiene
- a strong RustDesk unattended password
- root-owned helper scripts
- no WAN port forwarding

Suspend and shutdown are normal OS actions. They are safer for data integrity
than cutting power with a smart plug, but they do not replace backups, disk
encryption, or careful remote-access credential handling.

## Daily Use And Wear

Using sleep or clean shutdown every day is normal PC behavior. It should not
damage a healthy desktop by itself.

`systemctl suspend` is not a full reboot. The OS pauses the running session,
keeps enough standby power for resume, and continues from the same desktop
state when the machine wakes. Depending on firmware, this may be traditional
suspend-to-RAM (`deep`) or a lighter idle sleep state (`s2idle`).

Shutdown is different. Linux stops services, unmounts filesystems, powers off,
and the next wake goes through firmware/UEFI and a normal Linux boot. That is
more like starting the PC fresh.

Daily sleep/wake or daily clean shutdown/startup is usually fine. Avoid the
things that are actually risky:

- holding the power button unless the machine is frozen
- cutting AC power with a smart plug while Linux is running
- repeatedly forcing failed suspend attempts
- relying on remote access without backups for important data

If both paths work reliably, use suspend for shorter breaks and shutdown for
longer periods away.

## Sources

- Tailscale documents WireGuard-based encrypted device connectivity:
  <https://tailscale.com/docs/concepts/tailscale-encryption>
- Tailscale describes private tailnet connectivity:
  <https://tailscale.com/docs/concepts/what-is-tailscale>
- Asuswrt-Merlin supports user scripts and Entware on supported models:
  <https://www.asuswrt-merlin.net/features>
- RustDesk documents unattended/permanent password behavior in the client docs:
  <https://rustdesk.com/docs/en/client/>
