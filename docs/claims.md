# Claims And Evidence

This project should be marketed accurately. It is not guaranteed to be the best
possible workflow for every person, router, OS, or threat model.

## Recommended Public Claim

> An energy-efficient, private, phone-controlled WOL/suspend workflow for Linux
> desktops using an already-on router, Tailscale, iOS Shortcuts, and RustDesk.

## Claim Matrix

| Claim | Status | Why |
| --- | --- | --- |
| Energy-efficient | Strong for the target setup | It avoids running an extra always-on relay device when the router is already powered. The workstation can stay suspended or off. |
| Easy once installed | Reasonable | iOS Shortcuts become simple GET requests, but initial setup still requires router scripting, Tailscale, Linux services, sudoers, UEFI WOL, and testing. |
| Safer than WAN port forwarding | Strong when configured correctly | APIs are bound to Tailscale IPs and should not be exposed on WAN. Tailscale uses WireGuard for encrypted device-to-device connectivity. |
| Universally safest | Do not claim | A leaked bearer token, compromised phone, compromised tailnet device, or weak RustDesk password can still cause harm. |
| Most effective WOL workflow | Good for router-capable homes | Router relay is excellent when the router is already on and on the same LAN. Other users may be better served by a NAS, OpenWrt, Home Assistant, IPMI, AMT, or vendor remote-management stack. |
| Data-safe | Conditional | Suspend/shutdown through the OS is safer than cutting power with a smart plug. It does not replace backups, disk encryption, or RustDesk credential hygiene. |
| Cross-platform | Architecture yes, scripts no | Router-side WOL can wake many OSes, but the included PC suspend/shutdown API is Linux/systemd-focused. Windows and macOS need different local service/helper implementations. |

## Source Notes

- Tailscale documents its data plane as using WireGuard for encrypted
  communication between devices:
  <https://tailscale.com/docs/concepts/tailscale-encryption>
- Tailscale describes private device connectivity through tailnets:
  <https://tailscale.com/docs/concepts/what-is-tailscale>
- Asuswrt-Merlin documents user scripts for custom firewall rules, scheduled
  jobs, and starting services:
  <https://github.com/RMerl/asuswrt-merlin/wiki/User-scripts>
- Asuswrt-Merlin documents third-party software support through Entware:
  <https://www.asuswrt-merlin.net/features>
- RustDesk documents client command-line parameters including permanent password
  support:
  <https://rustdesk.com/docs/en/client/>
- RustDesk documents self-hosting and relay behavior for users who want more
  control over remote access infrastructure:
  <https://rustdesk.com/docs/en/self-host/>

Always keep the repo language scoped to the target hardware and configuration.
