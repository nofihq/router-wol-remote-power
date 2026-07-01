# Security Model

This project is designed for private tailnet use, not public internet exposure.

## Recommended Defaults

- Bind the router API to the router's Tailscale IP.
- Bind the PC API to the PC's Tailscale IP.
- Do not forward router WAN ports to either API.
- Use a strong random bearer token.
- Use separate router and PC tokens if you want compromise of one endpoint to
  avoid authorizing the other endpoint.
- Store token files outside git with mode `0600`, owned by the root-run service
  or by the non-root service user that must read the token.
- Prefer Tailscale ACLs that allow only your phone to reach the API ports.
- Keep sudoers entries limited to fixed root-owned helper scripts.
- Keep `/usr/local/sbin/pc_*_with_wol` owned by root and not writable by the API
  user.

## Threats To Care About

- A leaked bearer token lets an attacker wake, suspend, or shut down the PC if
  they can also reach the API.
- A compromised tailnet device may be able to call the APIs unless ACLs prevent
  it.
- A weak RustDesk unattended password can expose the desktop session.
- Publishing real Tailscale IPs, LAN IPs, MAC addresses, or tokens makes later
  mistakes easier.
- Root helper scripts must be root-owned and not writable by the API user.
- The bearer token is authorization, not identity. Pair it with Tailscale ACLs
  where possible.
- GET requests are easy for iOS Shortcuts, but they are still state-changing
  actions. Do not expose these endpoints outside the tailnet.

## Not Covered

- This does not harden RustDesk itself.
- This does not replace full disk encryption.
- This does not guarantee suspend works on every Linux/NVIDIA/ACPI combination.
