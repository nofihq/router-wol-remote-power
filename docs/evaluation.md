# Evaluation

This workflow is efficient when the router is already powered on and can send
Wake-on-LAN packets. In that case, no extra relay computer needs to stay awake
just to wake the workstation.

## Strengths

- No WAN port forwarding.
- No additional always-on Raspberry Pi, NAS, or mini PC is required.
- Phone Shortcuts are simple HTTP GET calls.
- Tailscale provides the private network path.
- Suspend preserves desktop state and wakes faster than cold boot.
- Shutdown remains available for longer breaks.

## Limits

- It is not universal. WOL and suspend depend on motherboard, NIC, firmware,
  router, GPU driver, and OS behavior.
- It is not automatically safer than every alternative. It is safer than public
  port forwarding when configured as a private tailnet-only service, but tokens,
  tailnet access, and RustDesk credentials still need protection.
- It is not always easier than a commercial smart plug or built-in vendor
  remote management, but it avoids power-cutting the machine and keeps normal
  OS shutdown/suspend semantics.

## Good Fit

- Linux desktop at home.
- Wired Ethernet.
- Router already supports Tailscale or can run a small local service.
- User wants iPhone shortcuts for power state.
- User wants RustDesk remote desktop after wake.

## Poor Fit

- Laptop that moves between networks.
- Wi-Fi-only desktop.
- Router cannot run custom scripts or Tailscale.
- PC firmware cannot wake from the desired sleep/off state.
- Suspend is unreliable and cannot be fixed through normal systemd driver hooks.
